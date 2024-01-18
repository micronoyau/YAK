OUT="boot.bin"
FILENAME="boot.s"

all: build run

build:
	nasm -f bin $(FILENAME) -o $(OUT)

run: build
	qemu-system-x86_64 -drive file=$(OUT),format=raw

debug: build
	qemu-system-i386 -drive file=$(OUT),format=raw -S -gdb tcp::1234 &
	gdb $(OUT) \
		-ex "target remote localhost:1234" \
		-ex "set architecture i8086" \
		-ex "b *0x7c00" \
		-ex "c" \

