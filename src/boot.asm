[BITS 16]
[ORG 0x7C00]

start:
    cli                 ; Clear interrupts
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00      ; Set up stack
    sti                 ; Enable interrupts

    ; Clear screen
    mov ah, 0
    mov al, 3
    int 0x10

    ; Print boot messages
    mov si, msg1
    call print
    call newline
    mov si, msg2
    call print
    call newline
    mov si, waitmsg
    call print

.wait_enter:
    mov ah, 0           ; Wait for keypress
    int 0x16
    cmp al, 13          ; Check if ENTER was pressed
    jne .wait_enter

    ; Load stage2 (sector 2) to 0x8000:0000
    mov ax, 0x8000
    mov es, ax
    xor bx, bx          ; ES:BX = 0x8000:0000
    mov ah, 0x02        ; BIOS read sector
    mov al, 1           ; 1 sector
    mov ch, 0           ; cylinder
    mov cl, 2           ; sector (sector #2)
    mov dh, 0           ; head
    mov dl, 0           ; drive 0 (floppy A:)
    int 13h
    jc disk_error

    ; Jump to stage2
    jmp 0x8000:0000

disk_error:
    mov si, errormsg
    call newline
    call print
    jmp $               ; Infinite loop

; Print string routine
print:
.next:
    lodsb               ; Load byte from SI into AL
    test al, al         ; Check if end of string (0)
    je .done
    mov ah, 0x0E        ; BIOS teletype function
    int 0x10            ; Print character
    jmp .next
.done:
    ret

; Print newline
newline:
    mov ah, 0x0E
    mov al, 0x0D        ; Carriage Return
    int 0x10
    mov al, 0x0A        ; Line Feed
    int 0x10
    ret

; Messages
msg1 db "IshanOS-2.0 Launching...", 0
msg2 db "I'm Alive!", 0
waitmsg db "Press ENTER to continue...", 0
errormsg db "Disk read error!", 0

; Boot sector padding and signature
times 510-($-$$) db 0
dw 0xAA55
