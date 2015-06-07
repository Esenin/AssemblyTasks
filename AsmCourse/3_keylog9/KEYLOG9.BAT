;@goto batnik

	model tiny;
	.code
	.486
	org 100h
_: 	
	jmp start

symtab     db '0123456789ABCDEF'
m0 	db '  '
hello_msg 	db 'Start keyboard capture:\n', 13, 10, '$'
bye_msg 	db ' Program finished.', 13, 10, '$'
old_vector   dd 0                          ; storrage for source vector
f9 	db 0			      ; storrage for input char

start:
	mov dx, offset hello_msg
	mov ah, 9
	int 21h
	
	;Takes int 9 vector without int 21 
	push 0                 ; set es := 0 for convinient adressing
	pop es                 ;
	 	
	mov bx, 24h            ; 24h = 36 = 9 * 4, offset for int 9 
	mov ax, [es:bx]	       ; gets ip
	mov cx, [es:bx + 2]    ; gets cs
	mov word ptr old_vector, ax ; saves source vector handler
	mov word ptr old_vector + 2, cx; 
	
	cli 						; lock
								; setup out handler
	mov dx, offset handler_int9
	push cs
	pop ax
	mov [es:bx], dx
	mov [es:bx + 2], ax
	
	sti

cycle:  ; Spinning in a cycle, before 'ESC' 
	cmp cs:f9, 1   ; KeyBoardCode for 'ESC'              
	jne cycle
	
	cli
				; Sets original vector
	push cs
	pop ds
	push 0 
	pop es
	mov ax, word ptr [ds:old_vector];
	mov cx, word ptr [ds:old_vector + 2];
	mov es:24h, ax
	mov es:26h, cx
	
	sti

	; Print string
	mov dx, offset bye_msg
	mov ah, 9
	int 21h
	
	ret


handler_int9:	
	push ax      ;
	in al, 60h   ; transfers word from KBD 
	call print;
	cmp al, 1    ; 
	jne endofhandler;

	mov al, 20h  ; one - do not take next int
	out 20h, al  ; 
	mov cs:f9, 1; Set 'Esc' found	

endofhandler:
	pop ax       ;
	iret;



print:
	pusha  	           ; saves all registers
	push ds     
	push es
	push cs
	pop ds            ; ds = cs
	push cs            
	pop es            ; es = cs
	
	mov di, ax        ; stores value from KBD 
	
	mov al, 20h       ;  
	out 20h, al       ; sends byte to port
;________________________________________________
	mov ax, di        ; source data
	shr ax, 12        ; last 4-bit
	lea bx, symtab       ; translation table
	xlat              ;
	
	mov ah, 0Eh       ; 
	int 10h           ;
	
	xor bh, bh        ; get cursor
	mov ah, 3
	int 10h

	dec dl            ; retype
	mov ah, 2         ; set cursor
	int 10h           ;
	
	mov ah, 0Ah       ; write char at cursor
	mov bx,0Fh        ; bh - page
	mov cx, 1         ; how many times to print
	int 10h           ; print char
	
	xor bh, bh        ;
	mov ah, 3         ; read in cx, ds - cursor pos & size
	int 10h           ; 
	
	add dl, 1         ; +1 column
	mov ah, 2         ; sets cursor position
	int 10h           ;
;_________________________________________________
	mov ax, di        ;
	shr ax, 8         ; pre last 4 bit
	and ax, 0Fh       ;
	lea bx, symtab       ; table
	xlat 
	
	mov ah, 0Ah       ; write char at cursor
	mov bx, 0Fh       ; 
		          ;       
	mov cx, 1         ; how many times to print
	int 10h           ; print char
	
	mov ah, 3         ; read in cx, ds - cursor pos & size
	int 10h            ; 
	
	xor bh, bh        ; 
	add dl, 1         ; move cursor
	mov ah, 2         ; sets cursor position
	int 10h            ;
;_________________________________________________
	mov ax, di        ;
	shr ax, 4         ;  4 bit
	and ax, 0Fh       ;
	lea bx, symtab       ;
	xlat
	
	mov ah, 0Ah       ; write char at cursor
	mov bx, 0Fh       ; 
		          ;       
	mov cx, 1         ; how many times to print
	int 10h           ; print char
	
	mov ah, 3         ; read in cx, ds - cursor pos & size
	int 10h           ; 
	
	xor bh, bh        ; 
	add dl, 1         ; move cursor
	mov ah, 2         ; sets cursor position
	int 10h           ;

;_________________________________________________
	
	mov ax, di        ;
	                  ;  4 bit
	and ax, 0Fh       ;
	lea bx, symtab       ;
	xlat
	
	mov ah, 0Ah       ; write char at cursor
	mov bx, 0Fh       ; 
		          ;       
	mov cx, 1         ; how many times to print
	int 10h           ; print char
	mov ah, 3         ; read in cx, ds - cursor pos & size
	int 10h           ; 
	
	xor bh, bh        ; 
	mov dl, 0         ; move cursor
	add dh, 1         ; next row
	mov ah, 2         ; sets cursor position
	int 10h           ;

	pop es
	pop ds
	popa
	ret

	end _

:batnik
@echo off
tasm /m keylog9.bat
tlink /x/t keylog9
del keylog9.obj


