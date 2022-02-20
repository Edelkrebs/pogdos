%ifndef __SYS_INFO_ASM
%define __SYS_INFO_ASM

%include "kernel/util/debug_util.asm"
%include "kernel/util/cpu_util.asm"

BOOT_INFO_DRIVE_NUMBER equ 0 ; Offsets for the boot info block
NO_FLOPPY equ 0x0
FLOPPY_360_KB equ 0x1
FLOPPY_720_KB equ 0x3
FLOPPY_1_2_MB equ 0x2
FLOPPY_1_44_MB equ 0x4
FLOPPY_2_88_MB equ 0x5

SYSINFO:
.boot_info_address: resw 1
.master_floppy:      db 1
.slave_floppy:       db 1  

sys_info_init:
    push ebp
    mov ebp, esp

    mov [SYSINFO.boot_info_address], bx
    
    mov al, 0x10
    out 0x70, al
    call io_wait
    in al, 0x71

    mov cl, al
    shr cl, 4
    mov [SYSINFO.master_floppy], cl
    and al, 0xF
    mov [SYSINFO.slave_floppy], al ; Get the master and slave floppy drive type(if there is one) from CMOS register 0x10

    mov esp, ebp
    pop ebp
    ret

test: db "hello", 0

%endif
