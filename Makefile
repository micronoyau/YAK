all: build run

build:
	nasm -f bin boot.s -o boot.bin

run: build
	qemu-system-x86_64 -drive file=boot.bin,format=raw

debug: build
	qemu-system-x86_64 -drive file=boot.bin,format=raw -S -gdb tcp::1234
