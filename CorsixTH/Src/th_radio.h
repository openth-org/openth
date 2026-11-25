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

#ifndef CORSIX_TH_TH_RADIO_H_
#define CORSIX_TH_TH_RADIO_H_

#include "config.h"

#include <string>

//! Internet radio for the jukebox: one stream at a time, played on its own
//! audio stream (like the movies), so the game's music track is untouched.
//! FFmpeg opens and decodes the stream in a thread of its own; the game only
//! starts, stops and asks how it goes. Only this computer hears it, so it
//! has no effect on a multiplayer game.
namespace th::radio {

//! What the radio is doing.
enum class state { stopped, connecting, playing, failed };

struct status {
  state current{state::stopped};
  std::string station;  //!< The station's name (icy-name), if it sends one.
  std::string title;    //!< What is on now (StreamTitle), if it says.
  //! Why it failed: "https" (no TLS in this build), "open", "no_audio",
  //! "device" or "ended".
  std::string error;
  std::string detail;  //!< FFmpeg's or SDL's own words for the error.
};

//! Whether this build can play internet radio (built with FFmpeg 5.1+).
bool supported();

//! Starts playing the stream at url, stopping any stream already playing.
//! Returns at once: connecting happens in the radio's thread.
void play(const std::string& url);

//! Stops the stream and waits for its thread to finish.
void stop();

//! Pauses or resumes the sound (the stream stays connected while it can).
void set_paused(bool paused);

//! Sets the volume, 0 to 1, on the same scale as the game's music volume.
void set_volume(float volume);

//! A copy of the radio's current status.
status get_status();

//! The first stream address in a .pls or .m3u playlist, or "" when text is
//! not such a playlist (an HLS playlist is left to FFmpeg).
std::string first_playlist_entry(const std::string& text);

//! The StreamTitle in an ICY metadata packet
//! ("StreamTitle='Artist - Song';StreamUrl='';"), or "".
std::string icy_stream_title(const std::string& packet);

//! The value of the header called name (e.g. "icy-name") in ICY response
//! headers, one "name: value" per line, or "".
std::string icy_header(const std::string& headers, const std::string& name);

}  // namespace th::radio

#endif  // CORSIX_TH_TH_RADIO_H_
