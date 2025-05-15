[BITS 16]
[ORG 0x1000]

start:
    mov ax, 0x9000
    mov es, ax
    xor bx, bx
    call cls
    call prompt_filename
    call load_or_create_file

.main_loop:
    call draw_editor
    call show_hotkeys
    call get_key_extended
    cmp ah, 0
    je .regular_key
    cmp ah, 0x3B  ; F1
    je handle_new
    cmp ah, 0x3C  ; F2
    je handle_save
    cmp ah, 0x3D  ; F3
    je handle_exit
    jmp .main_loop

.regular_key:
    call handle_input
    jmp .main_loop

; ========== Constants ==========
%define MAX_LINES     256
%define MAX_COLS      80
%define SCREEN_LINES  22
%define TAB_WIDTH     4

; ========== Buffers ==========
filename_buf   times 11 db 0
cursor_x       dw 0
cursor_y       dw 0
scroll_offset  dw 0
modified_flag  db 0
file_lines     dw MAX_LINES
file_size      dw 0
sector_start   dw 0
sector_count   dw 0
entry_offset   dw 0
free_sector    dw 0

draw_editor:
    call cls
    mov cx, SCREEN_LINES
    xor si, si
    mov dx, [scroll_offset]
.line_loop:
    mov bx, dx
    shl bx, 7          ; bx = line offset
    add bx, si
    push cx
    call move_cursor_to_line
    mov cx, MAX_COLS
.char_loop:
    mov al, [es:bx]
    or al, al
    jz .print_space
    call print_char
    jmp .next_char
.print_space:
    mov al, ' '
    call print_char
.next_char:
    inc bx
    loop .char_loop
    inc dx
    inc si
    pop cx
    loop .line_loop
    call move_cursor
    ret

show_hotkeys:
    mov si, hotkey_msg
    call move_cursor_bottom
    call print_string
    ret

handle_input:
    cmp al, 0x0D
    je .newline
    cmp al, 0x09
    je .tab
    cmp al, 0x08
    je .backspace
    cmp al, 0x00
    je .arrow_check
    call store_char
    mov byte [modified_flag], 1
    ret

.newline:
    inc word [cursor_y]
    mov word [cursor_x], 0
    mov byte [modified_flag], 1
    ret

.tab:
    mov cx, TAB_WIDTH
.tab_loop:
    mov al, ' '
    call store_char
    loop .tab_loop
    ret

.arrow_check:
    call get_key
    cmp ah, 75
    je move_left
    cmp ah, 77
    je move_right
    cmp ah, 72
    je move_up
    cmp ah, 80
    je move_down
    ret

load_or_create_file:
    mov ax, 400
    call read_sector
    mov si, 0
.loop:
    cmp byte [es:si], 0
    je .not_found
    mov di, filename_buf
    push si
    mov cx, 11
    repe cmpsb
    pop si
    je .found
    add si, 32
    cmp si, 512
    jb .loop
.not_found:
    call clear_buffer
    xor ax, ax
    mov [sector_start], ax
    mov [sector_count], ax
    mov [file_size], ax
    mov byte [modified_flag], 0
    ret

.found:
    mov ax, [es:si+15]
    mov [sector_start], ax
    mov cx, [es:si+17]
    mov [sector_count], cx
    mov bx, 0
    mov si, 0

.next_sector:
    push cx
    call read_sector
    pop cx
    mov dx, 0
.copy_loop:
    mov al, [es:dx]
    mov [es:bx], al
    inc bx
    inc dx
    cmp dx, 512
    jb .copy_loop
    inc ax
    loop .next_sector
    mov [file_size], bx
    mov byte [modified_flag], 0
    ret

save_file:
    mov bx, 0
    mov cx, [file_size]
    add cx, 511
    shr cx, 9
    mov [sector_count], cx

    mov ax, [sector_start]
    cmp ax, 0
    jne .write_file

    call find_free_entry
    jc .fail
    call find_free_sectors
    jc .fail
    mov [sector_start], ax
    mov ax, [sector_start]

.write_file:
    push cx
.sector_loop:
    push cx
    mov si, bx
    mov dx, 0
.copy_bytes:
    mov al, [es:si]
    mov [es:dx], al
    inc si
    inc dx
    cmp dx, 512
    jb .copy_bytes
    call write_sector
    inc ax
    mov bx, si
    pop cx
    loop .sector_loop
    pop cx

    ; Update file table
    mov ax, 400
    call read_sector
    mov si, 0
.find_slot:
    cmp byte [es:si], 0
    je .write_entry
    mov di, filename_buf
    push si
    mov cx, 11
    repe cmpsb
    pop si
    je .write_entry
    add si, 32
    cmp si, 512
    jb .find_slot
    jmp .fail

.write_entry:
    mov di, si
    mov si, filename_buf
    mov cx, 11
    rep movsb
    mov ax, [file_size]
    mov [es:di], ax
    mov word [es:di+2], 0
    mov ax, [sector_start]
    mov [es:di+4], ax
    mov ax, [sector_count]
    mov [es:di+6], ax
    call write_sector
    mov byte [modified_flag], 0
    ret

.fail:
    ret

prompt_filename:
    mov si, prompt_msg
    call print_string
    mov di, filename_buf
    mov cx, 8
.read:
    call get_key
    cmp al, 0x0D
    je .pad
    stosb
    loop .read
.pad:
    mov al, ' '
    rep stosb
    mov si, ext_txt
    rep movsb
    ret

ask_save_prompt:
    mov si, save_prompt
    call print_string
    call get_key
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
    mov ax, cx
    clc
    ret
.next:
    inc cx
    cmp cx, 1400
    jbe .scan
    stc
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

get_key_extended:
    xor ah, ah
    int 16h
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

move_cursor:
    ; Calculate and move cursor (optional feature)
    ret

move_cursor_bottom:
    ; Position for hotkey row
    ret

prompt_msg     db "Enter filename (no ext): ", 0
save_prompt    db "Save changes (Y/N)? ", 0
hotkey_msg     db "[F1] New  [F2] Save  [F3] Exit", 0
ext_txt        db "TXT"
