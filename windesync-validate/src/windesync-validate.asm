include "incs/hardware.inc"

SECTION "int_vbl", ROM0[$40]
INT_VBL:
	push	AF
	push	BC
	push	DE
	push	HL
	jp	HANDLE_VBL

SECTION "int_lcd", ROM0[$48]
INT_LCD:
	push	AF
	push	HL

	ldh	A,[scrolltable_idx]
	ld	H,HIGH(SCROLLTABLE>>1)		; Prepare HB of index/2
	ld	L,A
	inc	A				; \ Increment and store next index
	ldh	[scrolltable_idx],A		; /
	add	HL,HL				; Calculate 
	ld	A,[HL+]
	ldh	[rSCX],A
	ld	A,[HL+]
	ldh	[rWX],A
	ld	A,L


	ldh	A,[rLY]
	cp	9
	jr	z,.disablewin

	cp	81
	jr	z,.change_scy

	cp	81-9
	jr	z,.disable_sprites

.end
	pop	HL
	pop	AF
	reti
.disable_sprites
	ld	A,LCDCF_ON|LCDCF_WIN9C00|LCDCF_BG8000|LCDCF_BGON|LCDCF_OBJ16
	jr	.write_lcdc

.change_scy
	ld	A,-74
	ldh	[rSCY],A
	ld	A,LCDCF_ON|LCDCF_WIN9C00|LCDCF_BG8000|LCDCF_OBJON|LCDCF_BGON|LCDCF_OBJ16
	jr	.write_lcdc

.disablewin
	ld	A,LCDCF_ON|LCDCF_WIN9C00|LCDCF_BG8000|LCDCF_OBJON|LCDCF_BGON|LCDCF_OBJ16
.write_lcdc
	ldh	[rLCDC],A
	jr	.end

SECTION "Header", ROM0[$100]
	di				; 1
	jp	ENTRY			; 4

	ds	$150 - @, 0

SECTION "Main", ROM0
ENTRY::

	ldh	A,[rLCDC]
	add	A
	jr	nc,.alreadyoff
.waitvbl
	ldh	A,[rLY]
	cp	$90
	jr	c,.waitvbl

.alreadyoff
	xor	A
	ldh	[rLCDC],A

	ld	C,$80
	xor	A
.clear_hram_loop
	ld	[$FF00+C],A
	inc	C
	jr	nz,.clear_hram_loop

	ld	HL,_OAMRAM		; Clear OAM
	ld	E,L			; L==0
	ld	BC,$A0
	call	CLEAR

	ld	HL,OAM_STATIC		;
	ld	DE,_OAMRAM		; Clear OAM
	ld	BC,OAM_STATIC.end-OAM_STATIC
	call	COPY

	call	INIT_VRAM


	; Set up similar IO register values to Star Trek
	ld	A,$07
	ldh	[rLYC],A

	xor	A	

	ld	A,$07
	ldh	[rWX],A

	ld	A,%01010011
	ldh	[rBGP],A

	ld	A,%11100100
	ldh	[rOBP0],A
	ld	A,%10101000
	ldh	[rOBP1],A

	ld	A,STATF_MODE00			; Set up HBöank interrupt
	ldh	[rSTAT],A

	ld	A,IEF_VBLANK|IEF_STAT
	ldh	[rIE],A

	xor	A
	ldh	[rSCX],A
	ldh	[rSCY],A
	ldh	[rWY],A
	ldh	[rIF],A

	; Fill in initial value

	ld	A,LCDCF_ON|LCDCF_WIN9C00|LCDCF_WINON|LCDCF_BG8000|LCDCF_BGON|LCDCF_OBJ16
	ldh	[rLCDC],A

	ei

.el	halt
	jr	.el

INIT_VRAM:
	; Clear tilesets
	ld	HL,$8000
	ld	B,$98			; Top byte of end address
	ld	E,L			; L==0
	call	FASTCLEAR

	; Load a font into tile RAM.
	ld	HL,Font0
	ld	DE,$8200
	ld	BC,Font0.end-Font0
	call	COPY

	; Calibration tiles
	ld	HL,CALTILES
	ld	DE,$8000
	ld	BC,CALTILES.end-CALTILES
	call	COPY

	; Calibration tiles
	ld	HL,SPRITETILES
	ld	DE,$8100
	ld	BC,SPRITETILES.end-SPRITETILES
	call	COPY

	; Fill map 0 with tile 1
	ld	HL,$9800
	ld	B,$9C			; Top byte of end address
	ld	E,$00
	call	FASTCLEAR

	; Fill map 1 with tile 0
	;ld	HL,$9C00
	ld	B,$A0			; Top byte of end address
	ld	E,L			; L==0
	call	FASTCLEAR


	ld	HL,MAP_CHECKMARK
	ld	DE,$9800
	ld	BC,MAP_CHECKMARK.end-MAP_CHECKMARK
	call	COPY

	ld	HL,S_POSITIVE
	ld	DE,$9C00
	call	MPRINT

	ld	HL,S_NEGATIVE
	ld	DE,$9920
	call	MPRINT

	ret


HANDLE_VBL:
	call	READ_JOYPAD

	ld	A,LCDCF_ON|LCDCF_WIN9C00|LCDCF_WINON|LCDCF_BG8000|LCDCF_BGON|LCDCF_OBJ16
	ldh	[rLCDC],A

	xor	A

	ldh	[rIF],A
	ldh	[scrolltable_idx],A

	ldh	[rWY],A
	ldh	[rSCY],A

	ld	A,7
	ldh	[rWX],A

	pop	HL
	pop	DE
	pop	BC
	pop	AF
	reti



CALTILES:
	; Tile 00: blank.
rept 8
	dw	`33333333
endr
	; Tile 01: "vertical" piece.
rept 8
	dw	`31313131
endr

	; Tile 02: right side slanted, left piece.
	dw	`31313131
	dw	`31313131
	dw	`31313131
	dw	`31313131
	dw	`31313131
	dw	`31313133
	dw	`31313333
	dw	`31333333

	; Tile 03: right side slanted right piece.
	dw	`31313131
	dw	`31313133
	dw	`31313333
	dw	`31333333
	dw	`33333333
	dw	`33333333
	dw	`33333333
	dw	`33333333

	; Tile 04: left side slanted right piece.
	dw	`33333330
	dw	`33333031
	dw	`33303131
	dw	`30313131
	dw	`31313131
	dw	`31313131
	dw	`31313131
	dw	`31313131

	; Tile 05: left side slanted left piece.
	dw	`33333333
	dw	`33333333
	dw	`33333333
	dw	`33333333
	dw	`33333330
	dw	`33333031
	dw	`33303131
	dw	`30313131

	; Tile 06: "vertical" piece with shadow on the left.
rept 8
	dw	`30313131
endr

	; Tile 07,08: 6,1 but with diagonal line
	dw	`30313131
	dw	`30313131
	dw	`30313131
	dw	`30313131
	dw	`30313130
	dw	`30313031
	dw	`30303131
	dw	`30313131

	dw	`31313130
	dw	`31313031
	dw	`31303131
	dw	`30313131
	dw	`31313131
	dw	`31313131
	dw	`31313131
	dw	`31313131


.end

SPRITETILES:

	; Sprite tile 00+01: NW slope blocker.
	dw	`00000001
	dw	`00000010
	dw	`00000101
	dw	`00001010
	dw	`00010101
	dw	`00101010
	dw	`01010101
	dw	`10101010

	dw	`01010101
	dw	`10101010
	dw	`01010101
	dw	`10101010
	dw	`01010101
	dw	`10101010
	dw	`01010101
	dw	`10101010

	; Sprite tile 02+03: Solid blocker.
	dw	`01010101
	dw	`10101010
	dw	`01010101
	dw	`10101010
	dw	`01010101
	dw	`10101010
	dw	`01010101
	dw	`10101010

	dw	`01010101
	dw	`10101010
	dw	`01010101
	dw	`10101010
	dw	`01010101
	dw	`10101010
	dw	`01010101
	dw	`10101010

	; Sprite tile 04+05: SE slope.
	dw	`01010101
	dw	`10101010
	dw	`01010101
	dw	`10101010
	dw	`01010101
	dw	`10101010
	dw	`01010101
	dw	`10101010

	dw	`01010101
	dw	`10101010
	dw	`01010100
	dw	`10101000
	dw	`01010000
	dw	`10100000
	dw	`01000000
	dw	`10000000

	; Sprite tile 06+07: cover for dirt pixels.
	dw	`00100000
	dw	`00000000
	dw	`00000000
	dw	`00000000
	dw	`00000000
	dw	`00000000
	dw	`00000000
	dw	`00000000

	dw	`00100000
	dw	`00000000
	dw	`00000000
	dw	`00000000
	dw	`00000000
	dw	`00000000
	dw	`00000000
	dw	`00000000

.end


SECTION "Scroll table", ROM0, ALIGN[8]
SCROLLTABLE:
	REPT 9
		db	$00,$07
	ENDR

.firstcheck
	; Draw first checkmark
SCROLLVAR = 0
	REPT 8*7
	IF SCROLLVAR <24
		db LOW(-SCROLLVAR),(7+SCROLLVAR)%8
	ELSE
		db LOW(-SCROLLVAR),7+SCROLLVAR
	ENDC
SCROLLVAR = SCROLLVAR + 1
	ENDR

.text
	; Display second message
	REPT 16
		db 0,168
	ENDR
.secondcheck
SCROLLVAR = 0
SCROLLVAR_WX = 8
	REPT 8*7
	IF SCROLLVAR <24
		db LOW(-1-SCROLLVAR),(7+SCROLLVAR_WX)%8
	ELSE
		db LOW(-1-SCROLLVAR),7+SCROLLVAR_WX
	ENDC
SCROLLVAR = SCROLLVAR + 1
	IF (SCROLLVAR % 7) == 0
SCROLLVAR_WX = SCROLLVAR_WX - 1
	ENDC

	ENDR


	REPT 17
		db 0,168
	ENDR

SECTION "Util", ROM0
; Simple, slow memcopy.
; HL=Source.
; DE=Destination.
; BC=Length.
COPY:
	ld	A,[HL+]
	ld	[DE],A
	inc	DE
	dec	BC
	ld	A,B
	or	C
	jr	nz,COPY
	ret

; Simple, slow memclear.
; HL=Start adress.
; E=Value.
; BC=Length.
CLEAR:
	ld	A,E
	ld	[HL+],A
	dec	BC
	ld	A,B
	or	C
	jr	nz,CLEAR
	ret

; Clears memory in 256 byte chunks up to a page boundary.
; E=Value to clear with.
; HL=Start address.
; B=End address (Exclusive.)
; Example: To clear WRAM:
; E=0 HL=$C000 B=$E0
FASTCLEAR:
	ld	A,E
	;xor	A
	ld	C,64
.loop::
	ld	[HL+],A
	ld	[HL+],A
	ld	[HL+],A
	ld	[HL+],A
	dec	C
	jr	nz,.loop
	ld	A,H
	cp	B
	ret	z
	jr	FASTCLEAR


; Minimal print function
MPRINT:
	ld	A,[HL+]
	or	A
	ret	z
	cp	"\n"
	jr	z,.nextrow
	cp	"\t"
	jr	z,.tab

	ld	[DE],A
	inc	DE
	jr	MPRINT
.nextrow
	ld	A,E
	and	$E0
	add	$20
	ld	E,A
	jr	nc,MPRINT
	inc	D
	jr	MPRINT

.tab
	ld	A,E
	and	$FC
	add	$02
	ld	E,A
	jr	nc,MPRINT
	inc	D
	jr	MPRINT

; Print one hexadecimal byte.
PRINTHEX:
	ld	E,A
	swap	A
	call	PRINTHEX_DIGIT
	ld	A,E
PRINTHEX_DIGIT:
	and	$0F
	add	$30
	cp	$3A
	jr	c,.noupper
	add	7
.noupper
	ld	[HL+],A
	ret


READ_JOYPAD::
	ld	A,P1F_GET_DPAD
	ldh	[rP1],A
	ldh	A,[rP1]
	ldh	A,[rP1]
	ldh	A,[rP1]
	ldh	A,[rP1]
	cpl
	and	$0F
	swap	A
	ld	B,A
	ld	A,P1F_GET_BTN
	ldh	[rP1],A
	ldh	A,[rP1]
	ldh	A,[rP1]
	ldh	A,[rP1]
	ldh	A,[rP1]
	ldh	A,[rP1]
	cpl
	and	$0F
	or	B
	ld	C,A
	ldh	A,[joypad_held]
	xor	C
	and	C
	ldh	[joypad_pressed],A
	ld	A,C
	ldh	[joypad_held],A
	ld	A,P1F_GET_NONE
	ldh	[rP1],A
	ret

SECTION "Graphics", ROM0
Font0:
	incbin "graphics/font0.2bpp"
.end

SECTION "Strings", ROM0
S_POSITIVE:	db	" SHOULD TRIGGER     \n"
		db	"                    ",0

S_NEGATIVE:	db	" SHOULD NOT TRIGGER \n"
		db	"                    ",0

SECTION "Static OAM source", ROM0

OAM_STATIC:
SX = 88
SY = 49
TO = $10	; Tile offset.
	; Lower right leg of the cross
	db	SY+0	,SX+0	,TO+0	,0
	db	SY+0	,SX+8	,TO+2	,0
	db	SY+8	,SX+8	,TO+2	,0
	db	SY+8	,SX+16	,TO+2	,0
	db	SY+22	,SX+16	,TO+2	,0
	db	SY+16	,SX+24	,TO+2	,0
	db	SY+22	,SX+16	,TO+2	,0
	db	SY+22	,SX+32	,TO+2	,0

	; Upper left leg of the cross
	db	SY-18	,SX-10	,TO+4	,0
	db	SY-18	,SX-18	,TO+2	,0
	db	SY-18-16,SX-18	,TO+2	,0
	db	SY-18-8,SX-26	,TO+2	,0
	db	SY-18-8,SX-26-8	,TO+2	,0

SX = 30
SY = 48
	; Lower left portion of the checkmark. 
	; Hides the left side of the checkmark if emulated incorrectly.
	; Also hides the glitch pixels if misplaced.
	db	SY+0	,SX	,TO+2	,0
	db	SY	,SX+8	,TO+2	,0
	db	SY	,SX+16	,TO+2	,0
	db	SY	,SX+24	,TO+2	,0
	db	SY+16	,SX+16	,TO+2	,0
	db	SY+16	,SX+24	,TO+2	,0


	; Cover dirt on the left side of the screen.
	; In the end I decided to leave the dirt pixels in, though.
;	db	26	,6	,TO+6	,0
;	db	26+16	,6	,TO+6	,0


; Lower copy of the checkmark
SX = 90
SY = 49+76-2
TO = $10	; Tile offset.
	; Lower right leg of the cross
	db	SY+0	,SX+0	,TO+0	,0
	db	SY+0	,SX+8	,TO+2	,0
	db	SY+8	,SX+8	,TO+2	,0
	db	SY+8	,SX+16	,TO+2	,0
	db	SY+22	,SX+16	,TO+2	,0
	db	SY+16	,SX+24	,TO+2	,0
	db	SY+22	,SX+16	,TO+2	,0
	db	SY+22	,SX+32	,TO+2	,0

	; Upper left leg of the cross
	db	SY-18	,SX-10	,TO+4	,0
	db	SY-18	,SX-18	,TO+2	,0
	db	SY-18-16,SX-18	,TO+2	,0
	db	SY-18-8,SX-26	,TO+2	,0
	db	SY-18-8,SX-26-8	,TO+2	,0


.end

SECTION "Checkmark map", ROM0

	PUSHC
	CHARMAP	" ",0
	CHARMAP	"A",1
	CHARMAP	"B",2
	CHARMAP	"C",3
	CHARMAP	"D",4
	CHARMAP	"E",5
	CHARMAP	"a",6
	CHARMAP	"F",7
	CHARMAP	"G",8
MAP_CHECKMARK:
	db	"                                "
	db	"      aA  EDBC                  "
	db	"      aAEDBC                    "
	db	"      FGBC                      "
	db	"AA  EDAA                        "
	db	"AAEDBCaA                        "
	db	"AABC  aA                        "
	db	"BC    aA                        "
	db	"                                "
	db	"                                "
	db	"                                "
	db	"                                "
	db	"                                "
.end
	POPC

SECTION "Hivars", HRAM
joypad_pressed:	db
joypad_held:	db
scrolltable_idx:	db
