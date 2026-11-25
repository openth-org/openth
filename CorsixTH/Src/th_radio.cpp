/*
Copyright (c) 2026 OpenTH contributors

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
of the Software, and to permit persons to whom the Software is furnished to do
so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

#include "th_radio.h"

#include <SDL3/SDL.h>

#include <algorithm>
#include <atomic>
#include <cctype>
#include <chrono>
#include <cstdint>
#include <mutex>
#include <thread>
#include <vector>

#include "th_sound.h"

#ifdef CORSIX_TH_USE_FFMPEG
extern "C" {
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libavutil/channel_layout.h>
#include <libavutil/error.h>
#include <libavutil/opt.h>
#include <libswresample/swresample.h>
}
// (The channel layout API of FFmpeg 5.1; every build we ship has it.)
#if LIBAVUTIL_VERSION_INT >= AV_VERSION_INT(57, 24, 100) && \
    LIBSWRESAMPLE_VERSION_INT >= AV_VERSION_INT(4, 5, 100)
#define TH_RADIO_WITH_FFMPEG
#endif
#endif

namespace th::radio {

namespace {

std::string trim(const std::string& s) {
  const char* space = " \t\r\n";
  std::size_t first = s.find_first_not_of(space);
  if (first == std::string::npos) {
    return "";
  }
  std::size_t last = s.find_last_not_of(space);
  return s.substr(first, last - first + 1);
}

std::string lower(std::string s) {
  std::transform(s.begin(), s.end(), s.begin(), [](unsigned char c) {
    return static_cast<char>(std::tolower(c));
  });
  return s;
}

//! Whether s starts with prefix (given in lower case), ignoring case.
bool starts_with(const std::string& s, const std::string& prefix) {
  return s.size() >= prefix.size() && lower(s.substr(0, prefix.size())) == prefix;
}

bool is_stream_address(const std::string& s) {
  return starts_with(s, "http://") || starts_with(s, "https://");
}

//! Calls f(line) for each line of text, trimmed, until f returns true.
template <typename F>
void for_each_line(const std::string& text, F f) {
  std::size_t pos = 0;
  while (pos < text.size()) {
    std::size_t end = text.find('\n', pos);
    if (end == std::string::npos) {
      end = text.size();
    }
    if (f(trim(text.substr(pos, end - pos)))) {
      return;
    }
    pos = end + 1;
  }
}

}  // namespace

std::string first_playlist_entry(const std::string& text) {
  std::string body = text;
  if (body.compare(0, 3, "\xEF\xBB\xBF") == 0) {
    body.erase(0, 3);
  }
  std::string low = lower(body);
  if (low.find("#ext-x-") != std::string::npos) {
    return "";  // HLS: FFmpeg plays that itself.
  }
  bool pls = low.find("[playlist]") != std::string::npos;
  std::string found;
  for_each_line(body, [&](const std::string& line) {
    if (line.empty()) {
      return false;
    }
    std::string value;
    if (pls) {
      std::size_t eq = line.find('=');
      if (!starts_with(line, "file") || eq == std::string::npos) {
        return false;
      }
      value = trim(line.substr(eq + 1));
    } else if (line[0] != '#') {
      value = line;
    }
    if (is_stream_address(value)) {
      found = value;
      return true;
    }
    return false;
  });
  return found;
}

std::string icy_stream_title(const std::string& packet) {
  const std::string key = "StreamTitle='";
  std::size_t first = packet.find(key);
  if (first == std::string::npos) {
    return "";
  }
  first += key.size();
  std::size_t last = packet.find("';", first);
  if (last == std::string::npos) {
    last = packet.rfind('\'');
    if (last == std::string::npos || last < first) {
      last = packet.size();
    }
  }
  return trim(packet.substr(first, last - first));
}

std::string icy_header(const std::string& headers, const std::string& name) {
  std::string want = lower(name) + ":";
  std::string found;
  for_each_line(headers, [&](const std::string& line) {
    if (!starts_with(line, want)) {
      return false;
    }
    found = trim(line.substr(want.size()));
    return true;
  });
  return found;
}

namespace {

// What the stream is turned into: what the movies play too.
constexpr int out_rate = 48000;
constexpr int out_channels = 2;
constexpr int bytes_per_second =
    out_rate * out_channels * static_cast<int>(sizeof(float));

struct radio_player {
  std::mutex mutex;  // Guards st, stream and started.
  status st;
  SDL_AudioStream* stream{nullptr};  // Owned by the thread while it plays.
  bool started{false};  // The sound began (after the first half second).
  std::thread worker;
  std::atomic<bool> abort{false};
  std::atomic<bool> paused{false};
  std::atomic<float> gain{1.0f};
};

radio_player& player() {
  // Never destroyed: a static destructor must not join a thread that may
  // still use SDL after it has shut down. The game stops the radio itself.
  static radio_player* p = new radio_player();
  return *p;
}

void set_state(state current, const std::string& error = "",
               const std::string& detail = "") {
  radio_player& p = player();
  std::scoped_lock lock(p.mutex);
  p.st.current = current;
  p.st.error = error;
  p.st.detail = detail;
}

#ifdef TH_RADIO_WITH_FFMPEG

//! Sleeps up to ms milliseconds, waking at once when the radio is stopped.
void nap(int ms) {
  radio_player& p = player();
  for (int waited = 0; waited < ms && !p.abort; waited += 20) {
    std::this_thread::sleep_for(std::chrono::milliseconds(20));
  }
}

int interrupt_callback(void* opaque) {
  return static_cast<radio_player*>(opaque)->abort.load() ? 1 : 0;
}

std::string error_text(int err) {
  char buffer[AV_ERROR_MAX_STRING_SIZE] = {};
  av_strerror(err, buffer, sizeof(buffer));
  return buffer;
}

AVDictionary* open_options() {
  AVDictionary* options = nullptr;
  av_dict_set(&options, "icy", "1", 0);  // Ask for the station and song.
  av_dict_set(&options, "user_agent", "OpenTH", 0);
  av_dict_set(&options, "rw_timeout", "15000000", 0);  // 15 s, in us.
  av_dict_set(&options, "reconnect", "1", 0);
  av_dict_set(&options, "reconnect_streamed", "1", 0);
  av_dict_set(&options, "reconnect_delay_max", "4", 0);
  return options;
}

//! The stream named by the playlist at url (.pls, .m3u), or "".
std::string fetch_playlist_entry(const std::string& url) {
  radio_player& p = player();
  AVIOInterruptCB interrupt{interrupt_callback, &p};
  AVDictionary* options = open_options();
  av_dict_set(&options, "icy", "0", 0);
  AVIOContext* io = nullptr;
  int err = avio_open2(&io, url.c_str(), AVIO_FLAG_READ, &interrupt, &options);
  av_dict_free(&options);
  if (err < 0) {
    return "";
  }
  std::string text;
  std::vector<unsigned char> buffer(4096);
  while (text.size() < 65536 && !p.abort) {
    int n = avio_read(io, buffer.data(), static_cast<int>(buffer.size()));
    if (n <= 0) {
      break;
    }
    text.append(reinterpret_cast<const char*>(buffer.data()),
                static_cast<std::size_t>(n));
  }
  avio_closep(&io);
  return first_playlist_entry(text);
}

//! The value of an option of the stream's connection (the http protocol's
//! ICY data), or "".
std::string connection_option(AVFormatContext* fmt, const char* name) {
  std::string result;
  void* targets[] = {fmt, fmt->pb};
  for (void* target : targets) {
    if (target == nullptr) {
      continue;
    }
    uint8_t* value = nullptr;
    if (av_opt_get(target, name, AV_OPT_SEARCH_CHILDREN, &value) >= 0 &&
        value != nullptr) {
      result = reinterpret_cast<const char*>(value);
    }
    av_freep(&value);
    if (!result.empty()) {
      break;
    }
  }
  return result;
}

//! Reads the station's name and what is on now.
void update_metadata(AVFormatContext* fmt) {
  std::string station =
      icy_header(connection_option(fmt, "icy_metadata_headers"), "icy-name");
  std::string title =
      icy_stream_title(connection_option(fmt, "icy_metadata_packet"));
  if (station.empty()) {
    if (AVDictionaryEntry* e = av_dict_get(fmt->metadata, "icy-name", nullptr, 0)) {
      station = e->value;
    }
  }
  if (title.empty()) {
    if (AVDictionaryEntry* e =
            av_dict_get(fmt->metadata, "StreamTitle", nullptr, 0)) {
      title = e->value;
    }
  }
  radio_player& p = player();
  std::scoped_lock lock(p.mutex);
  p.st.station = trim(station);
  p.st.title = trim(title);
}

//! Everything one connection holds, freed in the right order.
struct connection {
  AVFormatContext* fmt{nullptr};
  AVCodecContext* codec{nullptr};
  SwrContext* swr{nullptr};
  AVPacket* packet{nullptr};
  AVFrame* frame{nullptr};
  SDL_AudioStream* stream{nullptr};
  AVChannelLayout out_layout{};
  // What the resampler was made for: a stream may change it midway.
  AVChannelLayout in_layout{};
  int in_rate{0};
  int in_format{-1};

  connection() = default;
  connection(const connection&) = delete;
  connection& operator=(const connection&) = delete;

  ~connection() {
    if (stream != nullptr) {
      radio_player& p = player();
      {
        std::scoped_lock lock(p.mutex);
        p.stream = nullptr;
        p.started = false;
      }
      SDL_DestroyAudioStream(stream);
    }
    av_channel_layout_uninit(&out_layout);
    av_channel_layout_uninit(&in_layout);
    av_frame_free(&frame);
    av_packet_free(&packet);
    swr_free(&swr);
    avcodec_free_context(&codec);
    if (fmt != nullptr) {
      avformat_close_input(&fmt);
    }
  }
};

enum class outcome {
  not_opened,  // Not audio we can play: maybe a playlist.
  played,      // It played, then ended or broke.
  stopped      // The game stopped the radio.
};

//! Turns one decoded frame into the stream's format and queues it.
void queue_frame(connection& c, std::vector<uint8_t>& out) {
  AVFrame* frame = c.frame;
  if (c.swr == nullptr || frame->sample_rate != c.in_rate ||
      frame->format != c.in_format ||
      av_channel_layout_compare(&frame->ch_layout, &c.in_layout) != 0) {
    swr_free(&c.swr);
    if (swr_alloc_set_opts2(&c.swr, &c.out_layout, AV_SAMPLE_FMT_FLT, out_rate,
                            &frame->ch_layout,
                            static_cast<AVSampleFormat>(frame->format),
                            frame->sample_rate, 0, nullptr) < 0 ||
        swr_init(c.swr) < 0) {
      swr_free(&c.swr);
      return;
    }
    av_channel_layout_uninit(&c.in_layout);
    av_channel_layout_copy(&c.in_layout, &frame->ch_layout);
    c.in_rate = frame->sample_rate;
    c.in_format = frame->format;
  }
  int samples = swr_get_out_samples(c.swr, frame->nb_samples);
  if (samples <= 0) {
    return;
  }
  out.resize(static_cast<std::size_t>(samples) * out_channels * sizeof(float));
  uint8_t* out_data = out.data();
  // (As th_movie.cpp: the input's type differs between FFmpeg versions.)
  int converted = swr_convert(c.swr, &out_data, samples,
                              frame->extended_data, frame->nb_samples);
  if (converted > 0) {
    SDL_PutAudioStreamData(
        c.stream, out.data(),
        converted * out_channels * static_cast<int>(sizeof(float)));
  }
}

//! Connects to url and plays it until it ends or the radio is stopped.
outcome play_stream(const std::string& url, std::string* error,
                    std::string* detail) {
  radio_player& p = player();
  connection c;
  c.fmt = avformat_alloc_context();
  if (c.fmt == nullptr) {
    *error = "open";
    return outcome::not_opened;
  }
  c.fmt->interrupt_callback.callback = interrupt_callback;
  c.fmt->interrupt_callback.opaque = &p;
  AVDictionary* options = open_options();
  int err = avformat_open_input(&c.fmt, url.c_str(), nullptr, &options);
  av_dict_free(&options);
  if (err < 0) {  // (avformat_open_input freed the context.)
    if (p.abort) {
      return outcome::stopped;
    }
    *error = err == AVERROR_PROTOCOL_NOT_FOUND && starts_with(url, "https://")
                 ? "https"
                 : "open";
    *detail = error_text(err);
    return outcome::not_opened;
  }
  err = avformat_find_stream_info(c.fmt, nullptr);
  if (err < 0) {
    if (p.abort) {
      return outcome::stopped;
    }
    *error = "open";
    *detail = error_text(err);
    return outcome::not_opened;
  }
  const AVCodec* decoder = nullptr;
  int index =
      av_find_best_stream(c.fmt, AVMEDIA_TYPE_AUDIO, -1, -1, &decoder, 0);
  if (index < 0 || decoder == nullptr) {
    *error = "no_audio";
    *detail = error_text(index < 0 ? index : AVERROR_DECODER_NOT_FOUND);
    return outcome::not_opened;
  }
  c.codec = avcodec_alloc_context3(decoder);
  if (c.codec == nullptr ||
      avcodec_parameters_to_context(c.codec, c.fmt->streams[index]->codecpar) <
          0 ||
      (err = avcodec_open2(c.codec, decoder, nullptr)) < 0) {
    *error = "no_audio";
    *detail = error_text(err);
    return outcome::not_opened;
  }
  c.packet = av_packet_alloc();
  c.frame = av_frame_alloc();
  av_channel_layout_from_mask(&c.out_layout, AV_CH_LAYOUT_STEREO);

  SDL_AudioSpec spec;
  spec.format = SDL_AUDIO_F32;
  spec.channels = out_channels;
  spec.freq = out_rate;
  // (The device starts paused: the sound begins once half a second waits.)
  c.stream = SDL_OpenAudioDeviceStream(SDL_AUDIO_DEVICE_DEFAULT_PLAYBACK,
                                       &spec, nullptr, nullptr);
  if (c.stream == nullptr) {
    *error = "device";
    *detail = SDL_GetError();
    return outcome::not_opened;
  }
  SDL_SetAudioStreamGain(c.stream, p.gain);
  {
    std::scoped_lock lock(p.mutex);
    p.stream = c.stream;
    p.started = false;
  }
  update_metadata(c.fmt);

  std::vector<uint8_t> out;
  bool started = false;
  Uint64 last_metadata = SDL_GetTicks();
  while (!p.abort) {
    err = av_read_frame(c.fmt, c.packet);
    if (err == AVERROR(EAGAIN)) {
      nap(10);
      continue;
    }
    if (err < 0) {
      *detail = error_text(err);
      break;
    }
    if (c.packet->stream_index == index) {
      // (A broken packet is skipped: radio goes on.)
      if (avcodec_send_packet(c.codec, c.packet) >= 0) {
        while (!p.abort && avcodec_receive_frame(c.codec, c.frame) >= 0) {
          queue_frame(c, out);
          av_frame_unref(c.frame);
        }
      }
    }
    av_packet_unref(c.packet);

    if (!started &&
        SDL_GetAudioStreamQueued(c.stream) >= bytes_per_second / 2) {
      started = true;
      std::scoped_lock lock(p.mutex);
      p.started = true;
      if (!p.paused) {
        SDL_ResumeAudioStreamDevice(c.stream);
      }
      p.st.current = state::playing;
      p.st.error.clear();
      p.st.detail.clear();
    }
    // Two seconds ahead is plenty: the rest waits on the network.
    while (!p.abort &&
           SDL_GetAudioStreamQueued(c.stream) > 2 * bytes_per_second) {
      std::this_thread::sleep_for(std::chrono::milliseconds(50));
    }
    if (SDL_GetTicks() - last_metadata >= 1000) {
      update_metadata(c.fmt);
      last_metadata = SDL_GetTicks();
    }
  }
  if (p.abort) {
    return outcome::stopped;
  }
  if (!started) {
    *error = "no_audio";
    return outcome::not_opened;
  }
  return outcome::played;
}

void run(const std::string& url) {
  static std::once_flag network_once;
  std::call_once(network_once, [] { avformat_network_init(); });
  radio_player& p = player();
  std::string address = url;
  int hops = 0;      // Playlists followed.
  int retries = 0;   // Reconnections since the last good while.
  while (!p.abort) {
    std::string error;
    std::string detail;
    Uint64 began = SDL_GetTicks();
    outcome result = play_stream(address, &error, &detail);
    if (result == outcome::stopped || p.abort) {
      return;
    }
    if (result == outcome::played) {
      // It ended or broke: connect again, as a radio would. A stream that
      // keeps dropping at once is given up after a few tries.
      if (SDL_GetTicks() - began > 60000) {
        retries = 0;
      }
      if (++retries > 5) {
        set_state(state::failed, "ended", detail);
        return;
      }
      set_state(state::connecting);
      nap(2000);
      continue;
    }
    // Not audio: maybe a playlist (.pls, .m3u) naming the stream.
    if (hops < 3) {
      std::string next = fetch_playlist_entry(address);
      if (!next.empty() && next != address) {
        address = next;
        ++hops;
        continue;
      }
    }
    if (!p.abort) {
      set_state(state::failed, error.empty() ? "open" : error, detail);
    }
    return;
  }
}

#endif  // TH_RADIO_WITH_FFMPEG

}  // namespace

bool supported() {
#ifdef TH_RADIO_WITH_FFMPEG
  return true;
#else
  return false;
#endif
}

void play(const std::string& url) {
  stop();
#ifdef TH_RADIO_WITH_FFMPEG
  radio_player& p = player();
  p.abort = false;
  {
    std::scoped_lock lock(p.mutex);
    p.st = status{};
    p.st.current = state::connecting;
  }
  p.worker = std::thread(run, url);
#else
  set_state(state::failed, "open", "This build has no FFmpeg");
#endif
}

void stop() {
  radio_player& p = player();
  p.abort = true;
  if (p.worker.joinable()) {
    p.worker.join();
  }
  std::scoped_lock lock(p.mutex);
  p.st = status{};
}

void set_paused(bool paused) {
  radio_player& p = player();
  p.paused = paused;
  std::scoped_lock lock(p.mutex);
  if (p.stream != nullptr && p.started) {
    if (paused) {
      SDL_PauseAudioStreamDevice(p.stream);
    } else {
      SDL_ResumeAudioStreamDevice(p.stream);
    }
  }
}

void set_volume(float volume) {
  volume = std::clamp(volume, 0.0f, 1.0f);
  radio_player& p = player();
  p.gain = th::sound::linear_to_logarithmic_volume(volume);
  std::scoped_lock lock(p.mutex);
  if (p.stream != nullptr) {
    SDL_SetAudioStreamGain(p.stream, p.gain);
  }
}

status get_status() {
  radio_player& p = player();
  std::scoped_lock lock(p.mutex);
  return p.st;
}

}  // namespace th::radio
