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

FDCPCMD_READ_TRACK equ 2
FDCCMD_SPECIFY equ 3
FDCCMD_SENSE_DRIVE_STATUS equ 4
FDCCMD_WRITE_DATA equ 5
FDCCMD_READ_DATA equ 6
FDCCMD_RECALIBRATE equ 7
FDCCMD_SENSE_INTERRUPT equ 8
FDCCMD_WRITE_DELETED_DATA equ 9
FDCCMD_READ_ID equ 10
FDCCMD_READ_DELETED_DATA equ 12
FDCCMD_FORMAT_TRACK equ 13
FDCCMD_DUMPREG equ 14
FDCCMD_SEEK equ 15
FDCCMD_VERSION equ 16
FDCCMD_SCAN_EQUAL equ 17
FDCCMD_PERPENDICULAR_MODE equ 18
FDCCMD_CONFIGURE equ 19
FDCCMD_LOCK equ 20
FDCCMD_VERIFY equ 22
FDCCMD_SCAN_LOW_OR_EQUAL equ 25
FDCCMD_SCAN_HIGH_OR_EQUAL equ 29

DRIVE_TYPE_500KBPS equ 0
DRIVE_TYPE_300KBPS equ 1
DRIVE_TYPE_250KBPS equ 2
DRIVE_TYPE_1MBPS equ 3

%include "kernel/system/sys_info.asm"
%include "kernel/util/cpu_util.asm"

floppy_driver_init:
    push bp
    mov bp, sp

    mov bx, 0x38
    mov word [bx + 2], 0x0
    mov word [bx], floppy_irq6_handler ; Set the IVT entry for the IRQ6 to the OS' own handler
    
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
    mov dx, FLOPPY_CONFIGURATION_CONTROL_REGISTER
    out dx, al
    mov dx, FLOPPY_DATARATE_SELECT_REGISTER
    out dx, al

.reinitialize_fdc:
    push 0x0 ; Test operand byte
    push 0xb01000000 ; Test operand byte
    push 0x0 ; Test operand byte
    mov di, 0x9000 ; TODO replace this with a variable
    mov cl, FDCCMD_VERSION 
    call send_floppy_command

    mov sp, bp
    pop bp
    ret

send_floppy_command: ; Command in CL, Destination of the operand bytes in DI, operand bytes on the stack(bytes have to be pushed in reverse order), DMA will not be supported as long as compatability with QEMU is important, maybe there will be a DMA version of this for non-QEMU VMs in the future
    push bp
    mov bp, sp

.retry_floppy_command:
    mov si, cx ; Save original command
    
    mov ax, 2
    mul ch
    mov ch, al 
    add ch, 0x4 ; Get the offset on the stack for the first operand byte

    mov dx, FLOPPY_MAIN_STATUS_REGISTER
    in al, dx
    mov dl, al

    and al, 0xC0
    cmp al, 0x80
    jne .reset_procedure

    mov dx, FLOPPY_MAIN_STATUS_REGISTER
    in al, dx

    mov dx, FLOPPY_DATA_FIFO
    mov al, cl
    out dx, al ; After each write RQM is set to 0 by the FDC

.wait_for_rqm: ; So we wait for it to be 1 again
    and dl, 0x80
    test dl, dl
    jz .wait_for_rqm

    mov cx, 4; Counter
.send_command_bytes_loop:
    mov dx, FLOPPY_MAIN_STATUS_REGISTER
    in al, dx
    mov ah, al
    and al, 0x10 
    test al, al 
    jz .command_finished ; If the BSY bit is not set, the command got no result phase, so the command is done after the last command byte has been sent 
    mov al, ah
    and al, 0xc0
    cmp al, 0x80
    jne .post_command_byte_stage ; If the DIO bit is set or the RMQ bit is not set,  
    ; TODO maybe try to differenciate between command and execution phase and actually get whats going on

    mov bx, bp
    add bx, cx
    mov ax, [bx]
    mov dx, FLOPPY_DATA_FIFO
    out dx, al 
    add cx, 2

    xor bx, bx
    mov bl, al
    call print_byte_debug
    
    jmp .send_command_bytes_loop 

.post_command_byte_stage:
    mov bx, done_with_command_phase
    call print_string

    mov dx, FLOPPY_MAIN_STATUS_REGISTER
    in al, dx
    and al, 0x20
    test al, al
    jz .result_phase ; Wait for NDMA to be 0, so that the execution phase is over and we can go into the result phase
    jmp .post_command_byte_stage

.result_phase:
    mov bx, di
.loop_until_result_phase_over:
    ; Either waiting for a irq6, which there is no support for yet, or just read result bytes from FIFO, as long as RQM = 1, CMD BSY = 1, DIO = 1
    mov dx, FLOPPY_MAIN_STATUS_REGISTER
    in al, dx

    mov dx, FLOPPY_DATA_FIFO
    in al, dx
    mov byte [bx], al
    jmp $

    mov dx, FLOPPY_MAIN_STATUS_REGISTER
    in al, dx
    and al, 0xD0
    cmp al, 0xD0
    jne .command_finished
    inc bx
    jmp .loop_until_result_phase_over ; TODO tidy up these bit flag checks

.command_finished:
    mov dx, FLOPPY_MAIN_STATUS_REGISTER
    in al, dx

    and al, 0xD0
    cmp al, 0x80
    je .command_success
    mov cx, si
    jmp .retry_floppy_command ; If the RQM BSY or DIO flag are still set or not accordingly set after the command, retry it. (TODO: Which I should probably handle differently and check for each individual bit to be in the right state to have a accurate representation of the execution phase has ended or not and if the command was successful or not)

.command_success:

    mov sp, bp
    pop bp
    ret
.reset_procedure:
    call reset_fdc

    mov sp, bp
    pop bp
    ret

reset_fdc:
    push bp
    mov bp, sp

    mov al, 0x80
    int 0x0
    out FLOPPY_DATARATE_SELECT_REGISTER, al
    cli
    hlt

    mov sp, bp
    pop bp
    ret

floppy_irq6_handler:
    mov bx, irq6_debug_string
    call print_string
    iret

done_with_command_phase: db "Done with command phase!", 0
debug: db "poggers", 0
irq6_debug_string: db "IRQ 6 triggered.", 0
unsupported_floppy_drive_error_string: db "Unsupported floppy drive used to boot this operating system.", 0

print_byte_debug: ; such bad code satan would be scared if he looked at it 
    pusha

    mov di, bx
    mov ah, 0x0e
    shr bx, 0x4

    mov al, bl
    cmp al, 0x9
    jle .under_ten
    add al, 0x40
    jmp .done_adding

.under_ten:
    add al, 0x30

.done_adding:
    int 0x10

    mov bx, di
    mov ah, 0x0e
    and bx, 0xF

    mov al, bl
    cmp al, 0x9
    jle .under_ten2
    add al, 0x40
    jmp .done_adding2

.under_ten2:
    add al, 0x30

.done_adding2:
    int 0x10
.done
    popa
    ret

%endif