#import "ffmpeg_view.h"
#import "ffmpeg_gl_controller.h"
#import "opengl_shaders.h"
#import "opengl_utils.h"
#import "opengl_view.h"
#import <math.h>

#define QuadSide 0.7f 

static GLfloat QuadData[] = {
	//vertex coordinates
	-QuadSide, -QuadSide, 0.0f,
	QuadSide, -QuadSide, 0.0f,
	QuadSide, QuadSide, 0.0f,
	-QuadSide, QuadSide, 0.0f,

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

static GLuint QuadIndices[] = {
	0, 1, 2,
	0, 2, 3,
};

static const size_t VertexStride = 3;
static const size_t ColorStride = 3;
static const size_t TexCoordStride = 2;

static const size_t CoordOffset = 0;
static const size_t ColorOffset = 12;
static const size_t TexCoordOffset = 24;

static const size_t NumVertices = 4;
static const size_t NumIndices = 6;//sizeof(QuadIndices) / sizeof(QuadIndices[0]);

@implementation FfmpegView
{
	GLuint _programId;
	GLuint _vao;
	GLuint _vbo;
	GLuint _vbo_idx;

	GLuint _positionAttr;
	GLuint _colorAttr;
	GLuint _texCoordAttr;

	GLuint _textures[3];
}

-(void)initializeContext
{
	static int init = 0;
	if (init) {
		return;
	}

	ogl(glGenVertexArrays(1, &_vao));
	ogl(glBindVertexArray(_vao));
	ogl(glGenBuffers(1, &_vbo));
	ogl(glGenBuffers(1, &_vbo_idx));
	
	ogl(_programId = glCreateProgram());

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

	ogl(glAttachShader(_programId, frag));
	ogl(glAttachShader(_programId, vert));

	ogl(glBindAttribLocation(_programId, 0, "position"));
	ogl(glBindAttribLocation(_programId, 1, "color"));
	ogl(glBindAttribLocation(_programId, 2, "texcoord"));
	ogl(glBindFragDataLocation(_programId, 0, "out_color"));

	ogl(glLinkProgram(_programId));
	ogl(oglProgramLog(_programId));

	ogl(glGenTextures(3, _textures));
	
	glPolygonMode(GL_FRONT_AND_BACK, GL_FILL);
	ogl(glEnable(GL_DEPTH_TEST));
	ogl(glEnable(GL_BLEND));
    ogl(glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA));
	
	//XXX: fix this
	init = 1;
}

-(void)renderQuad
{
	GLfloat mvp_data[16] = {
	};

	float aspect = ((float)self.frame.size.width)/self.frame.size.height;
	projMatrix(mvp_data, 45.0, aspect, 1.0, 100.0);

	GLuint texUniform;

	ogl(glUseProgram(_programId));
	ogl(glBindVertexArray(_vao));
	ogl(_positionAttr = glGetAttribLocation(_programId, "position"));
	ogl(_colorAttr = glGetAttribLocation(_programId, "color"));
	ogl(_texCoordAttr = glGetAttribLocation(_programId, "texcoord"));
	ogl(texUniform = glGetUniformLocation(_programId, "sTexture"));
	//ogl(MVP = glGetUniformLocation(_programId, "MVP"));

	ogl(glBindBuffer(GL_ARRAY_BUFFER, _vbo));
	ogl(glBufferData(GL_ARRAY_BUFFER, sizeof(QuadData), QuadData, GL_STATIC_DRAW));

	ogl(glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _vbo_idx));
	ogl(glBufferData(GL_ELEMENT_ARRAY_BUFFER,
		sizeof(QuadIndices), QuadIndices, GL_STATIC_DRAW));

	ogl(glVertexAttribPointer(_positionAttr, VertexStride,
		GL_FLOAT, GL_FALSE, 0,
		(GLvoid*)(CoordOffset * sizeof(GLfloat))));
	ogl(glVertexAttribPointer(_colorAttr, ColorStride,
		GL_FLOAT, GL_FALSE, 0,
		(GLvoid*)(ColorOffset * sizeof(GLfloat))));
	ogl(glVertexAttribPointer(_texCoordAttr, TexCoordStride,
		GL_FLOAT, GL_FALSE, 0,
		(GLvoid*)(TexCoordOffset * sizeof(GLfloat))));

	//ogl(glUniformMatrix4fv(MVP, 1, GL_FALSE, mvp_data));

	ogl(glEnableVertexAttribArray(_positionAttr));
	ogl(glEnableVertexAttribArray(_colorAttr));
	ogl(glEnableVertexAttribArray(_texCoordAttr));

	ogl(glDrawElements(GL_TRIANGLES, NumIndices, GL_UNSIGNED_INT, 0));

	ogl(glDisableVertexAttribArray(_texCoordAttr));
	ogl(glDisableVertexAttribArray(_colorAttr));
	ogl(glDisableVertexAttribArray(_positionAttr));

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

	[self initializeContext];
	ogl(glViewport(0, 0, self.frame.size.width, self.frame.size.height));
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

	for (size_t i = 0; i < 1; i++) {
		ogl(glBindTexture(GL_TEXTURE_2D, _textures[i]));
			
		ogl(glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR));
		ogl(glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR));
		ogl(glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE));
		ogl(glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE));

		ogl(glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB,
			frame->linesize[0],
			frame->height, 0, GL_RED,
			GL_UNSIGNED_BYTE, frame->data[0]));
	}

	ogl(glActiveTexture(GL_TEXTURE0));
	
	CGLUnlockContext(contextObj);
	[self unlockFocus];
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
