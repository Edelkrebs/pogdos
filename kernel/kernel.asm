ORG 0x600

BITS 16

BOOT_INFO_DRIVE_NUMBER equ 0

section .kernel

_start:
    call sys_info_init

    mov bx, kernel_greet_string
    call print_string

    mov bx, kernel_version_string
    call print_string

    jmp $

%include "kernel/drivers/floppy_disk.asm"
%include "kernel/util/debug_util.asm"
%include "kernel/system/sys_info.asm"

kernel_greet_string: db "Welcome to PogDos 16-Bit Operating System version ", 0
kernel_greet_string_len: dw $ - kernel_greet_string

kernel_version_string: db "0.0.1", 0
kernel_version_string_len: dw $ - kernel_version_string