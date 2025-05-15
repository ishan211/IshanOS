[BITS 16]
[ORG 0x0000]

; Constants
SCREEN_WIDTH    equ 80
SCREEN_HEIGHT   equ 25
SNAKE_COLOR     equ 0x0A
FOOD_COLOR      equ 0x0C
BORDER_COLOR    equ 0x0F
GAME_SPEED      equ 5
VIDEO_SEG       equ 0xB800

DIR_RIGHT       equ 0
DIR_LEFT        equ 1
DIR_UP          equ 2
DIR_DOWN        equ 3

start:
    mov ax, cs
    mov ds, ax
    mov ax, VIDEO_SEG
    mov es, ax

    call clear_screen
    call hide_cursor
    call init_game

game_loop:
    call check_input
    call move_snake
    call check_collisions
    cmp byte [game_over], 1
    je end_game
    call render_game

    mov cx, 0xFFFF
delay_loop:
    push cx
    mov cx, [game_speed]
delay_inner:
    nop
    nop
    nop
    nop
    loop delay_inner
    pop cx
    loop delay_loop

    jmp game_loop

end_game:
    call show_game_over
wait_key:
    mov ah, 1
    int 0x16
    jz wait_key
    mov ah, 0
    int 0x16
    cmp al, 'r'
    je start
    cmp al, 'R'
    je start
    jmp 0x8000:0x0000

init_game:
    mov byte [direction], DIR_RIGHT
    mov byte [game_over], 0
    mov word [score], 0
    mov word [game_speed], GAME_SPEED
    mov byte [snake_length], 3

    mov ax, SCREEN_WIDTH / 2
    mov [snake_x], ax
    mov ax, SCREEN_HEIGHT / 2
    mov [snake_y], ax

    mov ax, (SCREEN_WIDTH / 2) - 1
    mov [snake_x + 2], ax
    mov ax, SCREEN_HEIGHT / 2
    mov [snake_y + 2], ax

    mov ax, (SCREEN_WIDTH / 2) - 2
    mov [snake_x + 4], ax
    mov ax, SCREEN_HEIGHT / 2
    mov [snake_y + 4], ax

    call generate_food
    call draw_border
    call draw_status
    ret

check_input:
    mov ah, 1
    int 0x16
    jz .no_key
    mov ah, 0
    int 0x16
    cmp ah, 0x48
    je .up
    cmp ah, 0x50
    je .down
    cmp ah, 0x4B
    je .left
    cmp ah, 0x4D
    je .right
    cmp al, 'p'
    je .pause
    cmp al, 'P'
    je .pause
    cmp al, 27
    je .quit
    jmp .no_key
.up:
    cmp byte [direction], DIR_DOWN
    je .no_key
    mov byte [direction], DIR_UP
    jmp .no_key
.down:
    cmp byte [direction], DIR_UP
    je .no_key
    mov byte [direction], DIR_DOWN
    jmp .no_key
.left:
    cmp byte [direction], DIR_RIGHT
    je .no_key
    mov byte [direction], DIR_LEFT
    jmp .no_key
.right:
    cmp byte [direction], DIR_LEFT
    je .no_key
    mov byte [direction], DIR_RIGHT
    jmp .no_key
.pause:
    mov ah, 0
    int 0x16
    jmp .no_key
.quit:
    mov byte [game_over], 1
.no_key:
    ret

move_snake:
    movzx ax, byte [snake_length]
    dec ax
    shl ax, 2
.move_segments:
    cmp ax, 0
    je .move_head
    mov bx, ax
    sub bx, 4

    mov si, bx
    mov cx, [snake_x + si]
    mov si, ax
    mov [snake_x + si], cx

    mov si, bx
    mov cx, [snake_y + si]
    mov si, ax
    mov [snake_y + si], cx

    sub ax, 4
    jmp .move_segments
.move_head:
    cmp byte [direction], DIR_RIGHT
    je .right
    cmp byte [direction], DIR_LEFT
    je .left
    cmp byte [direction], DIR_UP
    je .up
    cmp byte [direction], DIR_DOWN
    je .down
    jmp .done
.right:
    inc word [snake_x]
    jmp .done
.left:
    dec word [snake_x]
    jmp .done
.up:
    dec word [snake_y]
    jmp .done
.down:
    inc word [snake_y]
.done:
    ret

check_collisions:
    mov ax, [snake_x]
    mov bx, [snake_y]
    cmp ax, 0
    je .collision
    cmp ax, SCREEN_WIDTH - 1
    je .collision
    cmp bx, 1
    je .collision
    cmp bx, SCREEN_HEIGHT - 1
    je .collision

    mov cx, 1
.check_self:
    cmp cl, [snake_length]
    jae .check_food
    movzx dx, cl
    shl dx, 2
    mov si, dx
    cmp ax, [snake_x + si]
    jne .next
    cmp bx, [snake_y + si]
    jne .next
    jmp .collision
.next:
    inc cx
    jmp .check_self
.check_food:
    cmp ax, [food_x]
    jne .no_food
    cmp bx, [food_y]
    jne .no_food
    call grow_snake
    call generate_food
    call increase_score
.no_food:
    mov byte [game_over], 0
    ret
.collision:
    mov byte [game_over], 1
    ret

grow_snake:
    inc byte [snake_length]
    ret

increase_score:
    add word [score], 10
    cmp word [game_speed], 1
    jle .update
    dec word [game_speed]
.update:
    call draw_status
    ret

generate_food:
    mov ah, 0
    int 0x1A
    mov ax, dx
    xor dx, dx
    mov bx, SCREEN_WIDTH - 2
    div bx
    inc dx
    mov [food_x], dx
    mov ax, cx
    xor dx, dx
    mov bx, SCREEN_HEIGHT - 3
    div bx
    add dx, 2
    mov [food_y], dx
    ret

render_game:
    call draw_border
    call draw_status
    call draw_food
    call draw_snake
    ret

draw_border:
    mov cx, SCREEN_WIDTH
    mov di, SCREEN_WIDTH * 2
.top:
    mov word [es:di], BORDER_COLOR * 256 + 205
    add di, 2
    loop .top

    mov cx, SCREEN_WIDTH
    mov di, (SCREEN_HEIGHT - 1) * SCREEN_WIDTH * 2
.bottom:
    mov word [es:di], BORDER_COLOR * 256 + 205
    add di, 2
    loop .bottom

    mov cx, SCREEN_HEIGHT - 2
    mov di, SCREEN_WIDTH * 2
.left:
    mov word [es:di], BORDER_COLOR * 256 + 186
    add di, SCREEN_WIDTH * 2
    loop .left

    mov cx, SCREEN_HEIGHT - 2
    mov di, SCREEN_WIDTH * 2 + (SCREEN_WIDTH - 1) * 2
.right:
    mov word [es:di], BORDER_COLOR * 256 + 186
    add di, SCREEN_WIDTH * 2
    loop .right

    mov di, SCREEN_WIDTH * 2
    mov word [es:di], BORDER_COLOR * 256 + 201
    mov di, SCREEN_WIDTH * 2 + (SCREEN_WIDTH - 1) * 2
    mov word [es:di], BORDER_COLOR * 256 + 187
    mov di, (SCREEN_HEIGHT - 1) * SCREEN_WIDTH * 2
    mov word [es:di], BORDER_COLOR * 256 + 200
    mov di, (SCREEN_HEIGHT - 1) * SCREEN_WIDTH * 2 + (SCREEN_WIDTH - 1) * 2
    mov word [es:di], BORDER_COLOR * 256 + 188
    ret

draw_status:
    mov di, 0
    mov cx, SCREEN_WIDTH
    mov ax, 0x0700
.clear:
    mov [es:di], ax
    add di, 2
    loop .clear

    mov di, 2
    mov si, score_text
    call print_string
    mov ax, [score]
    call print_number
    mov di, 30 * 2
    mov si, controls_text
    call print_string
    ret

draw_snake:
    xor cx, cx
.seg_loop:
    cmp cx, [snake_length]
    jae .done
    mov ax, cx
    shl ax, 2
    mov si, ax
    mov bx, [snake_x + si]
    mov dx, [snake_y + si]
    mov di, dx
    imul di, SCREEN_WIDTH
    add di, bx
    shl di, 1
    mov ah, SNAKE_COLOR
    cmp cx, 0
    jne .body
    mov al, 'O'
    jmp .char
.body:
    mov al, 'o'
.char:
    mov [es:di], ax
    inc cx
    jmp .seg_loop
.done:
    ret

draw_food:
    mov di, [food_y]
    imul di, SCREEN_WIDTH
    add di, [food_x]
    shl di, 1
    mov word [es:di], FOOD_COLOR * 256 + 15
    ret

show_game_over:
    mov di, (12 * SCREEN_WIDTH + 35) * 2
    mov si, gameover_text
    call print_string
    mov di, (14 * SCREEN_WIDTH + 32) * 2
    mov si, restart_text
    call print_string
    ret

print_string:
.next:
    lodsb
    test al, al
    jz .done
    mov ah, 0x0F
    mov [es:di], ax
    add di, 2
    jmp .next
.done:
    ret

print_number:
    mov bx, 10
    mov cx, 0
.div:
    xor dx, dx
    div bx
    push dx
    inc cx
    test ax, ax
    jnz .div
.print:
    pop dx
    add dl, '0'
    mov dh, 0x0F
    mov [es:di], dx
    add di, 2
    loop .print
    ret

clear_screen:
    mov ax, 0x0700
    mov di, 0
    mov cx, SCREEN_WIDTH * SCREEN_HEIGHT
.loop:
    mov [es:di], ax
    add di, 2
    loop .loop
    ret

hide_cursor:
    mov ah, 1
    mov ch, 32
    int 0x10
    ret

; Data Section
direction     db DIR_RIGHT
snake_length  db 3
game_over     db 0
score         dw 0
game_speed    dw GAME_SPEED
snake_x:      times 100 dw 0
snake_y:      times 100 dw 0
food_x        dw 0
food_y        dw 0
score_text    db "Score: ", 0
controls_text db "Arrows: Move | P: Pause | ESC: Quit", 0
gameover_text db "GAME OVER!", 0
restart_text  db "Press R to restart or any key to exit", 0

; Pad to multiple of 512 bytes
times 512 - ($ - $$) % 512 db 0
