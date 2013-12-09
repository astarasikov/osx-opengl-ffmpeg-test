#ifndef __OPENGL_SHADERS__H__
#define __OPENGL_SHADERS__H__

#import "common.h"

#define QUOTE(A) #A

const char * const FRAG = "#version 150 core\n" QUOTE(
	in vec3 vert_color;
	in vec2 vert_texcoord;
	out vec4 out_color;
	uniform sampler2D texture_Y;
	uniform sampler2D texture_U;
	uniform sampler2D texture_V;

	void main(void) {
		vec3 yuv;
		vec3 rgb;
		yuv.x = texture(texture_Y, vert_texcoord).r;
		yuv.y = texture(texture_U, vert_texcoord).r - 0.5;
		yuv.z = texture(texture_V, vert_texcoord).r - 0.5;
		
		mat3 yuv2rgb = mat3(
			1.164, 1.164, 1.164,
			0, -0.391, 2.018,
			1.596, 0.813, 0
		);

		rgb = yuv2rgb * yuv;
		out_color = vec4(rgb, 1.0);
		//out_color = Y;
		//out_color = vec4(vert_color, 0.5);
	}
);

const char * const VERT = "#version 150 core\n" QUOTE(
	in vec4 position;
	in vec3 color;
	in vec2 texcoord;
	out vec3 vert_color;
	out vec2 vert_texcoord;

	void main(void) {
		gl_Position = position;
		vert_color = color;
		vert_texcoord = texcoord;
	}
);

#undef QUOTE

static inline void oglShaderLog(int sid) {
	GLint logLen;
	GLsizei realLen;

	glGetShaderiv(sid, GL_INFO_LOG_LENGTH, &logLen);
	if (!logLen) {
		return;
	}
	char* log = (char*)malloc(logLen);
	if (!log) {
		NSLog(@"Failed to allocate memory for the shader log");
		return;
	}
	glGetShaderInfoLog(sid, logLen, &realLen, log);
	NSLog(@"shader %d log %s", sid, log);
	free(log);
}

#endif //__OPENGL_SHADERS__H__
