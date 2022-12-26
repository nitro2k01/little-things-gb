include "incs/hardware.inc"

; Emit GBC palette entry.
; The color components are 5 bit. (0-31)
; PAL_ENTRY R,G,B
PAL_ENTRY:	MACRO
	assert (\1)==(\1)&%11111
	assert (\2)==(\2)&%11111
	assert (\3)==(\3)&%11111
	dw	(\1) | (\2)<<5| (\3)<<10
ENDM

SECTION "rst_38", ROM0[$38]
	call	HANDLE_RESULT

SECTION "int_vbl", ROM0[$40]
INT_VBL:
	call	HANDLE_RESULT

SECTION "int_lcd", ROM0[$48]
INT_LCD:
	call	HANDLE_RESULT

SECTION "Header", ROM0[$100]
	di				; 1
	jp	ENTRY			; 4

	ds	$150 - @, 0

SECTION "Main", ROM0
ENTRY::
	ldh	[initial_a],A		; Save for GBC detection later.

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

	ld	C,LOW(clear_after_here)
	xor	A
.clear_hram_loop
	ld	[$FF00+C],A
	inc	C
	jr	nz,.clear_hram_loop

	ld	HL,_OAMRAM		; Clear OAM
	ld	E,L			; L==0
	ld	BC,$A0
	call	CLEAR

	call	INIT_VRAM

	ld	A,$C0
	ldh	[rWX],A
	ldh	[rWY],A

	ld	A,%11100100
	ldh	[rBGP],A

	ld	A,IEF_VBLANK|IEF_STAT
	ldh	[rIE],A

	xor	A
	ldh	[rSCX],A
	ldh	[rSCY],A
	ldh	[rIF],A
	ld	HL,HALT_TEST_ROM
	ld	DE,HALT_TEST_VRAM
	ld	BC,HALT_TEST_VRAM.end-HALT_TEST_VRAM
	call	COPY

	; Reset timer.
	xor	A
	ldh	[rDIV],A

	ld	A,LCDCF_ON|LCDCF_WINON|LCDCF_BG8000|LCDCF_BGON
	ldh	[rLCDC],A

	ld	DE,$0000
	push	DE

	; Wait for not HBlank, then HBlank.
:	ldh	A,[rSTAT]
	and	$03
	jr	z,:-

:	ldh	A,[rSTAT]
	and	$03
	jr	nz,:-

	jp	HALT_TEST_VRAM

HALT_TEST_ROM:
LOAD "VRAM code", VRAM[$9C00]
HALT_TEST_VRAM:
	ld	A,IEF_STAT
	ldh	[rIE],A
	ld	A,IEF_STAT|IEF_VBLANK
	ldh	[rIF],A
.halts
	halt
	halt
	jr	@+2
	; If 
.after_jr
	call	HANDLE_RESULT
.retaddr_normal_jr
	ds	$18-@+.after_jr,0
.jr_double_bug
	call	HANDLE_RESULT
.retaddr_bugged_jr
.end
ENDL

INIT_VRAM:
	; Do a couple of GBC related init tasks even though we're (supposedly) not in GBC mode.
	; This is insurance that we're able to show things on screen even if we detect the CPU
	; mode incorrectly somehow. In other case, these are NOPs.

	; Restore VRAM bank.
	xor	A
	ldh	[rVBK],A

	; Load one palette so text is visible
	ld	BC,8<<8|LOW(rBCPS)
	ld	HL,GbcPals
	ld	A,$80
	ld	[$FF00+C],A
	inc	C
.palloop
	ld	A,[HL+]
	ld	[$FF00+C],A
	dec	B
	jr	nz,.palloop

	; Clear tilesets, and the visible part of the $9800 map.
	ld	HL,$8000
	ld	B,$9B			; Top byte of end address
	ld	E,L			; L==0
	call	FASTCLEAR

	; Load a font into tile RAM.
	ld	HL,Font0
	ld	DE,$8200
	ld	BC,Font0.end-Font0
	call	COPY

	ld	HL,S_ALL
	ld	DE,$9800
	call	MPRINT

	ld	HL,S_VERSION
	ld	DE,$9A2F
	call	MPRINT

	ldh	A,[initial_a]
	cp	$11
	jr	nz,.nogbc
	ld	HL,S_YES
	ld	DE,$988D
	call	MPRINT

.nogbc
	ret

CHECK_RET_ADDR:
	ld	E,-1

.loop	inc	E
	ld	A,[HL+]
	ld	D,A			; Lower byte of reference value.
	or	[HL]
	ret	z

	ld	A,[HL+]
	cp	B
	jr	nz,.loop

	ld	A,D
	cp	C
	jr	nz,.loop

	ret

LIST_RET_ADDRS:
	;	String address, reference return address
	dw	$003B		; rst $38 (Correct)
	dw	$0043		; VBlank interrupt
	dw	$004B		; HBlank interrupt
	dw	HALT_TEST_VRAM.retaddr_normal_jr
	dw	HALT_TEST_VRAM.retaddr_bugged_jr
	dw	$0000		; End of list

LIST_RET_STRINGS:
	dw	S_RST38, S_VBL_INT, S_LCD_INT
	dw	S_JR_NO_DOUBLE, S_JR_DOUBLE
	dw	S_ERROR

HANDLE_RESULT:
	call	CAPTURE_LY_AND_DIV	; CAPTURE_LY_AND_DIV takes the call to itself into account.

	pop	BC
	push	BC

	ld	HL,LIST_RET_ADDRS
	call	CHECK_RET_ADDR
	ld	A,E
	ldh	[ret_type],A

	ld	D,0
	ld	HL,LIST_RET_STRINGS
	add	HL,DE
	add	HL,DE

	ld	A,[HL+]
	ld	H,[HL]
	ld	L,A

	; Wait for VBlank
:	ldh	A,[rLY]
	cp	$90
	jr	nz,:-

	ld	DE,$9826
	call	MPRINT

	; This is the address HANDLE_RESULT was called from.
	pop	HL
	ldh	A,[ret_type]
	; Unknown address at the top of the stack? 
	; Print it so we can figure out wtf happened!
	cp	5		; TODO: Evaluate this.
	jr	z,.print_ret_addr

	pop	HL
	; Only do the extra calculation for ret type 0-2.
	cp	3
	jr	nc,.print_ret_addr

	ld	BC,(-HALT_TEST_VRAM.halts)&$FFFF
	add	HL,BC

	; Print a plus to signify relative value.
	ld	A,"+"
	ld	[$9849],A

.print_ret_addr
	push	HL			; Save for later validation.

	ld	C,L
	ld	A,H
	ld	HL,$984A
	call	PRINTHEX

	ld	A,C
	ld	HL,$984C
	call	PRINTHEX

	ldh	A,[ly_store]
	ld	HL,$9864
	call	PRINTHEX

	ldh	A,[div_store]
	ld	HL,$986C
	call	PRINTHEX

	ld	A,"."
	ld	[HL+],A

	ldh	A,[div_acc_store]
	call	PRINTHEX

	; ret addr==$0001?
	pop	BC
	ld	A,B
	or	A
	jr	nz,.no_cookie_for_you
	dec	C
	jr	nz,.no_cookie_for_you

	; ret type==0? (Came through rst $38)
	ldh	A,[ret_type]
	or	A
	jr	nz,.no_cookie_for_you

	; LY==1?
	ldh	A,[ly_store]
	dec	A
	jr	nz,.no_cookie_for_you

	; DIV==02.13 (DMG) or DIV==02.14 (GBC)
	ldh	A,[div_store]
	cp	2
	jr	nz,.no_cookie_for_you

	; Load reference value.
	ldh	A,[initial_a]
	cp	$11		; GBC?
	ld	B,$15
	jr	nz,.nogbc
	inc	B
.nogbc

	; Check fractional part.
	ldh	A,[div_acc_store]
	cp	B
	jr	nz,.no_cookie_for_you


	ld	DE,$98C8
	ld	HL,S_PASS
	call	MPRINT
.no_cookie_for_you
	jr	@


; Capture timing related information.
; This routine reads and stores LY.
; It then reads and stores DIV, and derives the hidden fractional part of DIV.
;
; It does this by periodically checking whether DIV ticked, with a period of 65 M cycles.
; Since (the visible portion of) DIV ticks every 64 M cycles, each loop iteration is
; progreesively offset by 1 cycle.
;
; Since there's a 2 M cycle window between read 1 and read 2, a tick will be observed for
; two consecutive loop iterations. The code following the capture sanity checks the 
; captured data and (if ok) derives the fractional part of DIV.
;
; The value it measures and calculates is the value of the visible and fractional part of DIV
; as if "call CAPTURE_LY_AND_DIV" was replaced with the "ld A,[HL]" that's reading DIV initially.
CAPTURE_LY_AND_DIV:
	ldh	A,[rLY]
	ldh	[ly_store],A

	; For testing single M cycle timing shifts.
;	rept $1d
;	nop
;	endr
	ld	HL,rDIV
	ld	A,[HL]
	ldh	[div_store],A

	ld	DE,SCRATCH
	ld	C,$40	; C=loop counter
.captureloop
	; Check whether DIV ticked between read 1 and read 2.
	; If the values are equal, the DIV1-DIV2=0.
	; If DIV ticked, DIV1-DIV2=$FF.
	ld	A,[HL]			; 2
	sub	[HL]			; 2

	ld	[DE],A			; 2
	inc	DE			; 2

	ld	B,13			; 2
.waitloop
	dec	B			; 1
	jr	nz,.waitloop		; 3/2
	;13*4-1=51

	dec	C			; 1
	jr	nz,.captureloop		; 3 (taken)
	; 2+2+2+2+2+51+1+3=65

	; Sanity check
	ld	HL,SCRATCH
	ld	C,$40
	ld	E,0			; Number of zeros.
.sanityloop
	ld	A,[HL+]
	or	A	
	jr	z,.zero
	inc	A			; Check for FF, the only allowed nonzero value.
	jr	nz,.badvalue
	dec	E			; Reverse the effect of the next dec.
.zero
	inc	E
	dec	C
	jr	nz,.sanityloop
	; What we know so far: 
	; * Array contains only 00 and FF. 
	; * Number of 00 bytes.
	ld	A,E
	cp	$3E
	jr	nz,.badvalue
	; * Array contains exactly $3E zeros and 2 FF.
	; * But not yet whether the two FF are contiguous.
	ld	A,[SCRATCH+$3F]
	ld	B,A			; Last value wrapped
	ld	C,$40
	ld	DE,$0000
	ld	HL,SCRATCH

.checkloop
	ld	A,[HL+]
	or	A
	jr	z,.nextvalue
	inc	B			; Check if last value was also FF.
	jr	z,.store_acc
.nextvalue
	ld	B,A			; Save current value as last value.
	dec	C
	jr	nz,.checkloop
	jr	.badvalue		; Iterated through whole array without finding two consecutive FF...
.store_acc
	ld	A,C
	sub	$0B			; Tuned offset
	and	$3f			; Modulo to 0-$3F
	sub	6+3+3+3			; Subtract the time consumed by the code before the read, and the implied call instruction.
	jr	nc,.nocarry
	ld	HL,div_store
	dec	[HL]
.nocarry
	and	$3f			; Modulo to 0-$3F again
.store_acc_raw
	ldh	[div_acc_store],A
	ret
.badvalue
	ld	A,$FF
	jr	.store_acc_raw


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
GbcPals:
	PAL_ENTRY	31,31,31
	PAL_ENTRY	16,16,16
	PAL_ENTRY	8,8,8
	PAL_ENTRY	0,0,0
.end

SECTION "Strings", ROM0
S_ALL:	db	"DOUBLE HALT CANCEL\n"
	db	"FATE: HALTED!\n"
	db	"RET ADDR: N/A\n"
	db	"LY:    DIV:\n"
	db	"SYS GBC-ISH? NO\n\n"
	db	"RESULT: FAIL!"
	db	0
S_VERSION:db	"V 1.0",0
S_RST38:db	"RST $38",0
S_LCD_INT:db	"LCD INT FIRED",0
S_VBL_INT:db	"VBL INT FIRED",0
S_PASS:	db	"PASS!",0
S_JR_NO_DOUBLE:	db "FALLTHROUGH",0
S_JR_DOUBLE:	db "FALLTHR. BUG",0
S_YES:	db	"YES",0
S_ERROR:db	"ERROR! ",0

SECTION "Fine calc scratch", WRAM0
; Buffer for capturing timing data.
SCRATCH:
	ds	$40

SECTION "Hivars", HRAM[$FF80]
initial_a:	db
clear_after_here:
joypad_pressed:	db
joypad_held:	db
ret_type:	DB
ly_store:	DB
div_store:	DB
div_acc_store:	DB
