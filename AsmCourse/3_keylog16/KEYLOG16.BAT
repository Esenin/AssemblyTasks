;@goto batnik
	model tiny
.code
	.486 ; real mode. fix jump range
	org 100h
_:	jmp start
 	
hello_msg  db 'Start keyboard capture:\n',13,10,'$' 	
bye_msg    db 'Program finished.', 13, 10,'$'
symtab     db '0123456789ABCDEF'

	db 0EAh	 

print:
	pusha          ; save registers
	push ds	       
	push es
	
	push cs
	push cs      
	pop ds         ; ds = cs
	pop es         ; es = cs
	
	mov si, ax     ; save CHAR data
; 	____________________________________________ first digit
	
	lea bx, symtab    ; translation table
	shr ax, 12     ; 4-bit translation
	xlat  		   ; (BX + AL) -> AL
	
	mov ah, 0Eh    ; Write char in tty mode
	int 10h    	
	
	xor bh, bh     ; Get cursor position. BH - display page num [in]
	mov ah, 3      ; Return ch,cl -- cursor start-end line, DH-DL -- row-col
	int 10h        ;
	
	dec dl         ; Retype
	mov ah, 2      ; Set cursor position DH-DL -- row-col
	int 10h        ;

	mov ah, 0Ah;   ; "write char at cursor"
	xor bx, bx;    ; clear page
	mov cx, 1      ; num of times to write char
	int 10h        

	xor bh,bh      ; clear page
	mov ah, 3      ; get cursor param
	int 10h
	
	add dl, 1      ; step to the next column
	mov ah, 2      ; set cursor param
	int 10h
;   ____________________________________________ 2nd digit & space
	
	mov ax, si     ; source
	shr ax, 8      ; 
	and ax, 0Fh    ; 
 	lea bx, sym    ; table
	xlat           ;
	
	mov ah, 0Ah;   ; write char at cursor
	xor bh, bh;    ; clear page
	mov cx, 1      ; one symbol
	int 10h        

	xor bh,bh      ; clear page
	mov ah, 3      ; get cursor param
	int 10h
	
	add dl, 2      ; step to the next column  . add some space here
	mov ah, 2      ; set cursor param
	int 10h
;   ____________________________________________ a minus & space

	mov al, '-'    ;
	mov ah, 0Ah;   ; write char at cursor
	xor bh, bh;    ; clear page
	mov cx, 1      ; one symbol
	int 10h        

	xor bh,bh      ; clear page
	mov ah, 3      ; get cursor param
	int 10h
	
	add dl, 2      ; step to the next column
	mov ah, 2      ; set cursor param
	int 10h
;   ____________________________________________
	
	mov ax, si     ; source
	
	mov ah, 0Ah;   ; write char at cursor. AL - ASCII val of char
	xor bx, bx;    ; clear page
	mov cx, 1      ; amount
	int 10h        

	xor bh,bh      ; clear page
	mov ah, 3      ; get cursor param
	int 10h
	
	mov dl, 0      ; step to the next column
	add dh, 1      ; step to the next row
	mov ah, 2      ; set cursor param
	int 10h
	
;   ____________________________________________
	
	pop es
	pop ds
	popa
	ret
start:	
	; Printing char with int16
	mov ah, 9     
	mov dx, offset hello_msg
	int 21h    
	
get_key:
	xor ax, ax    ; ah == 0 => keyboard read
	int 16h	      ; dos service
	push ax
	call print    ;
	pop ax
	cmp ah, 1     ; is Escape?
	jne get_key 
	
	;Print 'Bye!'
	mov ah, 9     
	mov dx, offset bye_msg
	int 21h       
 
	ret           
	
	end _


:batnik
@echo off
tasm /m keylog16.bat
tlink /x/t keylog16
del keylog16.obj


