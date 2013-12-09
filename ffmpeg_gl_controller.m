#import "ffmpeg_gl_controller.h"

@implementation GLController
-(id)init
{
	self = [super initWithContentRect: NSMakeRect(0, 0, 640, 480)
		styleMask: NSTitledWindowMask|NSResizableWindowMask|
			NSClosableWindowMask|NSMiniaturizableWindowMask
		backing: NSBackingStoreBuffered
		defer: false];

	[self setTitle: @"Opengl Test"];
	[self center];
	[self createGLView];
	[self setDelegate:[self glView]];
	[self makeKeyAndOrderFront:nil];
	[self display];

	return self;
}

-(void)createGLView
{
	NSOpenGLPixelFormatAttribute attribs[] = {
		NSOpenGLPFAOpenGLProfile, NSOpenGLProfileVersion3_2Core,
		NSOpenGLPFAColorSize, 24,
		NSOpenGLPFAAlphaSize, 8,
		NSOpenGLPFADepthSize, 24,
		NSOpenGLPFAStencilSize, 8,
		NSOpenGLPFADoubleBuffer,
		NSOpenGLPFAAccelerated,
		NSOpenGLPFANoRecovery,
		NSOpenGLPFAClosestPolicy,
		0,
	};

	NSOpenGLPixelFormat *pixelFormat =
	[
		[[NSOpenGLPixelFormat alloc]
			initWithAttributes:attribs]
	autorelease];

	[self setGlView:
		[
			[[FfmpegView alloc]
				initWithFrame: [[self contentView] bounds]
				pixelFormat:pixelFormat]
		autorelease]
	];
	[[[self glView] openGLContext] makeCurrentContext];
	[self setContentView:[self glView]];
}

-(void)dealloc
{
	[[self glView] release];
	[super dealloc];
}
@end
