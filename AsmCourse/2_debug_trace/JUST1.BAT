;@goto batnik
	model tiny

.code
	org 100h
_:	jmp start

msg	db	'Test msg', 13,10,'$'
msgExit	db	'Exitttt', 13, 10, '$'

start:
	xor ax,ax
	mov cx, 3
forr:
	mov ah, 9
	mov dx, offset msg
	int 21h
	dec cx
	cmp cx, 0
	jne forr

	mov ah, 9
	mov dx, offset msgExit
	int 21h
	ret
	end _


:batnik
@echo off
tasm /m just1.bat
tlink /x/t just1
del just1.obj


