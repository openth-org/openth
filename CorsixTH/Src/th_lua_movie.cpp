/*
Copyright (c) 2012 Stephen Baker

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

#include "config.h"

#include <SDL3/SDL.h>

#ifdef WITH_TRACY
#include <tracy/Tracy.hpp>
#endif

#include "lua.hpp"
#include "th_gfx_sdl.h"
#include "th_lua.h"
#include "th_lua_internal.h"
#include "th_movie.h"

namespace {

int l_movie_new(lua_State* L) {
  luaT_stdnew<movie_player>(L, luaT_environindex, true);
  return 1;
}

int l_movie_set_renderer(lua_State* L) {
  movie_player* pMovie = luaT_testuserdata<movie_player>(L);
  render_target* pRenderTarget = luaT_testuserdata<render_target>(L, 2);
  pMovie->set_renderer(pRenderTarget->get_renderer());
  return 0;
}

int l_movie_enabled(lua_State* L) {
  movie_player* pMovie = luaT_testuserdata<movie_player>(L);
  lua_pushboolean(L, pMovie->movies_enabled());
  return 1;
}

int l_movie_load(lua_State* L) {
  ZoneScoped;

  bool loaded;
  const char* warning;
  movie_player* pMovie = luaT_testuserdata<movie_player>(L);
  const char* filepath = lua_tolstring(L, 2, nullptr);
  pMovie->clear_last_error();
  loaded = pMovie->load(filepath);
  warning = pMovie->get_last_error();
  lua_pushboolean(L, loaded);
  lua_pushstring(L, warning);
  return 2;
}

int l_movie_unload(lua_State* L) {
  ZoneScoped;

  movie_player* pMovie = luaT_testuserdata<movie_player>(L);
  pMovie->unload();
  return 0;
}

int l_movie_play(lua_State* L) {
  ZoneScoped;

  const char* warning;
  movie_player* pMovie = luaT_testuserdata<movie_player>(L);
  pMovie->clear_last_error();
  pMovie->play();
  warning = pMovie->get_last_error();
  lua_pushstring(L, warning);
  return 1;
}

int l_movie_stop(lua_State* L) {
  ZoneScoped;

  movie_player* pVideo = luaT_testuserdata<movie_player>(L);
  pVideo->stop();
  return 0;
}

int l_movie_toggle_pause(lua_State* L) {
  ZoneScoped;

  movie_player* pVideo = luaT_testuserdata<movie_player>(L);
  pVideo->togglePause();
  return 0;
}

int l_movie_get_native_height(lua_State* L) {
  movie_player* pMovie = luaT_testuserdata<movie_player>(L);
  lua_pushinteger(L, pMovie->get_native_height());
  return 1;
}

int l_movie_get_native_width(lua_State* L) {
  movie_player* pMovie = luaT_testuserdata<movie_player>(L);
  lua_pushinteger(L, pMovie->get_native_width());
  return 1;
}

int l_movie_has_audio_track(lua_State* L) {
  movie_player* pMovie = luaT_testuserdata<movie_player>(L);
  lua_pushboolean(L, pMovie->has_audio_track());
  return 1;
}

int l_movie_get_length(lua_State* L) {
  movie_player* pMovie = luaT_testuserdata<movie_player>(L);
  lua_pushnumber(L, pMovie->get_movie_length());
  return 1;
}

int l_movie_refresh(lua_State* L) {
  ZoneScoped;

  movie_player* pMovie = luaT_testuserdata<movie_player>(L);
  SDL_Rect rect{static_cast<int>(luaL_checkinteger(L, 2)),
                static_cast<int>(luaL_checkinteger(L, 3)),
                static_cast<int>(luaL_checkinteger(L, 4)),
                static_cast<int>(luaL_checkinteger(L, 5))};
  double shown_pts = -1;
  double pts = pMovie->refresh(rect, &shown_pts);

  // The movie's clock, and the time of the frame drawn (nil when none was).
  lua_pushnumber(L, pts);
  if (shown_pts < 0) {
    lua_pushnil(L);
  } else {
    lua_pushnumber(L, shown_pts);
  }
  return 2;
}

// moviePlayer:drawPart(sx, sy, sw, sh, dx, dy, dw, dh, flip, alpha): part of
// the frame drawn last again (source in the movie's pixels, destination on
// the screen), mirrored left to right if flip, alpha 0 to 255 (default 255).
// Returns whether there was a frame to draw from.
int l_movie_draw_part(lua_State* L) {
  ZoneScoped;

  movie_player* pMovie = luaT_testuserdata<movie_player>(L);
  SDL_FRect source{static_cast<float>(luaL_checknumber(L, 2)),
                   static_cast<float>(luaL_checknumber(L, 3)),
                   static_cast<float>(luaL_checknumber(L, 4)),
                   static_cast<float>(luaL_checknumber(L, 5))};
  SDL_FRect destination{static_cast<float>(luaL_checknumber(L, 6)),
                        static_cast<float>(luaL_checknumber(L, 7)),
                        static_cast<float>(luaL_checknumber(L, 8)),
                        static_cast<float>(luaL_checknumber(L, 9))};
  bool flip = lua_toboolean(L, 10) != 0;
  lua_Integer alpha = luaL_optinteger(L, 11, 255);
  if (alpha < 0) {
    alpha = 0;
  } else if (alpha > 255) {
    alpha = 255;
  }
  lua_pushboolean(L, pMovie->draw_part(source, destination, flip,
                                       static_cast<std::uint8_t>(alpha)));
  return 1;
}

int l_movie_allocate_picture_buffer(lua_State* L) {
  ZoneScoped;

  movie_player* pMovie = luaT_testuserdata<movie_player>(L);
  pMovie->allocate_picture_buffer();
  return 0;
}

int l_movie_deallocate_picture_buffer(lua_State* L) {
  ZoneScoped;

  movie_player* pMovie = luaT_testuserdata<movie_player>(L);
  pMovie->deallocate_picture_buffer();
  return 0;
}

}  // namespace

void lua_register_movie(const lua_register_state* pState) {
  lua_class_binding<movie_player> lcb(pState, "moviePlayer", l_movie_new,
                                      lua_metatable::movie);
  lcb.add_function(l_movie_set_renderer, "setRenderer", lua_metatable::surface);
  lcb.add_function(l_movie_enabled, "getEnabled");
  lcb.add_function(l_movie_load, "load");
  lcb.add_function(l_movie_unload, "unload");
  lcb.add_function(l_movie_play, "play");
  lcb.add_function(l_movie_stop, "stop");
  lcb.add_function(l_movie_toggle_pause, "togglePause");
  lcb.add_function(l_movie_get_native_height, "getNativeHeight");
  lcb.add_function(l_movie_get_native_width, "getNativeWidth");
  lcb.add_function(l_movie_has_audio_track, "hasAudioTrack");
  lcb.add_function(l_movie_get_length, "getLength");
  lcb.add_function(l_movie_refresh, "refresh");
  lcb.add_function(l_movie_draw_part, "drawPart");
  lcb.add_function(l_movie_allocate_picture_buffer, "allocatePictureBuffer");
  lcb.add_function(l_movie_deallocate_picture_buffer,
                   "deallocatePictureBuffer");
}
