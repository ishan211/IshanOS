[BITS 16]
[ORG 0x1000]

start:
    mov ax, 0x9000
    mov es, ax
    xor bx, bx

menu:
    call cls
    call dir
    call newline
    mov si, menu_prompt
    call print_string
    call get_key
    cmp al, '1'
    je create_file
    cmp al, '2'
    je delete_file
    cmp al, '3'
    je cat_file
    jmp menu

create_file:
    call cls
    mov si, create_prompt
    call print_string
    call read_filename
    call find_free_entry
    jc menu
    call find_free_sectors
    jc menu

    call cls
    mov si, input_prompt
    call print_string

    mov bx, 0
.input_loop:
    call get_key
    cmp al, 0x13
    je .done_input
    cmp al, 0x0D
    jne .not_enter
    mov byte [es:bx], 0x0D
    inc bx
    mov byte [es:bx], 0x0A
    inc bx
    call newline
    jmp .input_loop
.not_enter:
    mov [es:bx], al
    inc bx
    call print_char
    cmp bx, 5120
    jb .input_loop
.done_input:
    mov [input_size], bx
    mov si, 0
    mov ax, [free_sector]
    mov cx, bx
    add cx, 511
    shr cx, 9
    mov [sector_count], cx
    push cx
.write_loop:
    mov di, si
    mov bx, 0
.write_byte:
    cmp di, [input_size]
    jae .pad_rest
    mov al, [es:di]
    mov [es:bx], al
    inc bx
    inc di
    cmp bx, 512
    jne .write_byte
    jmp .flush_sector
.pad_rest:
    cmp bx, 512
    je .flush_sector
    mov byte [es:bx], 0
    inc bx
    jmp .pad_rest
.flush_sector:
    call write_sector
    inc ax
    loop .write_loop
    pop cx

    mov ax, 400
    call read_sector
    mov si, [entry_offset]
    mov di, si
    mov si, filename_buf
    mov cx, 11
    rep movsb

    mov ax, [input_size]
    mov [es:di], ax
    mov word [es:di+2], 0
    mov ax, [free_sector]
    mov [es:di+4], ax
    mov ax, [sector_count]
    mov [es:di+6], ax
    call write_sector
    jmp menu

delete_file:
    call cls
    mov si, delete_prompt
    call print_string
    call read_filename
    mov ax, 400
    call read_sector
    mov si, 0
.loop:
    mov cx, 11
    mov di, filename_buf
    push si
    repe cmpsb
    pop si
    je .found
    add si, 32
    cmp si, 512
    jb .loop
    jmp menu
.found:
    mov cx, 32
    mov di, si
    xor ax, ax
.clear:
    stosb
    loop .clear
    call write_sector
    jmp menu

cat_file:
    call cls
    mov si, cat_prompt
    call print_string
    call read_filename
    mov ax, 400
    call read_sector
    mov si, 0
.find:
    push si
    mov di, filename_buf
    mov cx, 11
    repe cmpsb
    pop si
    je .found
    add si, 32
    cmp si, 512
    jb .find
    jmp menu
.found:
    mov ax, [es:si+15]
    mov cx, [es:si+17]
    mov bx, 0
.next_sector:
    push ax
    call read_sector
    pop ax
    mov si, 0
.char_loop:
    mov al, [es:si]
    cmp al, 0
    je .skip
    call print_char
.skip:
    inc si
    cmp si, 512
    jb .char_loop
    inc ax
    loop .next_sector
    call newline
    jmp menu

dir:
    mov ax, 400
    call read_sector
    mov si, 0
.next:
    cmp byte [es:si], 0
    je .done
    push si
    mov cx, 11
    call print_n_chars
    call newline
    pop si
    add si, 32
    cmp si, 512
    jb .next
.done:
    ret

read_filename:
    mov di, filename_buf
    mov cx, 11
.read:
    call get_key
    cmp al, 0x0D
    je .pad
    stosb
    loop .read
.pad:
    mov al, ' '
    rep stosb
    ret

find_free_entry:
    mov ax, 400
    call read_sector
    mov si, 0
.check:
    cmp byte [es:si], 0
    je .found
    add si, 32
    cmp si, 512
    jb .check
    stc
    ret
.found:
    mov word [entry_offset], si
    clc
    ret

find_free_sectors:
    mov cx, 401
.scan:
    mov ax, cx
    call read_sector
    mov si, 0
    mov dx, 0
.chk:
    cmp word [es:si], 0
    jne .next
    add si, 2
    inc dx
    cmp dx, 512
    jb .chk
    mov word [free_sector], cx
    clc
    ret
.next:
    inc cx
    cmp cx, 1400
    jbe .scan
    stc
    ret

print_n_chars:
.loop:
    lodsb
    call print_char
    loop .loop
    ret

print_string:
    lodsb
    or al, al
    jz .done
    call print_char
    jmp print_string
.done:
    ret

print_char:
    mov ah, 0x0E
    int 10h
    ret

newline:
    mov al, 0x0D
    call print_char
    mov al, 0x0A
    call print_char
    ret

cls:
    mov ax, 0x0600
    mov bh, 0x07
    mov cx, 0
    mov dx, 0x184F
    int 10h
    ret

get_key:
    mov ah, 0
    int 16h
    ret

read_sector:
    push dx
    push cx
    push ax
    mov dl, 0
    mov dh, 0
    xor ch, ch
    mov cl, al
    mov al, 1
    mov ah, 2
    int 13h
    pop ax
    pop cx
    pop dx
    ret

write_sector:
    push dx
    push cx
    push ax
    mov dl, 0
    mov dh, 0
    xor ch, ch
    mov cl, al
    mov al, 1
    mov ah, 3
    int 13h
    pop ax
    pop cx
    pop dx
    ret

; ==== Data ====

menu_prompt     db "1. Create  2. Delete  3. View (cat)",0
create_prompt   db "Filename to create: ",0
delete_prompt   db "Filename to delete: ",0
cat_prompt      db "Filename to view: ",0
input_prompt    db "Enter file text. Ctrl+S to save:",0

filename_buf    times 11 db 0
entry_offset    dw 0
free_sector     dw 0
input_size      dw 0
sector_count    dw 0

times 510-($-$$) db 0
dw 0xAA55

