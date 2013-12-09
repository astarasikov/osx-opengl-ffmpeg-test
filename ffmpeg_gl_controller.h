#ifndef __FFMPEG_GL_CONTROLLER__H__
#define __FFMPEG_GL_CONTROLLER__H__

#import "ffmpeg_view.h"

@interface GLController : NSWindow
-(void)createGLView;

@property(nonatomic, readwrite, retain) FfmpegView *glView;
@end

#endif //__FFMPEG_GL_CONTROLLER__H__
