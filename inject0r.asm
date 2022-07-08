global _start

%define O_RDWR      0x2
%define E_FAIL      0xFFFFFFFF

%define SEEK_SET    0x0

%define sys_read    0x0
%define sys_write   0x1
%define sys_open    0x2
%define sys_close   0x3
%define sys_lseek   0x8
%define sys_exit    0x3c

%define EP_POS      0x18

%macro _syscall 1    
    push %1
    pop rax
    syscall
%endmacro

%macro evalerr 1
    cmp eax, %1
    jle  .error
%endmacro

section .bss
    ep_new: resw 2

section .data
    success_msg db  '[+] Entry point written', 0xa, 0x0
    failure_msg db  '[-] Failed to rewrite entry point', 0xa, 0x0

section .text

_start:
    ; if (argc < 3) { goto .end; }
    mov     rax, [rsp]      ; argc
    cmp     al, 0x3
    jl      .end

    mov     r14, [rsp+0x10] ; arg_filename
    mov     r15, [rsp+0x18] ; arg_ep

    mov     rdi, r15
    call    atoi
    mov     [ep_new], rax

    xor     eax, eax
    mov     rdi, r14        ; ELF str
    mov     esi, O_RDWR
    call    open
    evalerr 0
    
    push    rax             ; target fd
    
    mov     edi, eax        ; fd
    mov     esi, EP_POS
    mov     edx, SEEK_SET
    call    lseek
    evalerr 0

    mov     edi, r13d
    mov     esi, 2
    call    divide
    mov     edx, eax

    pop     rdi
    mov     rsi, ep_new

    call    write
    evalerr 0

    call    close

    mov     rdi, success_msg
    call    print

.end:
    mov     edi, eax
    call    exit
.error:
    push    rax
    mov     rdi, failure_msg
    call    print
    pop     rax
    jmp     .end

strlen:
    push    rdi
    xor     eax, eax
    xor     ecx, ecx
    dec     ecx
    repne   scasb
    sub     eax, ecx
    sub     eax, 2
    pop     rdi
    ret


; uint8 multiply(uint8 dil, uint8 sil);
multiply:
    mov     al, dl
    mul     sil
    ret

; uint16 divide(uint16 dividend, uint16 divisor);
divide:
    mov     ax, di
    div     si
    ret

; rdi = string
; rcx = slen counter (i--)
; rax = multiplication result
; r9d = conversion result
; rbx = mul10
atoi:
    call    strlen
    test    eax, eax
    jz      .end

    mov     r13, rax

    push    rsi                 ; save rsi
    push    rdi                 ; string
    push    rbx                 ; mul10 factor
    xor     esi, esi            ; clear operation byte reg

; for (i8 i = slen; i >=0; i--)
    xor     ecx, ecx            ; clear ecx and switch it with rax
    xor     r9d, r9d            ; clear result
    xchg    eax, ecx            ; rax holds strlen, so rcx becomes counter and rax is clean
                                ; ecx is counter (i = (slen))
    dec     ecx                 ; last array index is (ecx - 1)
    ;inc     eax             
    xor     ebx, ebx        
    inc     bl                  ; mul10 starts with 1 and grows by (x*10)

    mov     r8d, 0xa            ; r8 is 10

.loop:
    mov     al, BYTE [rdi+rcx]  ; get cur_index byte
    sub     al, 0x30            ; subtract 48
    
    mul     bx                  ; multiply by mul10 factor
    push    rax                 ; save result
    mov     eax, ebx            ; mov mul10 factor to eax
    mul     r8d                 ; |-> multiply it by 10
    mov     ebx, eax            ; load it back

    pop     rax                 ; restore result
    add     r9d, eax            ; add result to final result
    xor     eax, eax

    dec     ecx
    cmp     ecx, 0
    jge     .loop

.end:
    pop     rbx
    pop     rdi
    pop     rsi
    xchg    eax, r9d
    ret

print:
    push    1
    push    1
    push    rdi
    call    strlen
    mov     edx, eax
    pop     rsi
    pop     rax
    pop     rdi
    syscall
    ret

open:
    _syscall(sys_open)
    ret

close:
    _syscall(sys_close)
    ret

write:
    _syscall(sys_write)
    ret

lseek:
    _syscall(sys_lseek)
    ret

exit:
    _syscall(sys_exit)
