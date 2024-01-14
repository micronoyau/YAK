all: build run

build:
	nasm -f bin loop.s -o loop

run: build
	qemu-system-x86_64 -drive file=loop,format=raw

debug: build
	qemu-system-x86_64 -drive file=loop,format=raw -S -gdb tcp::1234
