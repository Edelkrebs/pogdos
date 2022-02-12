%ifndef __DEBUG_UTIL_ASM
%define __DEBUG_UTIL_ASM

print_string:
    push ebp
    mov ebp, esp
    pusha
    mov ah, 0x0e
.loop:
    mov al, [bx]
    mov cx, bx
    mov bl, 1
    cmp al, 0
    je .end
    int 0x10
    mov bx, cx
    inc bx
    jmp .loop
.end:
    popa
    mov esp, ebp
    pop ebp
    ret

%endif