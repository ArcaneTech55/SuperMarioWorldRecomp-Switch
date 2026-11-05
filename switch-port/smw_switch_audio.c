#include "smw_switch_audio.h"
#include <stdlib.h>
#ifdef __SWITCH__
#include <SDL.h>
struct SmwSwitchAudio { SDL_AudioDeviceID device; };
SmwSwitchAudio *smw_switch_audio_open(int sample_rate) {
  if (sample_rate <= 0) return NULL;
  SmwSwitchAudio *a = (SmwSwitchAudio *)calloc(1, sizeof(*a));
  if (!a) return NULL;
  SDL_AudioSpec spec = {0}, obtained = {0};
  spec.freq = sample_rate;
  spec.format = AUDIO_S16SYS;
  spec.channels = 2;
  spec.samples = 1024;
  a->device = SDL_OpenAudioDevice(NULL, 0, &spec, &obtained, 0);
  if (!a->device) { free(a); return NULL; }
  SDL_PauseAudioDevice(a->device, 0);
  return a;
}
int smw_switch_audio_push(SmwSwitchAudio *a, const int16_t *samples, size_t frames) {
  if (!a || !samples || frames > UINT32_MAX / (2 * sizeof(int16_t))) return 0;
  /* Limit latency rather than enqueue unbounded frames if game pauses. */
  if (SDL_GetQueuedAudioSize(a->device) > 48000u * 4u / 2u) return 0;
  return SDL_QueueAudio(a->device, samples,
                        (Uint32)(frames * 2 * sizeof(int16_t))) == 0;
}
void smw_switch_audio_close(SmwSwitchAudio *a) {
  if (!a) return;
  SDL_CloseAudioDevice(a->device);
  free(a);
}
#else
struct SmwSwitchAudio { int placeholder; };
SmwSwitchAudio *smw_switch_audio_open(int rate) {(void)rate; return NULL;}
int smw_switch_audio_push(SmwSwitchAudio *a, const int16_t *p, size_t n) {
  (void)a; (void)p; (void)n; return 0;
}
void smw_switch_audio_close(SmwSwitchAudio *a) {(void)a;}
#endif
