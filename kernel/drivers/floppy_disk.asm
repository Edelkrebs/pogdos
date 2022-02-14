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
    mov dx, FLOPPY_CONFIGURATION_CONTROL_REGISTER
    out dx, al
    mov dx, FLOPPY_DATARATE_SELECT_REGISTER
    out dx, al

.reinitialize_fdc:
    mov ch, 0 ; The Version command requires no operand bytes.
    mov cl, FDCCMD_VERSION
    call send_floppy_command

    mov sp, bp
    pop bp
    ret

send_floppy_command: ; Command in CL, number of operand bytes in CH, operand bytes on the stack(bytes have to be pushed last to first)
    push bp
    mov bp, sp

.retry_floppy_command:
    mov si, cx ; Save original command 
    mov di, cx ; Save original operand byte count
    and si, 0xFF
    shr di, 0x8
    
    mov ax, 2
    mul ch
    mov ch, al 
    add ch, 0x4 ; Get the offset on the stack for the first operand byte

    mov dx, FLOPPY_MAIN_STATUS_REGISTER
    in al, dx

    mov bl, al
    and al, 0x80
    test al, al
    jz .reset_procedure ; If the RMQ bit(Its ok to send bytes to the FIFO buffer) is not set, then restart the FDC
    
    and bl, 0x40
    test bl, bl 
    jnz .reset_procedure ; If the DIO bit(The FIFO buffer expects a opcode) is set, then restart the FDC

    mov dx, FLOPPY_DATA_FIFO
    mov al, cl
    out dx, al

    mov bl, di ; Counter
.loop_until_command_phase_over:
    mov dx, FLOPPY_MAIN_STATUS_REGISTER
    in al, dx
    mov cl, al

    push ax
    push bp
    mov dx, FLOPPY_DATA_FIFO
    add bp, ch ; Add 
    mov al, [bp]
    out dx, al 
    pop bp ; Preserve the bp between the operand byte writes, since the stack offset will be loaded with bp TODO: Optimize so that bp will be preserved outside of this loop to not do stack operations this often, since its unnecessary
    pop ax ; Preserve ax between the operand byte writes
    ; TODO: put this somehow after the checks for DIO and RQM, since if we have 0 operand bytes this will not produce valid outputs.

    mov dl, al

    and al, 0x80
    test al, al
    jz .loop_until_command_phase_over
    and cl, 0x40
    test cl, cl
    jz .loop_until_command_phase_over ; If the DIO bit is 1, which means we need to read data from the FIFO IO port, the command phase is over, and we need to go into the execution phase

    ; Outside of the main command phase loop, wont be reached in command phase
    and dl, 0x20
    test dl, dl
    jz .wait_for_result_phase ; If the NDMA bit is not set, the command has no execution phase, so we skip the execution phase

.loop_until_execution_phase_over:

    ; TODO tidy up code and implement support for execution phase commands and figure out operand byte passing into the function

.wait_for_result_phase:
    ; Wait for MSR.RQM = 1, MSR.DIO = 1
    mov dx, FLOPPY_MAIN_STATUS_REGISTER
    in al, dx

    and al, 0xc0
    cmp al, 0xc0
    jne .wait_for_result_phase ; Verify that MSR.RQM and MSR.DIO are both 1

.loop_until_result_phase_over:
    ; TODO implement a parameter in the function that the user has to specify which holds a memory location for the result bytes to be stored, for now theres just one, since I am only doing the version command, but in the future there wil be more
    ; Either waiting for a irq6, which there is no support for yet, or just read result bytes from FIFO, as long as RQM = 1, CMD BSY = 1, DIO = 1
    
    mov dx, FLOPPY_DATA_FIFO
    in al, dx
    mov bl, al ; Store al temporarily, since only doing version command with one output byte(0x90)
    
    mov dx, FLOPPY_MAIN_STATUS_REGISTER
    in al, dx
    and al, 0xD0
    cmp al, 0xD0
    jne .command_finished
    jmp .loop_until_result_phase_over

    mov dx, FLOPPY_MAIN_STATUS_REGISTER

.command_finished:
    mov dx, FLOPPY_MAIN_STATUS_REGISTER
    in al, dx

    and al, 0xD0
    cmp al, 0x80
    je .command_success
    mov cx, si
    jmp .retry_floppy_command ; If the RQM BSY or DIO flag are still set or not accordingly set after the command, retry it. (TODO: Which I should probably handle differently and check for each individual bit to be in the right state to have a accurate representation of the execution phase has ended or not and if the command was successful or not)

.command_success:
    mov bx, debug
    call print_string

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

debug: db "poggers", 0
irq6_debug_string: db "IRQ 6 triggered.", 0
unsupported_floppy_drive_error_string: db "Unsupported floppy drive used to boot this operating system.", 0

%endif