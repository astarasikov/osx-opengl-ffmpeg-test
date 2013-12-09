#ifndef __OPENGL_SHADERS__H__
#define __OPENGL_SHADERS__H__

#import "common.h"

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
		return;
	}
	glGetShaderInfoLog(sid, logLen, &realLen, log);
	NSLog(@"shader %d log %s", sid, log);
	free(log);
}

#endif //__OPENGL_SHADERS__H__
