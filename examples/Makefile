CC ?= clang
CFLAGS ?= -O3 -Wall -Wextra -I../src/c/include
LDFLAGS ?= -L../lib -ldray -lm

all: c_example

c_example: c_example.c
	$(CC) $(CFLAGS) $< ../lib/libdray.a -lm -o $@

run: c_example
	./c_example

clean:
	rm -f c_example

.PHONY: all run clean
