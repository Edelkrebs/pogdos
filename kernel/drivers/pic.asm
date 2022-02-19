%ifndef __PIC_ASM
%define __PIC_ASM

%define MASTER_PIC_COMMAND 0x20
%define MASTER_PIC_DATA 0x21
%define SLAVE_PIC_COMMAND 0xA0
%define SLAVE_PIC_DATA 0xA1

%define PIC_EOI 0x20
%define PIC_INIT 0x11


pic_driver_init: ; BL = Vector offset master, BH = master offset slave
    push bp
    mov bp, sp
    push ax
    push cx

    cli

    in al, MASTER_PIC_DATA ; Get the current masking status of the master pic
    mov cl, al
    in al, SLAVE_PIC_DATA ; Get the current masking status of the slave pic
    mov ch, al

    mov al,  PIC_INIT
    out MASTER_PIC_COMMAND, al
    call io_wait
    out SLAVE_PIC_COMMAND, al
    call io_wait ; Initialize master and slave pic
    
    mov al, bl
    out MASTER_PIC_DATA, al
    call io_wait
    mov al, bh
    out SLAVE_PIC_DATA, al
    call io_wait ; Remap the PICs accordingly

    mov al, 0x4
    out MASTER_PIC_DATA, al ; Tell the master pic that the slave PIC sends IRQs through IRQ 2 
    call io_wait
    mov al, 0x2
    out SLAVE_PIC_DATA, al ; Tell the slave pic that it resides on IRQ 2
    call io_wait

    mov al, 0x1
    out MASTER_PIC_DATA, al ; 8086 Mode
    call io_wait
    out SLAVE_PIC_DATA, al ; 8086 Mode
    call io_wait

    mov al, cl
    out MASTER_PIC_DATA, al ; Restore masks
    mov al, ch
    out SLAVE_PIC_DATA, al ; Restore masks

    sti

    pop cx
    pop ax
    mov sp, bp
    pop bp
    ret

pic_eoi: ; AL stores the IRQ
    push ax
    cmp al, 0x8
    jl .done
    mov al, PIC_EOI
    out SLAVE_PIC_COMMAND, al
.done:
    out MASTER_PIC_COMMAND, al
    pop ax
    ret

%include "kernel/util/cpu_util.asm"

%endif
