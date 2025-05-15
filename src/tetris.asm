[BITS 16]
[ORG 0x0000]

; --- Constants ---
VIDEO_SEG       equ 0xB800
SCREEN_WIDTH    equ 80
SCREEN_HEIGHT   equ 25
GRID_WIDTH      equ 10
GRID_HEIGHT     equ 20
GRID_X_OFFSET   equ 30
GRID_Y_OFFSET   equ 2
BLOCK_CHAR      equ 0xDB
EMPTY_CHAR      equ 0x20

; Colors
COLOR_BLOCK     equ 0x0A  ; Bright green
COLOR_EMPTY     equ 0x00  ; Black
COLOR_BORDER    equ 0x0F  ; White
COLOR_TEXT      equ 0x0E  ; Yellow

; Tetromino shapes (4 rotations × 4 blocks × 7 pieces)
PIECES:
    ; I piece
    db 0,0, 0,1, 0,2, 0,3
    db 0,0, 1,0, 2,0, 3,0
    db 0,0, 0,1, 0,2, 0,3
    db 0,0, 1,0, 2,0, 3,0
    
    ; J piece
    db 0,0, 1,0, 1,1, 1,2
    db 0,1, 0,0, 1,0, 2,0
    db 0,0, 0,1, 0,2, 1,2
    db 0,1, 1,1, 2,1, 2,0
    
    ; L piece
    db 0,2, 1,0, 1,1, 1,2
    db 0,0, 1,0, 2,0, 2,1
    db 0,0, 0,1, 0,2, 1,0
    db 0,0, 0,1, 1,1, 2,1
    
    ; O piece
    db 0,0, 0,1, 1,0, 1,1
    db 0,0, 0,1, 1,0, 1,1
    db 0,0, 0,1, 1,0, 1,1
    db 0,0, 0,1, 1,0, 1,1
    
    ; S piece
    db 0,1, 0,2, 1,0, 1,1
    db 0,0, 1,0, 1,1, 2,1
    db 0,1, 0,2, 1,0, 1,1
    db 0,0, 1,0, 1,1, 2,1
    
    ; T piece
    db 0,1, 1,0, 1,1, 1,2
    db 0,0, 1,0, 1,1, 2,0
    db 0,0, 0,1, 0,2, 1,1
    db 0,1, 1,0, 1,1, 2,1
    
    ; Z piece
    db 0,0, 0,1, 1,1, 1,2
    db 0,1, 1,0, 1,1, 2,0
    db 0,0, 0,1, 1,1, 1,2
    db 0,1, 1,0, 1,1, 2,0

; Game variables
current_piece   dw 0
current_rot     dw 0
current_x       dw 4
current_y       dw 0
next_piece      dw 0
score           dw 0
level           dw 0
lines           dw 0
game_grid       times GRID_WIDTH*GRID_HEIGHT db 0
drop_counter    dw 0
drop_speed      dw 30
game_over_flag  db 0

start:
    mov ax, cs
    mov ds, ax
    mov ax, VIDEO_SEG
    mov es, ax

    call clear_screen
    call draw_border
    call draw_ui
    call new_piece
    
    mov ah, 0
    int 0x1A
    mov [next_piece], dx
    and word [next_piece], 7

game_loop:
    call handle_input
    cmp byte [game_over_flag], 1
    je game_over
    
    inc word [drop_counter]
    mov ax, [drop_speed]
    cmp word [drop_counter], ax  ; Fixed: added 'word'
    jae .do_drop                 ; Fixed: changed to jae + jmp
    jmp .no_drop
.do_drop:
    mov word [drop_counter], 0
    call move_down
.no_drop:
    
    call draw_grid
    call draw_current_piece
    call draw_next_piece
    call draw_score
    
    mov cx, 0x0001
    mov dx, 0x0000
    mov ah, 0x86
    int 0x15
    
    jmp game_loop

game_over:
    mov si, game_over_msg
    mov cx, 11
    mov di, (12 * SCREEN_WIDTH + 30) * 2
    mov ah, COLOR_TEXT
.print_loop:
    lodsb
    stosw
    loop .print_loop
    
    mov ah, 0
    int 0x16
    jmp 0x8000:0x0000

new_piece:
    mov ax, [next_piece]
    mov [current_piece], ax
    
    mov ah, 0
    int 0x1A
    mov [next_piece], dx
    and word [next_piece], 7
    cmp word [next_piece], 7
    jb .valid_piece
    mov word [next_piece], 0
.valid_piece:
    
    mov word [current_x], 4
    mov word [current_y], 0
    mov word [current_rot], 0
    
    call check_collision
    cmp al, 0
    je .no_collision
    mov byte [game_over_flag], 1
.no_collision:
    ret

check_collision:
    push bx
    push cx
    push dx
    push si
    
    mov ax, [current_piece]
    mov bx, 32
    mul bx
    mov si, PIECES
    add si, ax
    
    mov ax, [current_rot]
    shl ax, 3
    add si, ax
    
    mov cx, 4
.check_blocks:
    mov al, [si]
    cbw
    add ax, [current_y]
    cmp ax, 0
    jl .collision
    cmp ax, GRID_HEIGHT
    jge .collision
    
    mov bl, [si+1]
    mov bh, 0
    add bx, [current_x]
    cmp bx, 0
    jl .collision
    cmp bx, GRID_WIDTH
    jge .collision
    
    push ax
    push bx
    mov ax, GRID_WIDTH
    mul word [current_y]
    add ax, bx
    mov si, game_grid
    add si, ax
    pop bx
    pop dx
    cmp byte [si], 0
    jne .collision
    
    add si, 2
    loop .check_blocks
    
    xor al, al
    jmp .done
    
.collision:
    mov al, 1
.done:
    pop si
    pop dx
    pop cx
    pop bx
    ret

lock_piece:
    push bx
    push cx
    push dx
    push si
    
    mov ax, [current_piece]
    mov bx, 32
    mul bx
    mov si, PIECES
    add si, ax
    
    mov ax, [current_rot]
    shl ax, 3
    add si, ax
    
    mov cx, 4
.set_blocks:
    mov al, [si]
    cbw
    add ax, [current_y]
    
    mov bl, [si+1]
    mov bh, 0
    add bx, [current_x]
    
    push ax
    push bx
    mov ax, GRID_WIDTH
    mul word [current_y]
    add ax, bx
    mov di, game_grid
    add di, ax
    pop bx
    pop dx
    mov byte [di], 1
    
    add si, 2
    loop .set_blocks
    
    call check_lines
    call new_piece
    
    pop si
    pop dx
    pop cx
    pop bx
    ret

check_lines:
    push bx
    push cx
    push dx
    push si
    push di
    
    mov cx, GRID_HEIGHT-1
.line_loop:
    mov bx, cx
    dec bx
    mov al, 1
    
    mov si, 0
.check_line:
    push bx
    push si
    mov ax, GRID_WIDTH
    mul bx
    add ax, si
    mov di, game_grid
    add di, ax
    pop si
    pop bx
    cmp byte [di], 0
    jne .not_empty
    mov al, 0
.not_empty:
    inc si
    cmp si, GRID_WIDTH
    jb .check_line
    
    cmp al, 1
    jne .next_line
    
    mov si, cx
    dec si
.shift_loop:
    cmp si, 0
    je .clear_top
    mov di, si
    dec di
    
    push cx
    mov cx, GRID_WIDTH
.copy_loop:
    push bx
    push cx
    mov ax, GRID_WIDTH
    mul di
    add ax, cx
    dec ax
    mov bx, game_grid
    add bx, ax
    mov al, [bx]
    
    mov ax, GRID_WIDTH
    mul si
    add ax, cx
    dec ax
    mov bx, game_grid
    add bx, ax
    mov [bx], al
    pop cx
    pop bx
    loop .copy_loop
    pop cx
    
    dec si
    jmp .shift_loop
    
.clear_top:
    mov si, 0
    mov al, 0
.clear_loop:
    mov [game_grid + si], al
    inc si
    cmp si, GRID_WIDTH
    jb .clear_loop
    
    add word [score], 100
    inc word [lines]
    
    mov ax, [lines]
    mov bl, 10
    div bl
    cmp ah, 0
    jne .next_line
    cmp [drop_speed], 5
    jle .next_line
    sub word [drop_speed], 2
    inc word [level]
    
    inc cx
    
.next_line:
    loop .line_loop
    
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    ret

move_left:
    dec word [current_x]
    call check_collision
    cmp al, 0
    je .valid_move
    inc word [current_x]
.valid_move:
    ret

move_right:
    inc word [current_x]
    call check_collision
    cmp al, 0
    je .valid_move
    dec word [current_x]
.valid_move:
    ret

move_down:
    inc word [current_y]
    call check_collision
    cmp al, 0
    je .valid_move
    dec word [current_y]
    call lock_piece
.valid_move:
    ret

rotate:
    inc word [current_rot]
    mov ax, [current_rot]
    cmp ax, 4
    jb .valid_rot
    mov word [current_rot], 0
.valid_rot:
    call check_collision
    cmp al, 0
    je .rotation_ok
    dec word [current_x]
    call check_collision
    cmp al, 0
    je .rotation_ok
    add word [current_x], 2
    call check_collision
    cmp al, 0
    je .rotation_ok
    sub word [current_x], 1
    dec word [current_rot]
    cmp word [current_rot], -1
    jne .no_underflow
    mov word [current_rot], 3
.no_underflow:
.rotation_ok:
    ret

handle_input:
    mov ah, 1
    int 0x16
    jz .no_input
    
    mov ah, 0
    int 0x16
    
    cmp ah, 0x4B
    je .left
    cmp ah, 0x4D
    je .right
    cmp ah, 0x48
    je .rotate
    cmp ah, 0x50
    je .down
    cmp al, ' '
    je .hard_drop
    cmp al, 27
    je exit_game
    jmp .no_input
    
.left:
    call move_left
    jmp .no_input
.right:
    call move_right
    jmp .no_input
.rotate:
    call rotate
    jmp .no_input
.down:
    call move_down
    jmp .no_input
.hard_drop:
    call hard_drop
.no_input:
    ret

hard_drop:
.drop_loop:
    inc word [current_y]
    call check_collision
    cmp al, 0
    je .drop_loop
    dec word [current_y]
    call lock_piece
    ret

draw_grid:
    push bx
    push cx
    push dx
    push si
    
    mov cx, GRID_HEIGHT
    mov bx, 0
.row_loop:
    push cx
    mov cx, GRID_WIDTH
    mov si, 0
.col_loop:
    mov ax, bx
    add ax, GRID_Y_OFFSET
    mov dx, si
    add dx, GRID_X_OFFSET
    
    mov di, ax
    imul di, SCREEN_WIDTH
    add di, dx
    shl di, 1
    
    push bx
    push si
    mov ax, GRID_WIDTH
    mul bx
    add ax, si
    mov si, game_grid
    add si, ax
    pop si
    pop bx
    mov al, [si]
    cmp al, 0
    je .empty
    
    mov ax, COLOR_BLOCK * 256 + BLOCK_CHAR
    jmp .draw
.empty:
    mov ax, COLOR_EMPTY * 256 + EMPTY_CHAR
.draw:
    mov [es:di], ax
    
    inc si
    loop .col_loop
    
    inc bx
    pop cx
    loop .row_loop
    
    pop si
    pop dx
    pop cx
    pop bx
    ret

draw_current_piece:
    push bx
    push cx
    push dx
    push si
    
    mov ax, [current_piece]
    mov bx, 32
    mul bx
    mov si, PIECES
    add si, ax
    
    mov ax, [current_rot]
    shl ax, 3
    add si, ax
    
    mov cx, 4
.draw_blocks:
    mov al, [si]
    cbw
    add ax, [current_y]
    add ax, GRID_Y_OFFSET
    
    mov bl, [si+1]
    mov bh, 0
    add bx, [current_x]
    add bx, GRID_X_OFFSET
    
    mov di, ax
    imul di, SCREEN_WIDTH
    add di, bx
    shl di, 1
    
    mov ax, COLOR_BLOCK * 256 + BLOCK_CHAR
    mov [es:di], ax
    
    add si, 2
    loop .draw_blocks
    
    pop si
    pop dx
    pop cx
    pop bx
    ret

draw_next_piece:
    push bx
    push cx
    push dx
    push si
    
    mov cx, 4
    mov di, (5 * SCREEN_WIDTH + 50) * 2
    mov ax, COLOR_EMPTY * 256 + EMPTY_CHAR
.clear_loop:
    mov [es:di], ax
    mov [es:di+2], ax
    mov [es:di+4], ax
    mov [es:di+6], ax
    add di, SCREEN_WIDTH * 2
    loop .clear_loop
    
    mov ax, [next_piece]
    mov bx, 32
    mul bx
    mov si, PIECES
    add si, ax
    
    mov cx, 4
.draw_blocks:
    mov al, [si]
    cbw
    add ax, 6
    
    mov bl, [si+1]
    mov bh, 0
    add bx, 50
    
    mov di, ax
    imul di, SCREEN_WIDTH
    add di, bx
    shl di, 1
    
    mov ax, COLOR_BLOCK * 256 + BLOCK_CHAR
    mov [es:di], ax
    
    add si, 2
    loop .draw_blocks
    
    pop si
    pop dx
    pop cx
    pop bx
    ret

draw_score:
    push bx
    push cx
    push dx
    
    mov si, score_label
    mov cx, 6
    mov di, (5 * SCREEN_WIDTH + 50) * 2
    mov ah, COLOR_TEXT
.draw_label:
    lodsb
    stosw
    loop .draw_label
    
    mov ax, [score]
    mov bx, 10
    mov cx, 5
    mov di, (6 * SCREEN_WIDTH + 50) * 2 + 8
.draw_digits:
    xor dx, dx
    div bx
    add dl, '0'
    mov dh, COLOR_TEXT
    mov [es:di], dx
    sub di, 2
    loop .draw_digits
    
    mov si, lines_label
    mov cx, 6
    mov di, (8 * SCREEN_WIDTH + 50) * 2
    mov ah, COLOR_TEXT
.draw_lines_label:
    lodsb
    stosw
    loop .draw_lines_label
    
    mov ax, [lines]
    mov bx, 10
    mov cx, 5
    mov di, (9 * SCREEN_WIDTH + 50) * 2 + 8
.draw_lines_digits:
    xor dx, dx
    div bx
    add dl, '0'
    mov dh, COLOR_TEXT
    mov [es:di], dx
    sub di, 2
    loop .draw_lines_digits
    
    mov si, level_label
    mov cx, 6
    mov di, (11 * SCREEN_WIDTH + 50) * 2
    mov ah, COLOR_TEXT
.draw_level_label:
    lodsb
    stosw
    loop .draw_level_label
    
    mov ax, [level]
    mov bx, 10
    mov cx, 1
    mov di, (12 * SCREEN_WIDTH + 50) * 2 + 8
.draw_level_digits:
    xor dx, dx
    div bx
    add dl, '0'
    mov dh, COLOR_TEXT
    mov [es:di], dx
    sub di, 2
    loop .draw_level_digits
    
    pop dx
    pop cx
    pop bx
    ret

draw_ui:
    mov si, next_label
    mov cx, 10
    mov di, (3 * SCREEN_WIDTH + 50) * 2
    mov ah, COLOR_TEXT
.draw_next:
    lodsb
    stosw
    loop .draw_next
    
    mov si, controls
    mov cx, 32
    mov di, (15 * SCREEN_WIDTH + 45) * 2
    mov ah, COLOR_TEXT
.draw_controls:
    lodsb
    stosw
    loop .draw_controls
    
    ret

draw_border:
    ; Top border
    mov cx, GRID_WIDTH + 2
    mov ax, (GRID_Y_OFFSET - 1) * SCREEN_WIDTH * 2
    add ax, (GRID_X_OFFSET - 1) * 2
    mov di, ax
    mov ax, COLOR_BORDER * 256 + 196
.top:
    stosw
    loop .top

    ; Bottom border
    mov cx, GRID_WIDTH + 2
    mov ax, (GRID_Y_OFFSET + GRID_HEIGHT) * SCREEN_WIDTH * 2
    add ax, (GRID_X_OFFSET - 1) * 2
    mov di, ax
    mov ax, COLOR_BORDER * 256 + 196
.bot:
    stosw
    loop .bot

    ; Vertical borders
    mov cx, GRID_HEIGHT + 2
    mov si, GRID_Y_OFFSET - 1
.vert_loop:
    push cx
    ; Left border
    mov ax, si
    mov bx, SCREEN_WIDTH * 2
    mul bx
    add ax, (GRID_X_OFFSET - 1) * 2
    mov di, ax
    mov ax, COLOR_BORDER * 256 + 179
    stosw
    
    ; Right border
    mov ax, si
    mov bx, SCREEN_WIDTH * 2
    mul bx
    add ax, (GRID_X_OFFSET + GRID_WIDTH) * 2
    mov di, ax
    mov ax, COLOR_BORDER * 256 + 179
    stosw
    
    inc si
    pop cx
    loop .vert_loop
    
    ; Corners
    ; Top-left
    mov ax, (GRID_Y_OFFSET - 1) * SCREEN_WIDTH * 2
    add ax, (GRID_X_OFFSET - 1) * 2
    mov di, ax
    mov ax, COLOR_BORDER * 256 + 218
    stosw
    
    ; Top-right
    mov ax, (GRID_Y_OFFSET - 1) * SCREEN_WIDTH * 2
    add ax, (GRID_X_OFFSET + GRID_WIDTH) * 2
    mov di, ax
    mov ax, COLOR_BORDER * 256 + 191
    stosw
    
    ; Bottom-left
    mov ax, (GRID_Y_OFFSET + GRID_HEIGHT) * SCREEN_WIDTH * 2
    add ax, (GRID_X_OFFSET - 1) * 2
    mov di, ax
    mov ax, COLOR_BORDER * 256 + 192
    stosw
    
    ; Bottom-right
    mov ax, (GRID_Y_OFFSET + GRID_HEIGHT) * SCREEN_WIDTH * 2
    add ax, (GRID_X_OFFSET + GRID_WIDTH) * 2
    mov di, ax
    mov ax, COLOR_BORDER * 256 + 217
    stosw
    
    ret

clear_screen:
    mov ax, 0x0720
    mov di, 0
    mov cx, SCREEN_WIDTH * SCREEN_HEIGHT
.clear:
    mov [es:di], ax
    add di, 2
    loop .clear
    ret

; --- Data ---
next_label   db 'Next Piece:'
score_label  db 'Score:'
lines_label  db 'Lines:'
level_label  db 'Level:'
controls     db 'Arrows: Move  Up: Rotate  Space: Drop'
game_over_msg db 'GAME OVER!'

exit_game:
    jmp 0x8000:0x0000 