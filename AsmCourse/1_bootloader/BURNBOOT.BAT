;@goto -)
	model tiny
	locals __
.code
	org 100h
_:	jmp	start

msgerr 	db	'Error!', 13, 10, '$'
msgok  	db	'Ok', 13, 10, '$'
msgHello db	'Hi, man!', 13, 10, '$'
fnBoot	db 'bootcode.com', 0

start:		           
	push  cs
	pop	  es             

	call frdBoot        ; read bootcode.com into mem
	jc	 _e
	mov	 bx, offset EOF ; [es:bx] buff
	mov  dx, 0h         ; fix disk=80h, 0 == floppy
	mov  cx, 1h         ; start sector 1
	mov  ax, 301h       ; ah=3--write2disk, number of sectors=1
	int  13h            ; write sectors from memory
	jc 	 _e             ;


	mov   dx, offset msgok
	jmp   _x
_e:		
	mov	dx, offset msgerr
_x:		
	mov	ah, 9            ; print string
	int 	21h              ; dos:
	ret

frdBoot:	  ;i read bootcode.com to buffer [ds:dx]
	mov	dx, offset fnBoot ; 'bootcode.com'
	mov	ax, 3D00h         ; open file
	int 	21h
	jc 	_e
	mov	bx, ax            ; file handle
	mov	dx, offset EOF	  ; dest
	mov	cx, 300           ; bytes to read
	mov	ah, 3Fh           ; read from file by handle
	int 	21h

	jc		_e
	mov	ah, 3Eh           ; close file
	int 	21h
	ret


EOF:		end		_

:-)
@echo off
tasm /m burnboot.bat
tlink /x/t burnboot
del burnboot.obj













