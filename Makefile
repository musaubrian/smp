# gcc -o main main.c
CC=gcc
CFlags=-Wall -Wextra
CLibs=-lglfw -lGL -lm -lpthread -ldl -lrt
BIN=./bin/smp

preset:
	@mkdir -p ./bin

build:preset
	$(CC) -o $(BIN) main.c $(CFlags) $(CLibs)

run:build
	$(BIN)
