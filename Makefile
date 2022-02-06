TARGET := pogdos.bin
ASMFILES := $(shell find -type f -name '*.asm')
OBJ := $(ASMFILES:.asm=.o)

run: image
	qemu-system-i386 -no-reboot -no-shutdown -monitor stdio -fda $(TARGET)

image: all

all: $(TARGET)

$(TARGET): clean $(OBJ)
	dd if=/dev/zero bs=512 count=2880 of=$(TARGET)
	mkfs.msdos $(TARGET)
	dd if=boot/boot.o of=$(TARGET) bs=512 count=1 conv=notrunc
	mkdir mountdir
	sudo mount -o loop -t msdos $(TARGET) mountdir
	sudo cp kernel/kernel.o mountdir/kernel.bin
	sudo umount mountdir
	rmdir mountdir

%.o:%.asm
	nasm -fbin $< -o $@

clean:
	rm -rf $(TARGET) $(OBJ) 