#ifndef SMW_SWITCH_AUDIO_H
#define SMW_SWITCH_AUDIO_H
#include <stdint.h>
#include <stddef.h>
typedef struct SmwSwitchAudio SmwSwitchAudio;
/* Interleaved signed 16-bit stereo PCM, 48 kHz by default. */
SmwSwitchAudio *smw_switch_audio_open(int sample_rate);
int smw_switch_audio_push(SmwSwitchAudio *audio, const int16_t *samples, size_t frames);
void smw_switch_audio_close(SmwSwitchAudio *audio);
#endif
