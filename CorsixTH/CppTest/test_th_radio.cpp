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

#include <catch2/catch_test_macros.hpp>
#include <string>

#include "th_radio.h"

using th::radio::first_playlist_entry;
using th::radio::icy_header;
using th::radio::icy_stream_title;

TEST_CASE("pls playlist gives its first stream", "[radio]") {
  std::string pls =
      "[playlist]\r\n"
      "NumberOfEntries=2\r\n"
      "File1=http://stream.example.org:8000/live.mp3\r\n"
      "Title1=Example FM\r\n"
      "File2=http://backup.example.org/live.mp3\r\n";
  REQUIRE(first_playlist_entry(pls) == "http://stream.example.org:8000/live.mp3");
}

TEST_CASE("m3u playlist skips comments", "[radio]") {
  std::string m3u =
      "\xEF\xBB\xBF#EXTM3U\n"
      "#EXTINF:-1,Example FM\n"
      "\n"
      "https://stream.example.org/aac\n";
  REQUIRE(first_playlist_entry(m3u) == "https://stream.example.org/aac");
}

TEST_CASE("HLS and other text are not simple playlists", "[radio]") {
  REQUIRE(first_playlist_entry("#EXTM3U\n#EXT-X-VERSION:3\nchunk1.ts\n").empty());
  REQUIRE(first_playlist_entry("<html>not a playlist</html>").empty());
  REQUIRE(first_playlist_entry("").empty());
  REQUIRE(first_playlist_entry("[playlist]\nFile1=ftp://example.org/x\n").empty());
}

TEST_CASE("ICY stream title", "[radio]") {
  REQUIRE(icy_stream_title("StreamTitle='Artist - Song';StreamUrl='';") ==
          "Artist - Song");
  REQUIRE(icy_stream_title("StreamTitle='Don't Stop';") == "Don't Stop");
  REQUIRE(icy_stream_title("StreamTitle='';") == "");
  REQUIRE(icy_stream_title("StreamUrl='x';").empty());
}

TEST_CASE("ICY headers", "[radio]") {
  std::string headers =
      "icy-br:128\r\n"
      "ICY-Name: Example FM \r\n"
      "icy-genre:Pop\r\n";
  REQUIRE(icy_header(headers, "icy-name") == "Example FM");
  REQUIRE(icy_header(headers, "icy-genre") == "Pop");
  REQUIRE(icy_header(headers, "icy-url").empty());
}
