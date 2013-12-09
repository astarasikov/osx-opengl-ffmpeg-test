APPNAME=gl3
CC=gcc
CFLAGS=-pg
LDFLAGS=-framework Cocoa \
	-framework CoreVideo \
	-framework OpenGL \
	-lavcodec \
	-lavformat

CFILES = \
	gl3.m

OBJFILES=$(patsubst %.m,%.o,$(CFILES))

all: $(APPNAME)

$(APPNAME): $(OBJFILES)
	$(CC) $(LDFLAGS) $(CFLAGS) -o $@ $(OBJFILES)

$(OBJFILES): %.o: %.m
	$(CC) $(CFLAGS) -c $< -o $@

clean:
	rm $(APPNAME)
	rm *.o

run:
	make clean
	make all
	cp $(APPNAME) $(APPNAME).app/Contents/MacOS/$(APPNAME)
	#open $(APPNAME).app
	./$(APPNAME)
