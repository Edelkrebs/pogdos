ORG 0x800

BITS 16

section .kernel

_start:
    sti

    call sys_info_init

    mov bx, [SYSINFO.boot_info_address]
    mov al, byte [bx]

    mov bx, kernel_greet_string
    call print_string

    mov bx, kernel_version_string
    call print_string

    mov bl, 0x8 ; Map the Master pic to offset 0x8
    mov bh, 0x70 ; Map the slave pic to offset 0x70
    call pic_driver_init

    call floppy_driver_init

    mov bx, done
    call print_string

    jmp $


%include "kernel/drivers/floppy_disk.asm"
%include "kernel/util/debug_util.asm"
%include "kernel/system/sys_info.asm"
%include "kernel/drivers/pic.asm"

done: db "done", 0

kernel_greet_string: db "Welcome to PogDos 16-Bit Operating System version ", 0
kernel_greet_string_len: dw $ - kernel_greet_string

kernel_version_string: db "0.0.1", 0
kernel_version_string_len: dw $ - kernel_version_string
