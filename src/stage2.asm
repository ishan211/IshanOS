[BITS 16]
[ORG 0x0000]

start:
    ; Set up segment registers
    mov ax, cs
    mov ds, ax
    mov es, ax
    
    ; Clear screen
    mov ah, 0
    mov al, 3
    int 0x10

    ; Draw title
    mov si, title
    call print
    call newline
    call newline

draw_menu:
    ; Draw menu items with cursor
    call show_menu

    ; Read keyboard input
    call read_key

    ; Process key input
    cmp ah, 0x48     ; Up arrow
    je move_up
    cmp ah, 0x50     ; Down arrow
    je move_down
    cmp al, 13       ; Enter
    je select_option
    cmp al, 27       ; ESC
    je shutdown
    jmp draw_menu

move_up:
    ; Move selection cursor up
    cmp byte [sel], 0
    je draw_menu     ; Already at top
    dec byte [sel]
    jmp draw_menu

move_down:
    ; Move selection cursor down
    cmp byte [sel], 1
    je draw_menu     ; Already at bottom
    inc byte [sel]
    jmp draw_menu

select_option:
    ; Run the selected program
    cmp byte [sel], 0
    je load_editor
    cmp byte [sel], 1
    je load_snake
    jmp draw_menu

load_snake:
    ; Load the snake game from disk
    mov ax, 0x9000
    mov es, ax
    xor bx, bx          ; ES:BX = 0x9000:0000
    mov ah, 0x02        ; BIOS read sector
    mov al, 8           ; 8 sectors (4KB)
    mov ch, 0           ; cylinder
    mov cl, 11          ; sector (sector #11)
    mov dh, 0           ; head
    mov dl, 0           ; drive 0 (floppy A:)
    int 13h
    jc load_error
    
    ; Jump to snake game
    jmp 0x9000:0000

load_editor:
    ; Placeholder for text editor (not implemented yet)
    mov si, editor_msg
    call print_centered
    call newline
    call newline
    mov si, press_key_msg
    call print_centered
    
    ; Wait for keypress
    mov ah, 0
    int 0x16
    jmp draw_menu

load_error:
    ; Display load error message
    mov si, error_msg
    call print_centered
    call newline
    
    ; Wait for keypress
    mov ah, 0
    int 0x16
    jmp draw_menu

shutdown:
    ; Return to bootloader
    int 19h         ; Reboot system

show_menu:
    ; Clear menu area
    call clear_menu_area
    
    ; Draw selection cursor or space based on current selection
    mov si, menu1
    cmp byte [sel], 0
    jne not1
    mov si, selmenu1
not1:
    call print_centered
    call newline

    mov si, menu2
    cmp byte [sel], 1
    jne not2
    mov si, selmenu2
not2:
    call print_centered
    call newline
    ret

clear_menu_area:
    ; Clear the area where menu items are displayed
    mov ah, 0x02    ; Set cursor position
    mov bh, 0       ; Page 0
    mov dh, 3       ; Row 3
    mov dl, 0       ; Column 0
    int 0x10
    
    ; Clear 4 rows
    mov cx, 4
.clear_loop:
    push cx
    mov ah, 0x09    ; Write character and attribute
    mov al, ' '     ; Space
    mov bh, 0       ; Page 0
    mov bl, 0x07    ; Light gray on black
    mov cx, 80      ; 80 columns
    int 0x10
    
    ; Move cursor to next line
    mov ah, 0x02
    inc dh
    mov dl, 0
    int 0x10
    
    pop cx
    loop .clear_loop
    
    ; Reset cursor to where menu starts
    mov ah, 0x02
    mov dh, 3
    mov dl, 0
    int 0x10
    
    ret

read_key:
    ; Wait for and read a key
    xor ax, ax
    int 16h
    ret

print:
    ; Print string at SI
.next:
    lodsb
    test al, al
    je .done
    mov ah, 0x0E
    int 0x10
    jmp .next
.done:
    ret

print_centered:
    ; Calculate string length
    push si
    xor cx, cx
.count:
    lodsb
    test al, al
    je .done_count
    inc cx
    jmp .count
.done_count:
    
    ; Calculate starting column (40 - length/2)
    mov ax, 40
    sub ax, cx
    shr ax, 1
    
    ; Set cursor position
    mov ah, 0x02
    mov bh, 0
    mov dl, al
    int 0x10
    
    ; Print the string
    pop si
    call print
    ret

newline:
    mov ah, 0x0E
    mov al, 0x0D
    int 0x10
    mov al, 0x0A
    int 0x10
    ret

; Data section
sel db 0            ; Current selection (0-1)

; Menu strings
title         db "==== IshanOS 2.0 ====", 0
menu1         db "  Text Editor", 0
selmenu1      db "> Text Editor", 0
menu2         db "  Snake Game", 0
selmenu2      db "> Snake Game", 0
editor_msg    db "Text Editor coming soon!", 0
error_msg     db "Error loading program!", 0
press_key_msg db "Press any key to return to menu", 0

; Pad to exactly 512 bytes
times 512 - ($ - $$) db 0
