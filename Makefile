# gcc -o main main.c
CC=gcc
CFlags=-Wall -Wextra
# CLibs= -lraylib -lGL -lm -lpthread -ldl -lrt -lX11 -lwayland-client -lxkbcommon
CLibs= -lraylib -lGL -lm -lpthread -ldl -lrt
BIN=./bin/smp
IN=main.c

build:$(IN)
	@mkdir -p ./bin
	$(CC) -o $(BIN) $(IN) $(CFlags) $(CLibs)

run:build
	$(BIN)
