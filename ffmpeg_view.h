#ifndef __FFMPEG_VIEW__H__
#define __FFMPEG_VIEW__H__

#import "opengl_view.h"

#include <libavformat/avformat.h>
#include <libavcodec/avcodec.h>
#include <libswscale/swscale.h>

@interface FfmpegView : MyOpenGLViewBase
-(void)renderForTime:(CVTimeStamp)time;
-(void)setTexture:(AVFrame*)frame;
@end

#endif //__FFMPEG_VIEW__H__
