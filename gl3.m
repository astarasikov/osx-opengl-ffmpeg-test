#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>

#import "ffmpeg_view.h"
#import <math.h>

static CVReturn displayCallback(CVDisplayLinkRef displayLink,
	const CVTimeStamp *inNow, const CVTimeStamp *inOutputTime,
	CVOptionFlags flagsIn, CVOptionFlags *flagsOut,
	void *displayLinkContext)
{
	FfmpegView *view = (FfmpegView*)displayLinkContext;
	[view renderForTime: *inOutputTime];
	return kCVReturnSuccess;
}

@implementation FfmpegView
{
	CVDisplayLinkRef displayLink;
}

-(id)initWithFrame:(NSRect)frameRect pixelFormat:(NSOpenGLPixelFormat*)format
{
	self = [super initWithFrame:frameRect pixelFormat:format];
	[self registerDisplayLink];
	return self;
}

-(void)registerDisplayLink
{
	CGDirectDisplayID displayID = CGMainDisplayID();
	CVReturn error = CVDisplayLinkCreateWithCGDisplay(displayID, &displayLink);
	NSAssert((kCVReturnSuccess == error),
		@"Creating Display Link error %d", error); 

	error = CVDisplayLinkSetOutputCallback(displayLink, displayCallback, self);
	NSAssert((kCVReturnSuccess == error),
		@"Setting Display Link callback error %d", error);
	CVDisplayLinkStart(displayLink);
}

#define QUOTE(A) #A

const char * const FRAG = "#version 150 core\n" QUOTE(
	in vec3 vert_color;
	in vec2 vert_texcoord;
	out vec4 out_color;
	//uniform sampler2D sTexture;

	void main(void) {
		//gl_FragColor = texture2D(sTexture, vert_texcoord);
		out_color = vec4(vert_color, 0.5);
	}
);

const char * const VERT = "#version 150 core\n" QUOTE(
	uniform mat4 MVP;
	in vec4 position;
	in vec3 color;
	in vec2 texcoord;
	out vec3 vert_color;
	out vec2 vert_texcoord;

	void main(void) {
		gl_Position = position;
		vert_color=color;
		vert_texcoord=texcoord;
	}
);

#define checkAndReportGlError do { \
	int _err = glGetError(); \
	if (_err) { \
		NSLog(@"GL Error %d at %d, %s", _err, __LINE__, __func__); \
	} \
} while (0)

-(void)glProgLog:(int)pid {
	GLint logLen;
	GLsizei realLen;

	glGetProgramiv(pid, GL_INFO_LOG_LENGTH, &logLen);
	char* log = (char*)malloc(logLen);
	if (log) {
		glGetProgramInfoLog(pid, logLen, &realLen, log);
		NSLog(@"program %d log %s", pid, log);
		free(log);
	}
}

-(void)glShaderLog:(int)pid {
	GLint logLen;
	GLsizei realLen;

	glGetShaderiv(pid, GL_INFO_LOG_LENGTH, &logLen);
	char* log = (char*)malloc(logLen);
	if (log) {
		glGetShaderInfoLog(pid, logLen, &realLen, log);
		NSLog(@"shader %d log %s", pid, log);
		free(log);
	}
}

-(void)projMatrix:(GLfloat*)data : 
	(GLfloat)fovy :(GLfloat)aspect :
	(GLfloat)z_near :(GLfloat)z_far
{
		float ymax = z_near * tan(fovy * M_PI / 360.0);
		float width = 2 * ymax;

		float depth = z_far - z_near;
		float d = -(z_far + z_near) / depth;
		float dn = -2 * (z_far * z_near) / depth;

		float w = 2 * z_near / width;
		float h = w * aspect;

		memset((void*)data, 0, 16 * sizeof(GLfloat));
		data[0] = w;
		data[5] = h;
		data[10] = d;
		data[11] = -1;
		data[14] = dn;
}

-(void)renderQuad
{
	const float side = 0.5f;
	GLfloat data[] = {
		//vertex coordinates
		0.0f, 0.0f, 0.0f,
		side, 0.0f, 0.0f,
		side, side, 0.0f,
		0.0f, side, 0.0f,

		//colors
		1, 0, 0,
		0, 1, 0,
		0, 0, 1,
		1, 1, 1,
	};

	GLuint indices[] = {
		0, 1, 2,
		0, 2, 3,
	};

	GLfloat mvp_data[16] = {
	};

	float aspect = ((float)self.frame.size.width)/self.frame.size.height;
	[self projMatrix:mvp_data:45.0:aspect:1:100];

	size_t vtxStride = 3;
	size_t colStride = 3;
	size_t texStride = vtxStride;
	size_t numVertices = 4;
	size_t numIndices = sizeof(indices)/sizeof(indices[0]);

	size_t coordOffset = 0;
	size_t colorOffset = 12;
	size_t texOffset = 0;

	static GLuint pid = 0;
	static GLuint vao = 0;
	static GLuint vbo = 0, vbo_idx = 0;

	static int init = 0;
	if (!init) {
		glGenVertexArrays(1, &vao);
		checkAndReportGlError;
		glBindVertexArray(vao);
		checkAndReportGlError;
		glGenBuffers(1, &vbo);
		checkAndReportGlError;
		glGenBuffers(1, &vbo_idx);
		checkAndReportGlError;

		pid = glCreateProgram();

		const char * const vsrc = VERT;
		const char * const fsrc = FRAG;
		
		GLuint vert = glCreateShader(GL_VERTEX_SHADER);
		checkAndReportGlError;
		GLuint frag = glCreateShader(GL_FRAGMENT_SHADER);
		checkAndReportGlError;

		glShaderSource(vert, 1, &vsrc, NULL);
		glCompileShader(vert);
		checkAndReportGlError;
		[self glShaderLog:vert];
		glShaderSource(frag, 1, &fsrc, NULL);
		glCompileShader(frag);
		checkAndReportGlError;
		[self glShaderLog:frag];

		glAttachShader(pid, frag);
		checkAndReportGlError;
		glAttachShader(pid, vert);
		checkAndReportGlError;

		glBindAttribLocation(pid, 0, "position");
		checkAndReportGlError;
		glBindAttribLocation(pid, 1, "color");
		glBindAttribLocation(pid, 2, "texcoord");
		glBindFragDataLocation(pid, 0, "out_color");

		glLinkProgram(pid);
		int status;
		[self glProgLog:pid];
		checkAndReportGlError;
		init = 1;
	}
	GLuint positionAttr, colorAttr, texCoordAttr, texUniform, MVP;
	
	glUseProgram(pid);
	checkAndReportGlError;

	glBindVertexArray(vao);
	checkAndReportGlError;

	positionAttr = glGetAttribLocation(pid, "position");
	checkAndReportGlError;

	colorAttr = glGetAttribLocation(pid, "color");
	checkAndReportGlError;

	texCoordAttr = glGetAttribLocation(pid, "texcoord");
	checkAndReportGlError;

	texUniform = glGetUniformLocation(pid, "sTexture");
	checkAndReportGlError;

	MVP = glGetUniformLocation(pid, "MVP");
	checkAndReportGlError;

	glBindBuffer(GL_ARRAY_BUFFER, vbo);
	checkAndReportGlError;
	glBufferData(GL_ARRAY_BUFFER, sizeof(data), data, GL_STATIC_DRAW);
	checkAndReportGlError;

	glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, vbo_idx);
	checkAndReportGlError;
	glBufferData(GL_ELEMENT_ARRAY_BUFFER,
		sizeof(indices), indices, GL_STATIC_DRAW);
	checkAndReportGlError;

	glVertexAttribPointer(positionAttr, vtxStride, GL_FLOAT, GL_FALSE, 0,
		(GLvoid*)(coordOffset * sizeof(GLfloat)));
	checkAndReportGlError;
	glVertexAttribPointer(colorAttr, colStride, GL_FLOAT, GL_FALSE, 0,
		(GLvoid*)(colorOffset * sizeof(GLfloat)));
	checkAndReportGlError;
	glVertexAttribPointer(texCoordAttr, texStride, GL_FLOAT, GL_FALSE, 0,
		(GLvoid*)(texOffset * sizeof(GLfloat)));
	checkAndReportGlError;

	glUniformMatrix4fv(MVP, 1, GL_FALSE, mvp_data);
	checkAndReportGlError;
	
	glEnableVertexAttribArray(positionAttr);
	checkAndReportGlError;
	glEnableVertexAttribArray(colorAttr);
	checkAndReportGlError;
	glEnableVertexAttribArray(texCoordAttr);
	checkAndReportGlError;

	glPolygonMode(GL_FRONT_AND_BACK, GL_FILL);

	glDrawElements(GL_TRIANGLES, numIndices, GL_UNSIGNED_INT, 0);
	glDrawElements(GL_TRIANGLE_FAN, numIndices, GL_UNSIGNED_INT, 0);
	glDrawElements(GL_POINTS, numIndices, GL_UNSIGNED_INT, indices);
	glDrawArrays(GL_TRIANGLES, 0, 4);
	checkAndReportGlError;

	glDisableVertexAttribArray(texCoordAttr);
	checkAndReportGlError;
	glDisableVertexAttribArray(colorAttr);
	checkAndReportGlError;
	glDisableVertexAttribArray(positionAttr);
	checkAndReportGlError;

	glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);
	checkAndReportGlError;
	glBindBuffer(GL_ARRAY_BUFFER, 0);
	checkAndReportGlError;
	glBindVertexArray(0);
	checkAndReportGlError;
}

-(void)renderForTime:(CVTimeStamp)time
{
	NSLog(@"Render");
	//CGLContextObj contextObj = [[self openGLContext] CGLContextObj];
	//CGLLockContext(contextObj);
	//[self lockFocus];
	if ([self lockFocusIfCanDraw] == NO) {
		return;
	}
	static int i = 0;
	double s = sin((i++ % 628) / 100.0);
	glViewport(0, 0, self.frame.size.width, self.frame.size.height);
	checkAndReportGlError;
	//glEnable(GL_CULL_FACE);
	//checkAndReportGlError;
	glEnable(GL_DEPTH_TEST);
	checkAndReportGlError;
	glEnable(GL_BLEND);
	checkAndReportGlError;
    //glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
	//glEnable(GL_TEXTURE_2D);
	//checkAndReportGlError;
	glClearColor(1, 1, 1, 1);
	checkAndReportGlError;
	glClear(GL_COLOR_BUFFER_BIT|GL_DEPTH_BUFFER_BIT);
	checkAndReportGlError;
	//glClearColor(0.0, 0.0, s >= 0 ? s : -s, 0.0);
	[self renderQuad];
	[[self openGLContext] flushBuffer];
	[self unlockFocus];
	//CGLUnlockContext(contextObj);
}

-(void)dealloc
{
	[super dealloc];
}

-(void)windowWillClose:(NSNotification *)note {
	CVDisplayLinkRelease(displayLink);
	[[NSApplication sharedApplication] terminate:self];
}
@end

@interface GLController : NSWindow
-(void)createGLView;

@property(nonatomic, readwrite, retain) FfmpegView *glView;
@end

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

#include <libavformat/avformat.h>
#include <libavcodec/avcodec.h>
#include <libswscale/swscale.h>

#define VIDEO_PATH "~/Downloads/video.mkv"

#define IS_VIDEO(stream) (stream->codec->codec_type == AVMEDIA_TYPE_VIDEO)

static void init_ffmpeg(void) {
	NSString *nspath = [@VIDEO_PATH stringByExpandingTildeInPath];
	const char *path = [nspath UTF8String];

	int stream = -1;
	AVFormatContext *fmt_context = NULL;
	AVCodecContext *codec_context = NULL;
	AVCodec *codec = NULL;

	av_register_all();

	if (avformat_open_input(&fmt_context, path, NULL, NULL) < 0) {
		NSLog(@"Failed to open the input");
		goto fail_open;
	}

	if (avformat_find_stream_info(fmt_context, NULL) < 0) {
		NSLog(@"Failed to find stream info");
		goto fail_parse_stream_info;
	}

	av_dump_format(fmt_context, 0, path, 0);
	for (stream = 0; stream < fmt_context->nb_streams; stream++) {
		if (IS_VIDEO(fmt_context->streams[stream])) {
			break;
		}
	}

	if (stream == fmt_context->nb_streams) {
		NSLog(@"Failed to find a video stream");
		goto fail_parse_stream;
	}

	codec_context = fmt_context->streams[stream]->codec;
	if (!codec_context) {
		NSLog(@"No codec context found");
		goto fail_parse_stream;
	}

	codec = avcodec_find_decoder(codec_context->codec_id);
	if (!codec) {
		NSLog(@"No codec decoder found");
		goto fail_parse_stream;
	}

	if (avcodec_open2(codec_context, codec, NULL) < 0) {
		NSLog(@"Failed to open codec");
		goto fail_parse_stream;
	}

	AVFrame *frame = avcodec_alloc_frame();
	AVPacket packet;
	while (av_read_frame(fmt_context, &packet) >= 0) {
		if (stream != packet.stream_index) {
			continue;
		}
		int frame_done;
		avcodec_decode_video2(codec_context, frame, &frame_done, &packet);
		if (!frame_done) {
			continue;
		}

		NSLog(@"Decoded frame data=%p fmt=%x width=%d height=%d qstride=%d",
			frame->data,
			frame->format,
			frame->width,
			frame->height,
			frame->qstride);
	}
	avcodec_free_frame(&frame);
	avcodec_close(codec_context);

fail_parse_stream:
fail_parse_stream_info:
	avformat_close_input(&fmt_context);
fail_open:
	[nspath release];
}

int main(int argc, char** argv) {
	//init_ffmpeg();
	NSAutoreleasePool *pool = [NSAutoreleasePool new];
	NSApplication *app = [NSApplication sharedApplication];
	GLController *controller = [[GLController alloc] init];
	[app run];
	[pool release];
	return 0;
}
