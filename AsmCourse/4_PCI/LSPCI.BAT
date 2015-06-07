;@goto batnik
    model tiny
.code
    .386 ;  fix jump range
    org 100h
_:  jmp start

CFG_ADDR    equ     0CF8h
CFG_DATA    equ     0CFCh
CDIR_AH     equ     03Bh      
OPENF_AH    equ     3Dh
READF_AH    equ     3Fh
CLOSEF_AH   equ     3Eh
PRINT_AH    equ     9
EXITZ_AH    equ     04Ch

busInfo_str     db  ' Bus number: $'
devInfo_str     db  ' Device number: $'
multifInfo_str  db  ' is MF: $'
funcInfo_str    db  ' Function number: $'
vendorId_str    db  ' VendorID: $'
productId_str   db  ' productID: $'
byte_buf    db  'xx $'
word_buf    db  'xxxx $'
endline     db  13,10,'$'

rootDir     db "C:\WORK\4_PCI\ROOT",0
nextDir_buf db '  ', 0
filename    db "data",0 
error_msg   db "Some error here!",13,10,"$"
exit_msg    db "Program finished",13,10,"$"
cdir_msg    db "Go to dir: ","$" ; debug only
sym_tab     db "0123456789ABCDEF"

text_buf    db 203 dup(0),"$"



error_handler:
    mov   dx, offset error_msg
    call  printDx
terminate:
    mov   dx, offset rootDir ; go to start directory
    call  cdir_dx
    mov   dx, offset exit_msg
    call  printDx
    xor   eax, eax
    mov   ah, EXITZ_AH ; terminate a process
    int   21h
    ret

printDx:
    pushad
    mov ah, PRINT_AH
    int 21h
    popad
    ret

start:      
    push  cs
    pop   es


    mov   ecx, 80000000h  ; (1 << 31) enable bit // see msg scheme

                          ; ecx will contain device config id
foreach_device:
    mov     eax, ecx        
    add     eax, 0Ch        ; 0Ch -- read header type
    mov     dx,  CFG_ADDR
    out     dx,  eax        ; send query for device 
    mov     dx,  CFG_DATA
    in      eax, dx   ; get headerType from configuration space into EAX // 4 bytes

    cmp     ax,  0ffffh      ; "-1" -- if device NOT exists
    je      terminate        ;                         exit

    xor     di,  di
    xor     ebx, ebx

    shr     eax, 23         ; check if multifunctional (16 + 7 = 23 first bit of header type)
    and     ax,  0001h
    cmp     ax,  1       
    jne     foreach_function

    mov     di, 1           ; MultiFunctional flag

foreach_function:
    mov   eax, ecx        ; ecx contains device config id
    or    eax, ebx        ; ebx - function mask (8-10 bit for function number. see scheme)   
    mov   esi, eax        ; save device address with function into esi

    mov   dx,  CFG_ADDR
    out   dx,  eax   ; eax = device addr + function mask
    mov   dx,  CFG_DATA
    in    eax, dx

    cmp   ax, 0ffffh      ; check if function NOT exists
    je    next_functon        ;                   then seek next function (they can be out of order with gaps)
    call  print_info    ; elif exist - print it

    cmp   di, 1           ; if not MF flag
    jne   next_device     ; go to next device
                            ; else :
next_functon:
    shr   ebx, 8          ; increment function number
    inc   ebx
    cmp   ebx, 8          ; 8 = 1000 - above maximum count of multifunction
    je    next_device
    shl   ebx, 8          ; ebx - function mask (3 bits, 8-10 in struct)
    jmp   foreach_function

next_device:
    add   ecx, 0800h      ; go to next device // inc device number (see scheme)
    test  ecx, 01000000h  ; check device exist (01000000 hex -> 25th bit = 1, other bits = 0)
    jz    foreach_device      
    call terminate
    


print_info: ; [in]eax - productID | VendorID (8+8 bits), [in]esi - device address; 
            ; [in] di -- is multifunctional
            ; clear function
    pushad
    push    eax        
    push    eax 

    ; PRINT bus num

    mov     dx, offset busInfo_str
    call    printDx
    
    mov     eax, esi
    shr     eax, 16     ; bus number @ 16-23 bits 
    and     eax, 0FFh
    call    print_byte;(al)

    

    ; PRINT device num

    mov     dx, offset devInfo_str
    call    printDx
    
    mov     eax, esi
    shr     eax, 11     ; device number @ 11-15 bits
    and     eax, 1Fh
    call    print_byte;(al)



    ; PRINT function num

    mov     dx, offset funcInfo_str
    call    printDx
    
    mov     eax, esi
    shr     eax, 8     ; function number @ 8-10 bits 
    and     eax, 7h
    call    print_byte;(al)

    ; PRINT is multifunctional
    mov     dx, offset multifInfo_str
    call    printDx
    mov     ax, di
    call    print_byte

    mov dx, offset endline
    call    printDx

    ;   print vendorID

    mov     dx, offset vendorId_str
    call    printDx

    pop     eax ; get from stack (productId + vendorId)
    call    print_word;(ax)


    ;   print productID

    mov     dx, offset productId_str
    call    printDx

    shr     eax, 16
    call    print_word;(ax)

    mov     dx, offset endline
    call    printDx


    ;                     print additional details from database
    pop     eax         ; old-good vendorID+productId
    call    print_vendor_details;(eax)

    mov     dx, offset endline
    call    printDx
    popad

    ret


print_vendor_details: ;[in] eax (productId + VendorID)
; @description. Our file system is like suffix tree: two hex symbol (1 byte) per directory
; so if vendorID = 8086h and productID is 0x9C14, we must go such way: root/80/86/9C/14/
; in this directory we have "data" file, that contains |-end string

    pushad
    mov   dx, offset rootDir ; go to start directory
    call  cdir_dx

    ; xchg at first vendor and product Ids
    mov   ebx, eax
    shr   ebx, 16   ; now bx contains productID
    shl   eax, 16
    mov   ax,  bx    ; now in eax (VendorID+ProductId)

    ; now we can go through EAX left to right with 2 hex-char step and go into same directories
    mov   cl, 24
detour_cd:
    push  eax
    shr   eax, cl 
    and   eax, 0FFh  ; last 8 bits in ax is byte == folder name

    mov   dx,  offset nextDir_buf
    call  byte_to_hex;(ax, dx)
    call  cdir_dx;(dx)

    pop   eax
    sub   cl, 8
    cmp   cl, 0
    jge   detour_cd

    call  print_from_file

    popad
    ret

print_from_file:
    pushad

    mov   dx, offset filename
    xor   al, al
    mov   ah, OPENF_AH     ; open file
    int   21h
    push  ax               ; ax contains file handler
    jc    error_handler

    mov   bx, ax           ; file handler needs to be in bx
    mov   al, 0
    mov   ah, READF_AH     ; means read file
    mov   dx, offset text_buf
    mov   cx, 200          ; max. I hope its till EOF
    int   21h              ; ax contains number of bytes read if not CF
    jc    error_handler

    mov   di, ax      ; I wanna put 13,10, "$" after text
    inc   di
    add   di, dx       
    mov   byte ptr[di], 13
    inc   di
    mov   byte ptr[di], 10
    inc   di
    mov   byte ptr[di], '$'

    call  printDx

    ; close file
    pop  bx
    xor  ax, ax
    mov  ah, CLOSEF_AH
    int  21h    

    mov  dx, offset endline
    call printDx

    popad
    ret

;
;  Some helpers
;

cdir_dx: ; [in] dx -ptr to asciiz string; clear function
    pushad
    ;push  dx
    ;push  dx
    ;mov   dx, offset cdir_msg
    ;call  printDx
    ;pop   dx
    ;call  printDx
    ;mov   dx, offset endline
    ;call  printDx

    ;pop dx
    xor  eax, eax
    mov  ah, CDIR_AH
    int  21h
    jc   error_handler
    popad
    ret


print_word: ; [in] ax -- 2byte to output; clear function
    pushad
    mov     dx, offset word_buf

    call    word_to_hex

    mov     ax, 0900h
    int     21h
    popad
    ret


print_byte: ; [in] al -- byte to output
    pushad
    mov     dx, offset byte_buf  ; dx contains ptr to 1-byte buffer

    call    byte_to_hex

    mov     ax, 0900h
    int     21h   
    popad
    ret


word_to_hex: ; [in]ax -- 2byte to ASCII, [in]dx -- ptr to buffer; clear function
    push    dx    
    xchg    ah, al
    call    byte_to_hex
    xchg    ah, al
    add     dx, 2
    call    byte_to_hex
    pop     dx
    ret

byte_to_hex: ;[in] al -- byte to ASCII, [in]dx -- ptr to buffer; clear function
    push    ax
    push    di
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
    pop     di
    pop     ax
    ret 

to_hex:  ; [in] al; [out] al -- ascii char  
    push  bx
    lea   bx, sym_tab
    xlat
    pop   bx
    ret

    end _





:batnik
@echo off
tasm /m lspci.bat
tlink /x/t lspci.obj
echo Editor: Ivan Senin
del lspci.obj