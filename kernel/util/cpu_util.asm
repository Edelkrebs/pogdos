%ifndef __CPU_UTIL_ASM
%define __CPU_UTIL_ASM

io_wait: 
    push ax
    mov al, 0
    out 0x80, al ; Write to an unused port 
    pop ax
    ret

%endif