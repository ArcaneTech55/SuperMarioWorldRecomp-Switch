#include "smw_switch_video.h"
#include <stddef.h>
#include <stdlib.h>

SmwSwitchRect smw_switch_fit_16_9(int sw, int sh) {
  if (sw <= 0 || sh <= 0) return (SmwSwitchRect){0, 0, 0, 0};
  int w = sw, h = (int)((int64_t)sw * 9 / 16);
  if (h > sh) { h = sh; w = (int)((int64_t)sh * 16 / 9); }
  return (SmwSwitchRect){(sw - w) / 2, (sh - h) / 2, w, h};
}

#ifdef __SWITCH__
#include <SDL.h>

struct SmwSwitchVideo {
  SDL_Window *window;
  SDL_Renderer *renderer;
  SDL_Texture *texture;
  int texture_width, texture_height;
};

void smw_switch_video_destroy(SmwSwitchVideo *v) {
  if (!v) return;
  if (v->texture) SDL_DestroyTexture(v->texture);
  if (v->renderer) SDL_DestroyRenderer(v->renderer);
  if (v->window) SDL_DestroyWindow(v->window);
  free(v);
}

SmwSwitchVideo *smw_switch_video_create(void) {
  /* SDL_Init(SDL_INIT_VIDEO) must be called by the game host first. */
  SmwSwitchVideo *v = (SmwSwitchVideo*)calloc(1, sizeof(*v));
  if (!v) return NULL;
  SDL_SetHint(SDL_HINT_RENDER_SCALE_QUALITY, "nearest");
  v->window = SDL_CreateWindow("Super Mario World Recomp",
      SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED,
      1280, 720, SDL_WINDOW_SHOWN);
  if (!v->window) goto fail;
  v->renderer = SDL_CreateRenderer(v->window, -1,
      SDL_RENDERER_ACCELERATED | SDL_RENDERER_PRESENTVSYNC);
  if (!v->renderer)
    v->renderer = SDL_CreateRenderer(v->window, -1, SDL_RENDERER_SOFTWARE);
  if (!v->renderer) goto fail;
  return v;
fail:
  smw_switch_video_destroy(v);
  return NULL;
}

bool smw_switch_video_present(SmwSwitchVideo *v, const uint32_t *pixels,
                              int w, int h, int pitch_bytes) {
  if (!v || !pixels || w <= 0 || h <= 0 || w > 16384 || h > 1024 ||
      pitch_bytes < w * (int)sizeof(uint32_t)) return false;
  if (!v->texture || v->texture_width != w || v->texture_height != h) {
    if (v->texture) SDL_DestroyTexture(v->texture);
    v->texture = SDL_CreateTexture(v->renderer, SDL_PIXELFORMAT_ARGB8888,
                                   SDL_TEXTUREACCESS_STREAMING, w, h);
    if (!v->texture) {
      v->texture_width = v->texture_height = 0;
      return false;
    }
    v->texture_width = w;
    v->texture_height = h;
  }
  if (SDL_UpdateTexture(v->texture, NULL, pixels, pitch_bytes) != 0)
    return false;
  int screen_w = 1280, screen_h = 720;
  SDL_GetRendererOutputSize(v->renderer, &screen_w, &screen_h);
  SmwSwitchRect fitted = smw_switch_fit_16_9(screen_w, screen_h);
  if (fitted.w <= 0 || fitted.h <= 0) return false;
  SDL_Rect dst = {fitted.x, fitted.y, fitted.w, fitted.h};
  SDL_SetRenderDrawColor(v->renderer, 0, 0, 0, 255);
  SDL_RenderClear(v->renderer);
  if (SDL_RenderCopy(v->renderer, v->texture, NULL, &dst) != 0)
    return false;
  SDL_RenderPresent(v->renderer);
  return true;
}
#else
/* Host tests verify geometry, not a Nintendo Switch runtime. */
struct SmwSwitchVideo { int unused; };
SmwSwitchVideo *smw_switch_video_create(void) { return NULL; }
void smw_switch_video_destroy(SmwSwitchVideo *v) { (void)v; }
bool smw_switch_video_present(SmwSwitchVideo *v, const uint32_t *pixels,
                              int w, int h, int pitch_bytes) {
  (void)v; (void)pixels; (void)w; (void)h; (void)pitch_bytes;
  return false;
}
#endif
