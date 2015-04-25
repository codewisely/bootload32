[org 0x7c00]
[bits 16]

jmp Main

check_a20:    ; checks for A20 line availability
mov ax, 0xFFFF
mov es, ax
mov di, 0x7E0E
mov al, byte[es:di]
cmp al, 0x55
jne .return
mov al, 0x69
mov byte[es:di], al
mov bl, byte[0x7DFE]
cmp bl, 0x69
jne .return

mov ax, 0x2401
int 15h
jnc .return

call .wait
mov al, 0xD1
out 0x64, al
call .wait
mov al, 0xDF
out 0x60, al
call .wait
jmp .return

.wait:
in al, 0x64
test al, 2
jnz .wait
ret

.return:
ret       ; returns to our main code

gdt_start:   ; Global Descriptor Table
gdt_null:
  dw  0
  dw  0
gdt_code:
  dw  0xFFFF      ; 4GB limit
  dw  0           ; base
  db  0           ; base
  db  10011010b   ; [present][privilege level][privilege level][code segment][code segment][conforming][readable][access]
  db  11001111b   ; [granularity][32 bit size bit][reserved][no use][limit][limit][limit][limit]
  db  0           ; base
gdt_data:
  dw  0xFFFF
  dw  0
  db  0
  db  10010010b
  db  11001111b   ; [present][privilege level][privilege level][data segment][data segment][expand direction][writeable][access]
  db  0
gdt_end:

gdt_descriptor:
  dw  gdt_end - gdt_start     ; size of GDT
  dd  gdt_start               ; location of GDT's start point

load_GDT:
cli
lgdt [gdt_descriptor]         ; actual function that loads GDT
mov eax, cr0                  ; make the Control Register 0 (CR0) writable - copy it to eax
or eax, 1                     ; switch the last byte (protected mode flag) to 1
mov cr0, eax                  ; move the value back to CR0
ret

Main:
cli
mov ax, 07c0h
push ax
add ax, 20h
mov ss, ax
mov sp, 1000h
pop ax
mov ds, ax

call check_a20
call load_GDT

jmp 08h:kernel                ; far jump to the kernel

[bits 32]                     ; below that line we are in the protected mode

set_environment:
mov ax, 10h
mov ds, ax
mov ss, ax
mov es, ax
mov fs, ax
mov gs, ax
mov esp, 0x9000
mov ebp, esp
ret

kernel:
call set_environment

; Since we are in the 32-bits mode
; no more interrupts!
; we have to write directly to the memory...

mov edi, 0xB8000    ; video memory (base)
mov [edi], 'H'
mov [edi+0x02], 'e'
mov [edi+0x04], 'l'
mov [edi+0x06], 'l'
mov [edi+0x08], 'o'
mov [edi+0x0A], '!'
cli                 ; clear interrupts (even though they were already disabled)
hlt                 ; halt the CPU
jmp $               ; another "security valve" - just stay where you are :)

times 510-($-$$) db 0           ; NASM-specific directive, this will fill-out the rest of the code with zeros (to the 510th byte)
dw 0xAA55                       ; Last 2 bytes always contain a boot signature
