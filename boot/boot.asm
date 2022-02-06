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

start:
    mov byte [BPB.drive_number], dl

    mov ax, 0
    mov bx, ax
    mov cx, ax
    mov dx, ax
    mov sp, ax
    mov bp, ax
    
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax

    mov ax, 0x500
    mov ss, ax

    ;Calculate essential fat12 info
    mov ax, [BPB.reserved_sectors]
    mov word [FAT12_INFO.fat_location], ax ;LBA address for FAT(1 in this case)

calculate_root_dir_start: ; number_of_fats * (sectors_per_fat * bytes_per_sector) + reserved_sectors
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
    mov bx, [FAT12_INFO.root_dir_location]
    add bx, [BPB.root_dir_entries]
    mov ax, 32
    mul bx
    add ax, [BPB.bytes_per_sector]
    sub ax, 1
    mov word [FAT12_INFO.data_location], ax ;Address of first data sector: FAT12_INFO.root_dir_location + BPB.root_dir_entries * 32 + BPB.bytes_per_sector - 1 

load_kernel:
.load_root_dir:
    xor dx, dx
    mov ax, [BPB.heads]
    mov bx, [BPB.sectors_per_track]
    mul bx
    xor dx, dx
    mov bx, ax
    mov ax, [FAT12_INFO.root_dir_location]
    div bx ; Calculating the cylinder(LBA divided by (heads per cylinder times sectors per track))
    
    mov ch, al

    xor dx, dx
    mov ax, [FAT12_INFO.root_dir_location]
    mov bx, [BPB.sectors_per_track]
    div bx
    xor dx, dx
    mov bx, [BPB.heads]
    div bx ;Calculating the head((LBA divided by secotrs per track) modulo heads)
    
    mov cl, dl

    xor dx, dx
    mov ax, [FAT12_INFO.root_dir_location]
    div word [BPB.sectors_per_track]
    add dl, 1

    mov dh, cl
    mov cl, dl

    mov dl, [BPB.drive_number]
    mov ah, 2
    mov al, 1
    mov bx, 0x7e00

    int 0x13

    jc error

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
    je .end
    inc di
    jmp .str_loop ; Compare the entry name in the root directory with the kernels file name

.end:
    jmp $

string: db "error", 0
string2: db "success", 0

error:
    mov bx, string
    call print_string
    jmp $

lba_to_chs: ; AX = LBA position, returns cylinder in CH, Sector in CL, Head in DH
    xor dx, dx
    div word [BPB.sectors_per_track]
    mov cl, dl
    inc cl ; Divide the LBA by the sectors per track to get the track number in al and the sector as a remainder in dl and increment by one because sector counting starts not at 0, but at 1

    xor dx, dx
    div word [BPB.heads]
    mov ch, al
    mov dh, dl ; Divide the track number by the heads present on the device to get the current head as a remainder and the track on that side of the disk as a result

    ret

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

kernel_file: db "KERNEL  BIN"
kernel_file_len: db $ - kernel_file

DiskAddressPacket:
.size: db 0x10
.unused: db 0
.sector_count: dw 14
.destination: dd 0x7c00
.lba_position: dq 13

FAT12_INFO:
.fat_location: dw 0
.root_dir_location: dw 0
.root_dir_size: dw 0
.data_location: dw 0

times 510 - ($ - $$) db 0
dw 0xAA55