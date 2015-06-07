;@goto batcode
			locals
			model tiny
			.386
.code
			org 07C00h       
_:			jmp start

vkey_up    equ  48h
vkey_down  equ  50h
vkey_esc   equ  1h

vectorsPerLine equ  4
lines_num      equ  20
top_pos        equ  0
end_pos        equ  200



hello	  db	'Loader is working here now. Press any key...', 13, 10, '$'
bye_msg	  db	'program finished!', 13, 10, '$'
sym_tab   db 	"0123456789ABCDEF"
addr_buf  db    " xxxx::    ",'$'
word_bufl db	"xxxx:",'$'
word_bufr db    "xxxx    ", '$'
endline   db	13,10,'$' 

start:
	push cs
	pop  ds 


	mov      dx, offset hello	
	call	 printDx

	xor		 ax, ax            ; ah=0--scan code
	int		 16h               ; i/o keyboard read


	mov	ax, 0
	call	show_vectors_routine;(first_line=ax)


	mov		dx, offset bye_msg    
	call	printDx

	ret                      


show_vectors_routine:	; [in] ax -- idx of start line 
	pusha


	mov dx, vectorsPerLine								
	mul	dx 				; why vPL to DX at first ??? 'coz we CANNOT mul immediate D:
	mov	si, ax			; si == ( idx of start line) * ptr[bytes_per_line]

	mov	ax, 02h		; reset cursor pos
	mov	dx, 0 		; DH -- row, DL -- col
	int	10h

	mov 	cx, lines_num  ; how much lines
	print_loop:	
								; print address
		mov	 ax,  si
		mov	 dx,  offset addr_buf
		inc dx  ; because format is " xxxx::    "
		call word_to_hex;(ax, dx)
		call printDx

		mov bx, vectorsPerLine
		line_loop:	
										; we wanna print in "dead:beef" format
										; lets print first word
			mov	ax, word ptr[si + 2]
			mov dx, offset word_bufl
			call word_to_hex;(byte=ax, ptr=dx)
			call printDx
										; print second word
			mov	ax, word ptr[si]
			mov dx, offset word_bufr
			call word_to_hex;(byte=ax, ptr=dx)
			call printDx
			
			add	si, 4 					; go to next word pair
			dec bx
			cmp bx, 0
			jg line_loop
	
		mov	dx, offset endline  ; print end line
		call printDx	
		dec	cx
		cmp cx, 0
		jg print_loop
	
	popa
	mov bx, ax
	jmp kbd_handler
exit:
	ret
	

kbd_handler: ;[in] bx - current line number
	xor ax, ax
	int	16h			; waiting for key

	cmp	ah, vkey_up
	je	scroll_up
	cmp	ah, vkey_down
	je	scroll_down
	cmp	ah, vkey_esc
	je	exit
	jmp	kbd_handler


scroll_up:	;[in] bx - current line number  [out] ax -- new start line num
	mov ax, bx
	mov	dx, lines_num
	neg	dx
	add	ax, dx 			; ax = ax + (-delta)
	cmp	ax, top_pos
	jge	show_vectors_routine
	; else
	sub ax, dx
	mov bx, ax
	jmp kbd_handler


scroll_down: ;[in] bx - current line number	[out] ax -- new start line num
	mov ax, bx
 	add	ax, lines_num  ; ax = ax + delta
	cmp	ax, end_pos
	jl	show_vectors_routine 
	; else
	sub ax, lines_num
	mov bx, ax
	jmp kbd_handler
		
;
;  HELPERS
;                      

printDx proc ; [in] dx - ptr to text
		 	 ; clear function
	pusha

	mov		ah, 0Eh ; ah -- int10 mode "write char in tty mode"
	xor		bx, bx  ; bx := 0. tty modes. color and some else
	mov 	si, dx  ; source idx := ptr to text
					; while (*si != '\0')
p:
	mov   al, [si]   ; al := [ptr to text] + i
	cmp	  al, '$'      ; if text[al] == \0
	je	  end_p
	int   10h   	   ; print. al -- char to write
	inc	  si          
	jmp	  p
end_p:
	popa
	ret   
printDx endp    


word_to_hex: ; [in] ax -- 2byte to ASCII, [in] dx -- ptr to buffer
			 ; clear function
    pusha  
    xchg    ah, al
    call    byte_to_hex
    xchg    ah, al
    add     dx, 2
    call    byte_to_hex
    popa
    ret

byte_to_hex: ; [in] al -- byte to ASCII, [in]dx -- ptr to buffer
			 ; clear function
    pusha
    ;  first 4 bits
    mov     ah, al
    shr     al, 4
    call    to_hex
    mov     di, dx    ; BECAUSE WE CANT USE DX AS A POINTER!
    mov     byte ptr[di], al
    ;  second 4 bits
    mov     al, ah
    and     al, 0fh
    call    to_hex
    mov     byte ptr[di + 1], al
    popa
    ret 

to_hex:  ; [in] al; [out] al -- ascii char; other regs wo changes
    push  bx
    lea   bx, sym_tab
    xlat
    pop   bx
    ret

	db 512 - ($-_)-2 dup(0) ; all to null
	db 055h, 0AAh			; boot sector
EOF:	 end		_

:batcode
@echo off
tasm /m bootcode.bat
tlink /t bootcode.obj, bootcode.bin
echo Editor:Ivan Senin
del *.obj
del *.map

