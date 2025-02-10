# gcc -o main main.c
CC=gcc
CFlags=-Wall -Wextra
# CLibs= -lraylib -lGL -lm -lpthread -ldl -lrt -lX11 -lwayland-client -lxkbcommon
CLibs= -lraylib -lGL -lm -lpthread -ldl -lrt
BIN=./bin/smp

preset:
	@mkdir -p ./bin

build:preset
	$(CC) -o $(BIN) main.c $(CFlags) $(CLibs)

run:build
	$(BIN)
