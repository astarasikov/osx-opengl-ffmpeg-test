#ifndef __OPENGL_UTILS__H__
#define __OPENGL_UTILS__H__

#import "common.h"

#define ogl(x) do { \
	x; \
	int _err = glGetError(); \
	if (_err) { \
		NSLog(@"GL Error %d at %d, %s", _err, __LINE__, __func__); \
	} \
} while (0)

static inline void oglProgramLog(int pid) {
	GLint logLen;
	GLsizei realLen;

	glGetProgramiv(pid, GL_INFO_LOG_LENGTH, &logLen);
	if (!logLen) {
		return;
	}
	char* log = (char*)malloc(logLen);
	if (!log) {
		return;
	}
	glGetProgramInfoLog(pid, logLen, &realLen, log);
	NSLog(@"program %d log %s", pid, log);
	free(log);
}

static inline void projMatrix(GLfloat *data,
	GLfloat fovy, GLfloat aspect,
	GLfloat z_near, GLfloat z_far)
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

#endif //__OPENGL_UTILS__H__
