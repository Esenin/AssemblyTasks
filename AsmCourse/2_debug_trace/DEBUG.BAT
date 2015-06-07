;@goto batnik
	model tiny  ; small segment, single group, COM-format
	.486 			; fix out of range jump. real mode
	.code
	org 100h    ; origin

					; program segment prefix
psp = ((stop - _ + 100h)+15)/16*16; calculating size in bytes
				  ; if /16 = > get paragraphs
prog = psp+100h   ; d-program start point

_:
	jmp start

fname   db 'just1.com',0
errmsg  db 'Error!',13,10,'$'
okmsg   db 'Debug prog has been loaded with OK status...',13,10,'$'
trace_stb db '>>> breakpoint!', 13,10,'$'
trace_stf db '<<< continue running prog...', 13,10,'$'
byemsg  db 'Debug finished',13,10,'$'
symbols db '0123456789ABCDEF'
debugmsg db 'Debug_step_here',13,10,'$'
newstr  db ' ',13,10,'$'
semicol db ':$'
bp_pos  db 0
old_cmd db 0
vector  dd 0      ; save old int3 vector

start:
	call append_prog

	mov ax, psp/16; calc size of program in paragraphs
	push cs       ; put on stack current segment (cs:ip)
	pop bx        ; segment in. bx := cs
	add ax, bx    ; in ax - code segment after current program  (psp/16 + cs)

	mov bx, psp   ; in bx size in bytes
	mov byte ptr[bx], 0CBh; retf = 0CBh, for correct return in parent

	; TEMP HERE:
	; call printer
	; END of TEMp

	call setup_ivector ; to offset printer


	push cs       ; CS (save for correct return)    stack [ cs ->
	push offset eod_handler ;                  stack[ cs, [eof_handler] ->
					  ; IP - replace here after return
		      	  ; retf pushes IP; CS
	mov ds, ax    ; fix ds for loaded program     ds := psp/16+cs
	push 0        ; for ret(IP) in loaded  => to place, were 0CBh
					  ;  								stack[cs, [eof_hanlder], 0 ->
	pushf         ; gets flag register
	pop bx        ; puts flags in bx
	or bx, 100h   ; set TF flag
	push bx       ; new flag register  |stack[cs, [e_h], 0, flags ->
	push ax       ; segment for loaded program
	push 100h     ; IP for loaded program
					  ;      stack [cs, [e_h], 0, flags, psp/16+cs, 100h ->

	iret	        ; jump to loaded program code
					  ; iret logic: pop ip, pop cs, popf
					  ;     stack [cs, [e_h], 0 ->
	ret

append_prog:
	mov ah, 03Dh  ; 'open file' functionjr
	xor al, al    ; read only mode
	mov dx, offset fname; pointer to file name, file in local directory
	int 21h       ; MSDOS call

	jc err_	      ; if CF: Error

		      ; ax contains file handle
	mov bx, ax    ; saves file handel in bx
	mov ah, 03Fh  ; 'read file' function
	mov cx, 0FFFFh; number of bytes to read
	mov dx, prog  ; buffer adress
	int 21h;

	jc err_

	mov ah, 9     ; 'print string' function
	mov dx, offset okmsg
	int 21h       ; go go, Dos!

	mov ah, 03Eh  ; 'close file handle' function
	int 21h       ;

	jc err_
	ret

setup_ivector:
	push ax       ; save
	push bx       ;
	push es       ;
				  ; stack[ psp/16+cs , psp, es ->

	mov ax, 3501h          ; 35h='get interrupt vector'
								  ; 01h int= single step, TF
								  ; return es:bx
	int 21h
	mov word ptr vector, bx; saves information
	mov word ptr vector, es;
	pop es       ; es:= es old. stack [ psp/16+cs, psp ->
	pop bx       ; bx := psp. stack [psp/16+cs ->

	mov dx, offset printer ; fwd label
					  ; place to be after int 1, 35h -> read old vector
	mov ax, 2501h ; 'set intrpt handler' 01h. [ds:dx] --addres of handler
	int 21h

	pop ax	      ; recover AX := psp/16+cs.       stack [->
	ret

eod_handler:          ; will be here after trace end
	push cs       ;
	pop ds        ; correct ds

	pushf         ; get flag regitser
	pop bx        ; eflags in bx - FIX
	xor bx, 100h  ; turn off TF
	push bx       ; new flag on stack
	popf          ;

	push ax
	push dx

	mov dx, offset byemsg;
	mov ah, 9
	int 21h

	lds dx, vector; pointer to old int 1 vector
	mov ax, 2501h ; recover old vector
	int 21h       ;

	pop dx
	pop ax

	ret

print_debug_step:
	push dx
	push ax
	mov dx, offset debugmsg
	mov ax, 0900h
	int 21h
	pop ax
	pop dx
	ret



print_word: ; [in] cx
	mov bx, offset symbols; pointer to translation table
	push cx
	push cx
	push cx
	push cx

	mov cl, 12
cycle:
	pop ax
	shr ax, cl
	and al, 0Fh; take last char
	xlat		; (bx + al) -> al
	mov dl, al
	mov ah, 02
	int 21h     ; dl == char

	sub cl, 4
	cmp cl, -4
	jnz cycle

	ret





printer:
	push bp       ; save stack begining            stack [ bp_old ->
	mov bp, sp    ; bp := sp. our frame

	push ds       ; 					stack[bp_old, ds->
	push cs       ;
	pop ds        ; set ds := cs from loaded program

	push dx		  ; save all registers in stack
	push cx
	push bx
	push ax       ; stack [ bp_old, ds, dx,cx,bx,ax ->

	mov dx, offset trace_stb
	mov ax, 0900h
	int 21h 	  ; print start trace msg

	mov bx, offset symbols; pointer to translation table

	mov cx, [bp + 4]      ; gets CS from stack (CS to print)
	call print_word


	mov dx, offset semicol; 'print char' semicol
	mov ah, 9
	int 21h

	mov cx, [bp + 2]      ; gets IP from stack  (IP to print)
	call print_word

	mov dx, offset newstr; go to the new string
	mov ah, 9
	int 21h

	mov dx, offset trace_stf
	mov ax, 0900h
	int 21h

	pop ax       ; recover all registers
	pop bx
	pop cx
	pop dx
	pop ds
	pop bp

	iret
err_:
	mov ah, 9     	     ; 'string output' function
	mov dx, offset errmsg; string adress
	int 21h              ; MSDOS call
	ret
stop:                        ; label for program length calculating
	end _

:batnik
@echo off
tasm /m/l debug.bat
tlink /x/t debug
del debug.obj



