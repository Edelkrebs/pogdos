%ifndef __SYS_INFO_ASM
%define __SYS_INFO_ASM

%include "kernel/util/debug_util.asm"
%include "kernel/util/cpu_util.asm"

struc sysinfo
    .boot_info_address: resw 1
    .master_floppy:      resb 1
    .slave_floppy:       resb 1  
endstruc

sys_info_init:
    push ebp
    mov ebp, esp

    mov [sysinfo.boot_info_address], bx

    mov al, 0x10
    out 0x70, al
    call io_wait
    in al, 0x71

    mov cl, al
    shr cl, 4
    mov [sysinfo.master_floppy], cl
    and al, 0xF
    mov [sysinfo.slave_floppy], al ; Get the master and slave floppy drive type(if there is one) from CMOS register 0x10

    mov esp, ebp
    pop ebp

test: db "hello", 0

%endif
