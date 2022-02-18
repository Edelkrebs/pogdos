org 0x7c00

BITS 16

section .boot
    jmp short 0x3e
    nop

BPB:
.oem_id: db "POGCHAMP"
.bytes_per_sector: dw 512
.sectors_per_cluster: db 1
.reserved_sectors: dw 1
.fat_count: db 2
.root_dir_entries: dw 224
.total_sectors: dw 2880
.media_descriptor_byte: db 0xf0
.sectors_per_fat: dw 9
.sectors_per_track: dw 18
.heads: dw 2
.hidden_sectors: dd 0
.large_sectors: dd 0
.drive_number: db 0
.nt_flags: db 0
.signature: db 0x29
.serial_number: dd 0x0
.label_string: db "POGCHAMPDOS"
.system_identifier: db "FAT12   "

ROOT_DIR_ENTRY_SIZE equ 32
DOS_FILE_NAME_OFFSET equ 0
DOS_FILE_EXTENSION_OFFSET equ 0x8
FILE_ATTRIBUTES_OFFSET equ 0xb
FIRST_CLUSTER_OFFSET equ 0x1a
KERNEL_MEMORY_LOCATION equ 0x800

start:
    mov byte [BPB.drive_number], dl
    mov byte [BOOT_INFO.drive_number], dl

    mov ax, 0
    mov bx, ax
    mov cx, ax
    mov dx, ax
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax

    mov ax, 0x800
    mov sp, ax
    mov bp, ax

    push bx
    mov bx, boot_phase
    call print_string
    pop bx

    ;Calculate essential fat12 info
    mov ax, [BPB.reserved_sectors]
    mov word [FAT12_INFO.fat_location], ax ;LBA address for FAT(1 in this case)

calculate_root_dir_start: ; number_of_fats * sectors_per_fat + reserved_sectors
    mov ax, [BPB.sectors_per_fat]
    mov bl, byte [BPB.fat_count]
    mul bx
    add ax, [BPB.reserved_sectors]

    mov word [FAT12_INFO.root_dir_location], ax ;LBA address for root directory

calculate_root_dir_size: ; (root_dir_entries * root_dir_entry_size) / bytes_per_sector
    xor dx, dx
    mov ax, [BPB.root_dir_entries]
    mov bx, ROOT_DIR_ENTRY_SIZE
    mul bl ; (root_dir_entries * root_dir_entry_size)
    
    div word [BPB.bytes_per_sector] ; (root_dir_entries * root_dir_entry_size) / bytes_per_sector 
    mov word [FAT12_INFO.root_dir_size], ax

calculate_fat_data_start:
    mov ax, [FAT12_INFO.root_dir_location]
    add ax, [FAT12_INFO.root_dir_size]

    mov word [FAT12_INFO.data_location], ax ; (root_dir_location + root_dir_size)
load_kernel:
.load_root_dir:
    mov di, [FAT12_INFO.root_dir_location]
    mov ax, [FAT12_INFO.root_dir_size]
    mov bx, 0x7e00
    call load_sector

    mov bx, 0x7e00 - ROOT_DIR_ENTRY_SIZE

.find_kernel_entry:
    add bx, 0x20
    cmp byte [bx], 0xE5
    je .find_kernel_entry ; Check if file actually exists
    cmp byte [bx], 0x0F
    je .find_kernel_entry ; Check if its long filename entry

    mov di, 0
.str_loop: 
    mov al, byte [bx + di]
    cmp al, byte [kernel_file + di]    
    jne .find_kernel_entry
    cmp di, 10
    je .end_find_kernel
    inc di
    jmp .str_loop ; Compare the entry name in the root directory with the kernels file name

.end_find_kernel:
    mov [kernel_file_loc], bx

    mov cx, 0
    add bx, [BPB.bytes_per_sector] ; Load the fat right after the first sector of the loaded root directory(0x8000) for later reference
    mov ax, [BPB.sectors_per_fat]
    mov di, [BPB.reserved_sectors]
    call load_sector

.load_kernel_clusters: ; Kernel will be loaded at address starting from 0x800, leaving 0x300 bytes for the stack
    mov bx, [kernel_file_loc]
    add bx, FIRST_CLUSTER_OFFSET
    mov ax, [bx] ; Load ax with the first cluster in the FAT of the kernel file 

    mov bx, KERNEL_MEMORY_LOCATION - 0x200
.find_next_cluster: ; Starting FAT cluster in ax
    push bx
    mov si, ax ; Store the current cluster value in si for later
    mov cx, 2
    div cx

    mov cl, 3
    mul cl

    mov bx, 0x8000
    add bx, ax ; Get the next cluster number by doing current_cluster_in_ax / 2 * 3
    cmp dx, 0
    jne .uneven_cluster

    mov ax, [bx]
    and ax, 0xFFF

    jmp .check_cluster

.uneven_cluster:
    mov ax, [bx + 1]
    ror ah, 0x4
    shr ax, 0x4
    
.check_cluster:
    pop bx
    add bx, 0x200 ; Get the correct destination address for the current kernel sector by popping the previously saved bx value off the stack

    pusha ; Save all the registers so they wont get lost during disk access
    mov di, si
    add di, [FAT12_INFO.data_location]
    sub di, 2 ; Calculate the sector from the cluster by doing first_data_sector - 2(because data clusters start at 3) + current_cluster
    mov ax, 1
    call load_sector
    popa

    cmp ax, 0xFFF
    je .end_kernel_read

    cmp ax, 0xFF0
    jg load_sector.error

    cmp ax, 0x2
    jl load_sector.error

    jmp .find_next_cluster

.end_kernel_read:
    mov bx, BOOT_INFO
    jmp KERNEL_MEMORY_LOCATION ; Jump to the kernel offset

load_sector: ; LBA stored in DI, Destination stored in BX, Sector read count stored in AX
    push bx
    push ax
    xor dx, dx
    mov ax, [BPB.heads]
    mov bx, [BPB.sectors_per_track]
    mul bx
    xor dx, dx
    mov bx, ax
    mov ax, di
    div bx ; Calculating the cylinder(LBA divided by (heads per cylinder times sectors per track))
    
    mov ch, al

    xor dx, dx
    mov ax, di
    mov bx, [BPB.sectors_per_track]
    div bx
    xor dx, dx
    mov bx, [BPB.heads]
    div bx ;Calculating the head((LBA divided by secotrs per track) modulo heads)
    
    mov cl, dl

    xor dx, dx
    mov ax, di
    div word [BPB.sectors_per_track]
    add dl, 1

    mov dh, cl
    mov cl, dl

    mov dl, [BPB.drive_number]
    mov ah, 2
    pop ax
    pop bx
    mov ah, 2

    int 0x13

    jc .error ; TODO: comment this better
    ret 
.error:
    mov bx, error_string
    call print_string
    jmp $
error_string: db "error", 0
debug_string: db "debug", 0
boot_phase: db "Entering boot phase", 0

print_string:
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
    ret

debug:
    push bx
    mov bx, debug_string
    call print_string
    pop bx
    jmp $

kernel_file: db "KERNEL  BIN"
kernel_file_len: db $ - kernel_file
kernel_file_loc: dw 0

FAT12_INFO:
.fat_location: dw 0
.root_dir_location: dw 0
.root_dir_size: dw 0
.data_location: dw 0

BOOT_INFO:
.drive_number db 0

times 510 - ($ - $$) db 0
dw 0xAA55