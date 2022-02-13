%ifndef __FLOPPY_DISK_ASM
%define __FLOPPY_DISK_ASM

FLOPPY_STATUS_REGISTER_A equ 0x3F0
FLOPPY_STATUS_REGISTER_B equ 0x3F1
FLOPPY_DIGITAL_OUTPUT_REGISTER equ 0x3F2
FLOPPY_TAPE_DRIVE_REGISTER equ 0x3F3
FLOPPY_MAIN_STATUS_REGISTER equ 0x3F4           ; If read from
FLOPPY_DATARATE_SELECT_REGISTER equ 0x3F4       ; If written to
FLOPPY_DATA_FIFO equ 0x3F5
FLOPPY_DIGITAL_INPUT_REGISTER equ 0x3F7         ; If read from 
FLOPPY_CONFIGURATION_CONTROL_REGISTER equ 0x3F7 ; If written to

DRIVE_TYPE_500KBPS equ 0
DRIVE_TYPE_300KBPS equ 1
DRIVE_TYPE_250KBPS equ 2
DRIVE_TYPE_1MBPS equ 3

%include "kernel/system/sys_info.asm"
%include "kernel/util/cpu_util.asm"

floppy_driver_init:
    push ebp
    mov ebp, esp

    mov cl, 0x4
    mov ax, 6
    mul cl

    add ax, 0x20

    mov bx, ax
    mov word [bx], 0x0
    add bx, 0x2
    mov word [bx + 2], floppy_irq6_handler ; Set the IVT entry for the IRQ6 to the OS' own handler
    
; Set the low 2 bits of the CCR and the DSR according to the master floppy drive(since this OS is gonna mainly read from this one, slave floppy support may be coming later on)
; Floppy types besides 1.44 or 1.2 MB floppies are not supported
.set_ccr_and_dsr:
    mov al, [SYSINFO.master_floppy]
    cmp al, FLOPPY_1_44_MB
    je .type_500kbps
    cmp al, FLOPPY_1_2_MB
    je .type_500kbps

    mov bx, unsupported_floppy_drive_error_string
    call print_string

.type_500kbps:
    mov al, DRIVE_TYPE_500KBPS
    and al, 0x3
    out FLOPPY_CONFIGURATION_CONTROL_REGISTER, al
    out FLOPPY_DATARATE_SELECT_REGISTER, al

    mov esp, ebp
    pop ebp
    ret

reset_fdc:
    push ebp
    mov ebp, esp


    mov al, 0x80
    int 0x0
    out FLOPPY_DATARATE_SELECT_REGISTER, al
    cli
    hlt

    mov esp, ebp
    pop ebp
    ret

send_floppy_command:
    push ebp
    mov ebp, esp
    
    xor ax, ax
    in al, FLOPPY_MAIN_STATUS_REGISTER
    
    mov esp, ebp
    pop ebp
    ret

floppy_irq6_handler:
    mov bx, irq6_debug_string
    call print_string
    iret

irq6_debug_string: db "IRQ 6 triggered.", 0
unsupported_floppy_drive_error_string: db "Unsupported floppy drive used to boot this operating system.", 0

%endif