CC ?= clang
CFLAGS ?= -O3 -Wall -Wextra -Werror -fPIC -Iinclude
LDFLAGS ?= -lm

SRC_DIR = src
OBJ_DIR = obj
BIN_DIR = ../../bin
LIB_DIR = ../../lib

SRCS = $(SRC_DIR)/dray_core.c \
       $(SRC_DIR)/dray_graph.c \
       $(SRC_DIR)/dray_solve.c \
       $(SRC_DIR)/dray_server.c \
       $(SRC_DIR)/dray_tui.c \
       $(SRC_DIR)/dray_bench.c

OBJS = $(patsubst $(SRC_DIR)/%.c, $(OBJ_DIR)/%.o, $(SRCS))

CLI_SRC = $(SRC_DIR)/dray_cli.c
CLI_OBJ = $(OBJ_DIR)/dray_cli.o
CLI_BIN = $(BIN_DIR)/dray

STATIC_LIB = $(LIB_DIR)/libdray.a
SHARED_LIB = $(LIB_DIR)/libdray.dylib

all: dirs $(STATIC_LIB) $(SHARED_LIB) $(CLI_BIN)

dirs:
	mkdir -p $(OBJ_DIR) $(BIN_DIR) $(LIB_DIR)

$(OBJ_DIR)/%.o: $(SRC_DIR)/%.c
	$(CC) $(CFLAGS) -c $< -o $@

$(STATIC_LIB): $(OBJS)
	ar rcs $@ $^

$(SHARED_LIB): $(OBJS)
	$(CC) -shared $(OBJS) $(LDFLAGS) -o $@

$(CLI_BIN): $(CLI_OBJ) $(STATIC_LIB)
	$(CC) $(CFLAGS) $< $(STATIC_LIB) $(LDFLAGS) -o $@

clean:
	rm -rf $(OBJ_DIR) $(CLI_BIN) $(STATIC_LIB) $(SHARED_LIB)

.PHONY: all dirs clean
