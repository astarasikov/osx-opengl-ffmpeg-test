#ifndef __OPENGL_VIEW__H__
#define __OPENGL_VIEW__H__

#import "common.h"

@interface MyOpenGLViewBase : NSOpenGLView <NSWindowDelegate>
-(void)registerDisplayLink;
-(void)windowWillClose:(NSNotification*)note;
-(void)renderForTime:(CVTimeStamp)time;
-(void)initializeContext;
@end

#endif //__OPENGL_VIEW__H__
