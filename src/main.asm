[BITS 16]
[ORG 0x0000]

%define CMD_MAX 64

fm_start:
    push ds
    push es
    push si
    push di

    push cs
    pop ds
    push cs
    pop es

    mov si, msg_banner
    call print_str

.cmd_loop:
    mov si, msg_prompt
    call print_str

    call read_line          ; fills cmd_buf (0-terminated)
    call trim_leading
    cmp byte [si], 0
    je .cmd_loop

    ; Compare command prefix
    mov di, cmd_help
    call starts_with_word
    jc .do_help

    mov di, cmd_ls
    call starts_with_word
    jc .do_ls

    mov di, cmd_cat
    call starts_with_word
    jc .do_cat

    mov di, cmd_rm
    call starts_with_word
    jc .do_rm

    mov di, cmd_mkdir
    call starts_with_word
    jc .do_mkdir

    mov di, cmd_touch
    call starts_with_word
    jc .do_touch

    mov di, cmd_exit
    call starts_with_word
    jc .do_exit

    mov si, msg_unknown
    call print_str
    jmp .cmd_loop

.do_help:
    mov si, msg_help
    call print_str
    jmp .cmd_loop

.do_ls:
    ; Optional path argument in SI
    call skip_word
    call fs_list_dir
    jmp .cmd_loop

.do_cat:
    call skip_word
    cmp byte [si], 0
    je .need_arg
    call fs_cat_file
    jmp .cmd_loop

.do_rm:
    call skip_word
    cmp byte [si], 0
    je .need_arg
    call fs_rm_file
    jmp .cmd_loop

.do_mkdir:
    call skip_word
    cmp byte [si], 0
    je .need_arg
    call fs_mkdir
    jmp .cmd_loop

.do_touch:
    call skip_word
    cmp byte [si], 0
    je .need_arg
    call fs_touch_file
    jmp .cmd_loop

.need_arg:
    mov si, msg_need_arg
    call print_str
    jmp .cmd_loop

.do_exit:
    pop di
    pop si
    pop es
    pop ds
    ret

; --- Hook these to killarOS FS / BIOS ---
fs_list_dir:
    ; SI -> path (empty = current dir)
    mov si, msg_stub_ls
    call print_str
    ret

fs_cat_file:
    ; SI -> filename
    mov si, msg_stub_cat
    call print_str
    ret

fs_rm_file:
    ; SI -> filename
    mov si, msg_stub_rm
    call print_str
    ret

fs_mkdir:
    ; SI -> dirname
    mov si, msg_stub_mkdir
    call print_str
    ret

fs_touch_file:
    ; SI -> filename
    mov si, msg_stub_touch
    call print_str
    ret

; --- Input & string helpers ---
read_line:
    push ax
    push cx
    push di
    mov di, cmd_buf
    xor cx, cx

.rl_loop:
    xor ah, ah
    int 0x16
    cmp al, 0x0D
    je .rl_done
    cmp al, 0x08
    je .rl_bs
    cmp al, 0x20
    jb .rl_loop
    cmp al, 0x7E
    ja .rl_loop
    cmp cx, CMD_MAX - 1
    jae .rl_loop

    mov [di], al
    inc di
    inc cx
    mov ah, 0x0E
    xor bh, bh
    int 0x10
    jmp .rl_loop

.rl_bs:
    test cx, cx
    jz .rl_loop
    dec di
    dec cx
    mov ah, 0x0E
    mov al, 0x08
    int 0x10
    mov al, ' '
    int 0x10
    mov al, 0x08
    int 0x10
    jmp .rl_loop

.rl_done:
    mov byte [di], 0
    mov si, msg_crlf
    call print_str
    pop di
    pop cx
    pop ax
    ret

trim_leading:
    mov si, cmd_buf
.tl_loop:
    cmp byte [si], ' '
    jne .tl_done
    inc si
    jmp .tl_loop
.tl_done:
    ret

; Returns CF=1 if word at SI equals ASCIIZ string at DI, followed by 0 or ' '
starts_with_word:
    push si
    push di
.sw_cmp:
    mov al, [di]
    test al, al
    jz .sw_check_end
    cmp [si], al
    jne .sw_no
    inc si
    inc di
    jmp .sw_cmp

.sw_check_end:
    mov al, [si]
    test al, al
    jz .sw_yes
    cmp al, ' '
    je .sw_yes

.sw_no:
    pop di
    pop si
    clc
    ret

.sw_yes:
    pop di
    pop si
    stc
    ret

; Advance SI past current word and spaces to argument
skip_word:
.sw1:
    cmp byte [si], 0
    je .sw_end
    cmp byte [si], ' '
    je .sw2
    inc si
    jmp .sw1
.sw2:
    cmp byte [si], ' '
    jne .sw_end
    inc si
    jmp .sw2
.sw_end:
    ret

print_str:
    push ax
    push bx
    push si
.ps_loop:
    lodsb
    test al, al
    jz .ps_done
    mov ah, 0x0E
    xor bh, bh
    int 0x10
    jmp .ps_loop
.ps_done:
    pop si
    pop bx
    pop ax
    ret

cmd_help    db 'help', 0
cmd_ls      db 'ls', 0
cmd_cat     db 'cat', 0
cmd_rm      db 'rm', 0
cmd_mkdir   db 'mkdir', 0
cmd_touch   db 'touch', 0
cmd_exit    db 'exit', 0

msg_banner      db 0x0D, 0x0A, 'killarOS File Manager package', 0x0D, 0x0A, 0
msg_prompt      db 'fm> ', 0
msg_crlf        db 0x0D, 0x0A, 0
msg_unknown     db 'Unknown command. Type "help".', 0x0D, 0x0A, 0
msg_need_arg    db 'Missing filename/path argument.', 0x0D, 0x0A, 0
msg_help        db 'Commands: ls [path], cat <file>, rm <file>, mkdir <dir>, touch <file>, help, exit', 0x0D, 0x0A, 0
msg_stub_ls     db '[ls] hook FS directory listing here', 0x0D, 0x0A, 0
msg_stub_cat    db '[cat] hook FS file read here', 0x0D, 0x0A, 0
msg_stub_rm     db '[rm] hook FS file delete here', 0x0D, 0x0A, 0
msg_stub_mkdir  db '[mkdir] hook FS dir create here', 0x0D, 0x0A, 0
msg_stub_touch  db '[touch] hook FS file create here', 0x0D, 0x0A, 0

cmd_buf times CMD_MAX db 0
