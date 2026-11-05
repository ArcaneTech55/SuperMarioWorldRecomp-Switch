/* Native Switch platform diagnostic, not yet SMW gameplay. */
#include <switch.h>
#include <SDL.h>
#include <stdint.h>
#include <stdlib.h>
#include <sys/stat.h>
#include "smw_switch_video.h"
#include "smw_switch_input.h"
#include "smw_switch_audio.h"
#include "smw_switch_save.h"
enum { W=SMW_SWITCH_WIDE_WIDTH, H=SMW_SWITCH_WIDE_HEIGHT };
static uint32_t screen[W*H];
int main(int argc, char **argv) {
 (void)argc; (void)argv;
 if (R_FAILED(fsdevMountSdmc())) return 1;
 mkdir("sdmc:/switch",0777);
 mkdir("sdmc:/switch/smw-recomp",0777);
 if (SDL_Init(SDL_INIT_VIDEO|SDL_INIT_AUDIO)!=0) return 2;
 if (!smw_switch_input_init()) return 3;
 SmwSwitchVideo *video=smw_switch_video_create();
 if (!video) return 4;
 SmwSwitchAudio *audio=smw_switch_audio_open(48000);
 const char *save="sdmc:/switch/smw-recomp/platform-check.dat";
 unsigned counter=0;
 (void)smw_switch_save_read(save,&counter,sizeof(counter));
 uint16_t last=0;
 int offset=0, save_ok=0, phase=0;
 while (appletMainLoop()) {
   SmwSwitchPad pad=smw_switch_input_poll();
   if(pad.snes & SMW_SNES_LEFT) --offset;
   if(pad.snes & SMW_SNES_RIGHT) ++offset;
   if((pad.snes & SMW_SNES_X) && !(last & SMW_SNES_X)) {
     ++counter;
     save_ok=smw_switch_save_write(save,&counter,sizeof(counter));
   }
   for (int y=0;y<H;y++) for(int x=0;x<W;x++) {
     int check=(((x+offset)/16 + y/16)&1);
     uint32_t r=(uint32_t)(save_ok && x<32 && y<12 ? 255 : (check?72:26));
     uint32_t g=(uint32_t)(x<43?160:x>W-43?100:40);
     uint32_t b=(uint32_t)(pad.snes && y>H-12?220:80);
     screen[y*W+x]=0xff000000u|(r<<16)|(g<<8)|b;
   }
   if (audio) {
     int16_t buf[1600];
     for(int i=0;i<800;i++) {
       phase=(phase+440)%48000;
       int16_t v=(pad.snes & SMW_SNES_B)?(phase<24000?1200:-1200):0;
       buf[i*2]=buf[i*2+1]=v;
     }
     (void)smw_switch_audio_push(audio,buf,800);
   }
   if(!smw_switch_video_present(video,screen,W,H,W*4)) break;
   last=pad.snes;
   SDL_Delay(16);
 }
 smw_switch_audio_close(audio);
 smw_switch_video_destroy(video);
 smw_switch_input_exit();
 SDL_Quit();
 fsdevUnmountAll();
 return 0;
}
