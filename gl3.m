#import "ffmpeg_view.h"
#import "ffmpeg_gl_controller.h"
#import "opengl_shaders.h"
#import "opengl_utils.h"
#import <math.h>

#include <libavformat/avformat.h>
#include <libavcodec/avcodec.h>
#include <libswscale/swscale.h>

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

-(void)renderQuad
{
	const float side = 0.7f;
	GLfloat data[] = {
		//vertex coordinates
		-side, -side, 0.0f,
		side, -side, 0.0f,
		side, side, 0.0f,
		-side, side, 0.0f,

		//colors
		1, 0, 0,
		0, 1, 0,
		0, 0, 1,
		1, 1, 1,

		//texture coordinates
		0, 0,
		1, 0,
		1, 1,
		0, 1,
	};

	GLuint indices[] = {
		0, 1, 2,
		0, 2, 3,
	};

	GLfloat mvp_data[16] = {
	};

	float aspect = ((float)self.frame.size.width)/self.frame.size.height;
	projMatrix(mvp_data, 45.0, aspect, 1.0, 100.0);

	size_t vtxStride = 3;
	size_t colStride = 3;
	size_t texStride = 2;
	size_t numVertices = 4;
	size_t numIndices = sizeof(indices)/sizeof(indices[0]);

	size_t coordOffset = 0;
	size_t colorOffset = 12;
	size_t texOffset = 24;

	static GLuint pid = 0;
	static GLuint vao = 0;
	static GLuint vbo = 0, vbo_idx = 0;

	static int init = 0;
	if (!init) {
		// should really do this on context loss/reinit
		ogl(glGenVertexArrays(1, &vao));
		ogl(glBindVertexArray(vao));
		ogl(glGenBuffers(1, &vbo));
		ogl(glGenBuffers(1, &vbo_idx));
		
		ogl(pid = glCreateProgram());

		const char * const vsrc = VERT;
		const char * const fsrc = FRAG;

		GLuint vert, frag;
		ogl(vert = glCreateShader(GL_VERTEX_SHADER));
		ogl(frag = glCreateShader(GL_FRAGMENT_SHADER));

		ogl(glShaderSource(vert, 1, &vsrc, NULL));
		ogl(glCompileShader(vert));
		oglShaderLog(vert);

		ogl(glShaderSource(frag, 1, &fsrc, NULL));
		ogl(glCompileShader(frag));
		oglShaderLog(frag);

		ogl(glAttachShader(pid, frag));
		ogl(glAttachShader(pid, vert));

		ogl(glBindAttribLocation(pid, 0, "position"));
		ogl(glBindAttribLocation(pid, 1, "color"));
		ogl(glBindAttribLocation(pid, 2, "texcoord"));
		ogl(glBindFragDataLocation(pid, 0, "out_color"));

		ogl(glLinkProgram(pid));
		ogl(oglProgramLog(pid));
		init = 1;
	}
	GLuint positionAttr, colorAttr, texCoordAttr, texUniform, MVP,
		sampler;
	
	ogl(glUseProgram(pid));
	ogl(glBindVertexArray(vao));
	ogl(positionAttr = glGetAttribLocation(pid, "position"));
	ogl(colorAttr = glGetAttribLocation(pid, "color"));
	ogl(texCoordAttr = glGetAttribLocation(pid, "texcoord"));
	ogl(texUniform = glGetUniformLocation(pid, "sTexture"));
	ogl(MVP = glGetUniformLocation(pid, "MVP"));
	ogl(sampler = glGetUniformLocation(pid, "texture"));

	ogl(glBindBuffer(GL_ARRAY_BUFFER, vbo));
	ogl(glBufferData(GL_ARRAY_BUFFER, sizeof(data), data, GL_STATIC_DRAW));

	ogl(glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, vbo_idx));
	ogl(glBufferData(GL_ELEMENT_ARRAY_BUFFER,
		sizeof(indices), indices, GL_STATIC_DRAW));

	ogl(glVertexAttribPointer(positionAttr, vtxStride, GL_FLOAT, GL_FALSE, 0,
		(GLvoid*)(coordOffset * sizeof(GLfloat))));
	ogl(glVertexAttribPointer(colorAttr, colStride, GL_FLOAT, GL_FALSE, 0,
		(GLvoid*)(colorOffset * sizeof(GLfloat))));
	ogl(glVertexAttribPointer(texCoordAttr, texStride, GL_FLOAT, GL_FALSE, 0,
		(GLvoid*)(texOffset * sizeof(GLfloat))));

	ogl(glUniformMatrix4fv(MVP, 1, GL_FALSE, mvp_data));

	ogl(glEnableVertexAttribArray(positionAttr));
	ogl(glEnableVertexAttribArray(colorAttr));
	ogl(glEnableVertexAttribArray(texCoordAttr));

	//ogl(glActiveTexture(GL_TEXTURE0));
	//ogl(glBindTexture(GL_TEXTURE_2D, 0));
	//ogl(glUniform1i(sampler, 1));

	ogl(glDrawElements(GL_TRIANGLES, numIndices, GL_UNSIGNED_INT, 0));
	//ogl(glDrawElements(GL_TRIANGLE_FAN, numIndices, GL_UNSIGNED_INT, 0));
	ogl(glDrawElements(GL_POINTS, numIndices, GL_UNSIGNED_INT, indices));
	//ogl(glDrawArrays(GL_TRIANGLES, 0, 4));

	ogl(glDisableVertexAttribArray(texCoordAttr));
	ogl(glDisableVertexAttribArray(colorAttr));
	ogl(glDisableVertexAttribArray(positionAttr));

	ogl(glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0));
	ogl(glBindBuffer(GL_ARRAY_BUFFER, 0));
	ogl(glBindVertexArray(0));
}

-(void)renderForTime:(CVTimeStamp)time
{
	NSLog(@"Render");
	if ([self lockFocusIfCanDraw] == NO) {
		return;
	}
	CGLContextObj contextObj = [[self openGLContext] CGLContextObj];
	CGLLockContext(contextObj);

	ogl(glViewport(0, 0, self.frame.size.width, self.frame.size.height));
	glPolygonMode(GL_FRONT_AND_BACK, GL_FILL);
	ogl(glEnable(GL_DEPTH_TEST));
	ogl(glEnable(GL_BLEND));
    ogl(glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA));
	ogl(glClearColor(1, 1, 1, 1));
	ogl(glClear(GL_COLOR_BUFFER_BIT|GL_DEPTH_BUFFER_BIT));
	[self renderQuad];
	[[self openGLContext] flushBuffer];

	CGLUnlockContext(contextObj);
	[self unlockFocus];
}

-(void)setTexture:(AVFrame*)frame {
	if ([self lockFocusIfCanDraw] == NO) {
		return;
	}
	CGLContextObj contextObj = [[self openGLContext] CGLContextObj];
	CGLLockContext(contextObj);

	static int texture = -1;
	if (texture < 0) {
		ogl(glGenTextures(1, &texture));
	}
	ogl(glBindTexture(GL_TEXTURE_2D, texture));
		
	ogl(glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR));
	ogl(glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR));
	ogl(glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE));
	ogl(glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE));

	ogl(glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB,
		frame->width, frame->height, 0, GL_RED,
		GL_UNSIGNED_BYTE, frame->data[0]));

	ogl(glActiveTexture(GL_TEXTURE0));
	
	CGLUnlockContext(contextObj);
	[self unlockFocus];
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

#define VIDEO_PATH "~/Downloads/video.mkv"

#define IS_VIDEO(stream) (stream->codec->codec_type == AVMEDIA_TYPE_VIDEO)

static void init_ffmpeg(id controller) {
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
			frame->data[0],
			frame->format,
			frame->width,
			frame->height,
			frame->qstride);
		[[controller glView] setTexture: frame];
	}
	avcodec_free_frame(&frame);
	avcodec_close(codec_context);

fail_parse_stream:
fail_parse_stream_info:
	avformat_close_input(&fmt_context);
fail_open:
	[nspath release];
}

static void async_ffmpeg(id controller) {
	dispatch_queue_t q = dispatch_queue_create("q_ffmpeg", NULL);
	dispatch_async(q, ^{
		init_ffmpeg(controller);
	});
	dispatch_release(q);
}

int main(int argc, char** argv) {
	NSAutoreleasePool *pool = [NSAutoreleasePool new];
	NSApplication *app = [NSApplication sharedApplication];
	GLController *controller = [[GLController alloc] init];
	async_ffmpeg(controller);
	[app run];
	[pool release];
	return 0;
}
