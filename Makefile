TARGET := pogdos.bin
ASMFILES := $(shell find -type f -name '*.asm')
OBJ := $(ASMFILES:.asm=.o)

run: image
	qemu-system-i386 -M q35 -no-reboot -no-shutdown -d int -monitor stdio -fda $(TARGET)

image: all

all: $(TARGET)

$(TARGET): clean assemble
	dd if=/dev/zero bs=512 count=2880 of=$(TARGET)
	mkfs.msdos $(TARGET)
	dd if=boot/boot.o of=$(TARGET) bs=512 count=1 conv=notrunc
	mkdir mountdir
	sudo mount -o loop -t msdos $(TARGET) mountdir
	sudo cp kernel/kernel.o mountdir/kernel.bin
	sleep 0.3
	sudo umount mountdir
	rmdir mountdir

assemble: 
	nasm -f bin boot/boot.asm -o boot/boot.o
	nasm -f bin kernel/kernel.asm -o kernel/kernel.o

clean:
	rm -rf $(TARGET) $(OBJ) 