;***********************************************************
;*
;*	 Author: Thomas Landzaat and Alexander Reed
;*	   Date: 12/4/2024
;*
;***********************************************************

.include "m32U4def.inc"         ; Include definition file

;***********************************************************
;*  Internal Register Definitions and Constants
;***********************************************************
.def    mpr = r16               ; Multi-Purpose Register
.def	i	= r17

.def	reg16 = r18
.def	ctr1 = r19


.def	ctr = r23

.def	STRING_DISPLAY = r24
.def	waitcnt = r25			; Wait Loop Counter

.equ	WTime = 5				; Time to wait in wait loop


; Use this signal code between two boards for their game ready
.equ    SendReady = 0b11111111

;***********************************************************
;*  Start of Code Segment
;***********************************************************
.cseg                           ; Beginning of code segment

;***********************************************************
;*  Interrupt Vectors
;***********************************************************
.org    $0000                   ; Beginning of IVs
	    rjmp    INIT            	; Reset interrupt

.org	$0002					;INT0
		rcall BUTTON
		reti

.org	$0004					;INT1
		rcall BUTTON2
		reti
		/*
.org	$0028
		rcall	Timer1_Overflow
		reti
*/

.org	$0032
		rcall	USART_Receive
		reti
/*
.org	$0034					;Data Register Empty
		rjmp

.org	$0036					;TX Complete
		rjmp
*/
.org    $0056                   ; End of Interrupt Vectors

;***********************************************************
;*  Program Initialization
;***********************************************************
INIT:
	;Stack Pointer (VERY IMPORTANT!!!!)
		ldi		mpr, low(RAMEND)
		out		SPL, mpr		; Load SPL with low byte of RAMEND
		ldi		mpr, high(RAMEND)
		out		SPH, mpr		; Load SPH with high byte of RAMEND
	;I/O Ports
		; Initialize Port B for output
		ldi		mpr, $FF		; Set Port B Data Direction Register
		out		DDRB, mpr		; for output
		ldi		mpr, $00		; Initialize Port B Data Register
		out		PORTB, mpr		; so all Port B outputs are low

		; Initialize Port D for input
		ldi		mpr, $00		; Set Port D Data Direction Register
		out		DDRD, mpr		; for input
		ldi		mpr, $FF		; Initialize Port D Data Register
		out		PORTD, mpr		; so all Port D inputs are Tri-State

		rcall LCDInit			; Initialize LCD Display
		rcall LCDClr			; Clear display
		rcall LCDBacklightOn	; Turn on LCD Backlight


		ldi ctr, 0b00000000
		ldi ctr1, 0b00000000
		ldi reg16, 0x04
		ldi STRING_DISPLAY, 0b00000000
		clr r6

		ldi mpr, $01
		mov r9, mpr
		
	;USART1
		;Set baudrate at 2400bps

		ldi mpr, 0xCF ; Load low byte
		sts UBRR1L, mpr ; UBRR1L in extended I/O space

		;Enable receiver and transmitter
		ldi mpr, 0b10011000 //used to be 0b10011000
		sts UCSR1B, mpr

		;Set frame format: 8 data bits, 2 stop bits
		ldi mpr, 0b00001110
		sts UCSR1C, mpr
		
		;TIMER/COUNTER1
		;Set Normal mode
		ldi		mpr, 0b00000000  
        sts		TCCR1A, mpr

        ldi		mpr, 0b00000101
        sts		TCCR1B, mpr
		/*Need prescaler 1024*/


		ldi     mpr, (1<<ISC11)|(0<<ISC10)|(1<<ISC01)|(0<<ISC00)
		sts     EICRA, mpr

		ldi     mpr, (0<<INT1)|(0<<INT0)
		out     EIMSK, mpr



		rcall DISPLAY_HOLD
	;Other
	sei


;***********************************************************
;*  Main Program
;***********************************************************
MAIN:
		rcall DISPLAY_HOLD
		
		RECHECK:
		in		mpr, PIND			; Get whisker input from Port D
		andi	mpr, (1<<7)
		cpi		mpr, $00
		brne	RECHECK				; Continue with next check
		rcall	DISPLAY_READY		; Call the subroutine HitRight
		
		WAITING:
			ldi     waitcnt, WTime		; Small Wait to help with multiple presses
			rcall   Wait
		rcall Transmit_Ready
			ldi     waitcnt, WTime		; Small Wait to help with multiple presses
			rcall   Wait

		cpi mpr, SendReady
		brne WAITING
		rcall InitGameStart
		rcall LED_COUNTDOWN	

		ldi     waitcnt, WTime		; Small Wait to help with multiple presses
		rcall   Wait
		rcall USART_Transmit
		ldi     waitcnt, WTime		; Small Wait to help with multiple presses
		rcall   Wait

		rcall OPP

		rcall LED_COUNTDOWN

			ldi     waitcnt, WTime		; Small Wait to help with multiple presses
			rcall   Wait
		rcall TRANSMIT_HAND
			ldi     waitcnt, WTime		; Small Wait to help with multiple presses
			rcall   Wait



		rcall DISPLAYWINNER
		//SBI PORTB, 7
			ldi     waitcnt, 200		; Small Wait to help with multiple presses
			rcall   Wait 

			clr r6
			clr ctr
			clr ctr1

			rjmp	MAIN
		//rcall WAIT_1_5sec
		//rcall WAIT_1_5sec

		//rcall LED_COUNTDOWN
		//rcall DISPLAYWINNER
		/*WAITING:

		rcall Transmit_Ready
		rcall USART_Receive
		cpi mpr, SendReady
		brne WAITING
		rcall LED_COUNTDOWN	
		*/
	

		MAIN2:
		rjmp	MAIN





DISPLAY_HOLD:
	push YL
	push YH
	push i
	ldi YL, $00
	ldi YH, $01
	ldi ZL, low(STRING_START<<1)
	ldi ZH, high(STRING_START<<1)
	ldi i, 32

	; Move strings from Program Memory to Data Memory
	LOOPLOAD: 
		lpm r7, Z+
		st Y+, r7
		dec i
		brne LOOPLOAD

		pop i
		pop YH
		pop YL

		rcall LCDWrLn1;
		rcall LCDWrLn2;
ret



DISPLAY_READY:
	push YL
	push YH
	push i
	ldi YL, $00
	ldi YH, $01
	ldi ZL, low(READY_START<<1)
	ldi ZH, high(READY_START<<1)
	ldi i, 32

	; Move strings from Program Memory to Data Memory
	LOOPREADY: 
		lpm r7, Z+
		st Y+, r7
		dec i
		brne LOOPREADY

		pop i
		pop YH
		pop YL

		rcall LCDWrLn1;
		rcall LCDWrLn2;
ret

TRANSMIT_READY:
	push r18
	push r11
	
	ldi r18, SendReady
	UDRFULL:
	lds r11, UCSR1A
	sbrs r11, UDRE1
	rjmp UDRFULL
	sts UDR1, r18
	//ldi mpr, (1<<5)
	//sts UCSR1A, mpr  does it auto clear flag?
	
	pop r11
	pop r18
ret

	USART_TRANSMIT:
	push r2
	push r3
	push ctr
	push ctr1
	push r25
	
	mov r2, ctr
	mov r3, ctr1
	
	rol r2
	rol r2
	
	or r2, r3
	
	UDRFULL2:
	lds r25, UCSR1A
	sbrs r25, UDRE1
	rjmp UDRFULL2
	sts UDR1, r2

	/*ldi ctr, 0b0000_0101
	cp ctr, r2
	brne ENDng
	SBI PORTB, 7

	ENDng:*/
	pop r25
	pop ctr1
	pop ctr
	pop r3
	pop r2
ret

TRANSMIT_HAND:
	push r11
	
	
	UDRFULL1:
	lds r11, UCSR1A
	sbrs r11, UDRE1
	rjmp UDRFULL1
	sts UDR1, r9
	
	pop r11
ret



USART_Receive:
	//push mpr
	lds mpr, UDR1
	//SBI PORTB, 6
	//pop mpr
ret


WAIT_1_5sec:
	push i
	push r25
	ldi i, 150

WAIT_10msec:
    ldi mpr, high(0xFFB1) 
    sts TCNT1H, mpr       
    ldi mpr, low(0xFFB1)  
    sts TCNT1L, mpr     

LOOP:
	in r25, TIFR1
    sbrs r25, TOV1        ; Skip next instruction if TOV1 is set
    rjmp LOOP             ; Loop if TOV1 no set


		RECHECK4:

	ldi mpr, (1 << TOV1)  ; TOV1 = 1 (bit 0)
    out TIFR1, mpr	      ; Clear the overflow flag

    dec i                 
    brne WAIT_10msec      

    pop r25              
    pop i                 
ret                   




LED_COUNTDOWN:
	push r27
	ldi r27, 0b11110000
	out PORTB, r27
		ldi     r27, (1<<INT1)|(1<<INT0)
		out     EIMSK, r27

	rcall WAIT_1_5sec
	CBI PORTB, 7
	rcall WAIT_1_5sec
	CBI PORTB, 6
	rcall WAIT_1_5sec
	CBI PORTB, 5
	rcall WAIT_1_5sec
	CBI PORTB, 4

		ldi     r27, (0<<INT1)|(0<<INT0)
		out     EIMSK, r27

		ldi r27, $01
		mov r6, r27

	pop r27

ret



InitGameStart:
	push r4
	push i
	push YL
	push YH
	push ZL
	push ZH
	cli

	ldi YL, $00
	ldi YH, $01

	ldi ZL, low(GAME_START<<1)
	ldi ZH, high(GAME_START<<1)

	ldi i, 16

	; Move strings from Program Memory to Data Memory
	LOOPGAME: 
	lpm r4, Z+
	st Y+, r4
	dec i
	brne LOOPGAME


	ldi YL, $10
	ldi YH, $01

	ldi ZL, low(ROCK_START<<1)
	ldi ZH, high(ROCK_START<<1)

	ldi i, 8

	; Move strings from Program Memory to Data Memory
	LOOPROCK1: 
	lpm r4, Z+
	st Y+, r4
	dec i
	brne LOOPROCK1

	ldi YL, $18
	ldi YH, $01

	ldi ZL, low(STRING_ROCK2<<1)
	ldi ZH, high(STRING_ROCK2<<1)

	ldi i, 8

	; Move strings from Program Memory to Data Memory
	LOOPROCK2: 
	lpm r4, Z+
	st Y+, r4
	dec i
	brne LOOPROCK2

	rcall LCDWrLn1
	rcall LCDWrLn2


	pop ZH
	pop ZL
	pop YH
	pop YL
	pop i
	pop r4
	sei
	ret

BUTTON:
	push r28
	push r8
	push i

	ldi     r28, (1 << INTF0)
	out     EIFR, r28

	clr R8
	clr R5

	cp r5, r6
	breq ME
	rjmp RESTORE

	ME:
	cpi ctr, 2          ; Compare ctr with 2
	brlo increment_ctr   ; If ctr < 2, branch to increment_ctr
	clr ctr              ; Clear ctr (set to 0)
	rjmp done            ; Skip incrementing

	increment_ctr:
	inc ctr              ; Increment ctr by 1

	done:
	
	mul ctr, reg16				; Stores result in R0
	
	ldi ZL, low(ROCK_START)
	ldi ZH, high(ROCK_START)

	add ZL, R0
	adc ZH, R8

	// Load address of LCD screen
	ldi YL, $10
	ldi YH, $01

	//Bitshift low bit of Z
	mov STRING_DISPLAY, ZL
	rol STRING_DISPLAY
	mov ZL, STRING_DISPLAY

	// Bitshift High bit of Z
	mov STRING_DISPLAY, ZH
	rol STRING_DISPLAY
	mov ZH, STRING_DISPLAY

	ldi i, 8

	; Move strings from Program Memory to Data Memory
	LOOPLOAD1: 
	lpm r7, Z+
	st Y+, r7
	dec i
	brne LOOPLOAD1

	rcall LCDWrLn2
	
	RESTORE:
	pop i
	pop r8
	pop r28
ret

BUTTON2:
	push r28
	push r8
	push i

	clr R8
	clr R5

	cp r5, r6
	breq ME2
	//rjmp OPP
	clr r9
	rjmp RESTORE2

	ME2:

	ldi     r28, (1 << INTF1)
	out     EIFR, r28

	cpi ctr1, 2          ; Compare ctr with 2
	brlo increment_ctr1  ; If ctr < 2, branch to increment_ctr
	clr ctr1              ; Clear ctr (set to 0)
	rjmp done1            ; Skip incrementing

	increment_ctr1:
	inc ctr1             ; Increment ctr by 1

	done1:
	

	mul ctr1, reg16				; Stores result in R0
	
	ldi ZL, low(STRING_ROCK2)
	ldi ZH, high(STRING_ROCK2)

	add ZL, R0
	adc ZH, R8

	// Load address of LCD screen
	ldi YL, $18
	ldi YH, $01

	//Bitshift low bit of Z
	mov STRING_DISPLAY, ZL
	rol STRING_DISPLAY
	mov ZL, STRING_DISPLAY

	// Bitshift High bit of Z
	mov STRING_DISPLAY, ZH
	rol STRING_DISPLAY
	mov ZH, STRING_DISPLAY

	ldi i, 8

	; Move strings from Program Memory to Data Memory
	LOOPLOAD2: 
	lpm r7, Z+ //was mpr
	st Y+, r7 //was mpr
	dec i
	brne LOOPLOAD2

	rcall LCDWrLn2

	RESTORE2:
	pop i
	pop r8
	pop r28
ret

OPP:
	push r28
	push r8
	push i
	//push mpr

	//ldi     r28, (1 << INTF0)
	//out     EIFR, r28

	clr R8
	//clr R14

	//cp r15, r14
	//brne OPP
	

	mov r15, mpr
	mov r14, r15

	ror r15
	ror r15
	mov mpr, r15
	andi mpr, $03

	mov r12, mpr

	mov mpr, r14
	andi mpr, $03

	mov r13, mpr


	
	mul r12, reg16				; Stores result in R0
	
	ldi ZL, low(ROCK_START)
	ldi ZH, high(ROCK_START)

	add ZL, R0
	adc ZH, R8

	// Load address of LCD screen
	ldi YL, $00
	ldi YH, $01

	//Bitshift low bit of Z
	mov STRING_DISPLAY, ZL
	rol STRING_DISPLAY
	mov ZL, STRING_DISPLAY

	// Bitshift High bit of Z
	mov STRING_DISPLAY, ZH
	rol STRING_DISPLAY
	mov ZH, STRING_DISPLAY

	ldi i, 8

	; Move strings from Program Memory to Data Memory
	LOOPLOAD3: 
	lpm r7, Z+
	st Y+, r7
	dec i
	brne LOOPLOAD3

	rcall LCDWrLn1

	mul r13, reg16				; Stores result in R0
	
	ldi ZL, low(STRING_ROCK2)
	ldi ZH, high(STRING_ROCK2)

	add ZL, R0
	adc ZH, R8

	// Load address of LCD screen
	ldi YL, $08
	ldi YH, $01

	//Bitshift low bit of Z
	mov STRING_DISPLAY, ZL
	rol STRING_DISPLAY
	mov ZL, STRING_DISPLAY

	// Bitshift High bit of Z
	mov STRING_DISPLAY, ZH
	rol STRING_DISPLAY
	mov ZH, STRING_DISPLAY

	ldi i, 8

	; Move strings from Program Memory to Data Memory
	LOOPLOAD4: 
	lpm r7, Z+
	st Y+, r7
	dec i
	brne LOOPLOAD4
	
	rcall LCDWrLn1

	//pop mpr
	pop i
	pop r8
	pop r28
ret




; Assume player 1's move is in ctr and player 2's move in temp
DISPLAYWINNER:
	cli
	push r7
	push i
	push reg16

	clr r14

	cpi mpr, $01
	brne RHAND
	mov r26, r12
	rjmp OURHAND

	RHAND:
	mov r26, r13

	OURHAND:
	cp r9, r14
	brne WINCOND
	mov ctr, ctr1
	rjmp WINCOND

	
    ; Check for tie
	
	//ldi r26, $01 
	WINCOND: //PAPER_OPP
	ldi reg16, $08
	clr R8

	cpi mpr, $01
	brne DISPRHAND

	mul r12, reg16				; Stores result in R0
	
	ldi ZL, low(ROCK_OPP)
	ldi ZH, high(ROCK_OPP)

	add ZL, R0
	adc ZH, R8

	// Load address of LCD screen
	ldi YL, $00
	ldi YH, $01

	//Bitshift low bit of Z
	mov STRING_DISPLAY, ZL
	rol STRING_DISPLAY
	mov ZL, STRING_DISPLAY

	// Bitshift High bit of Z
	mov STRING_DISPLAY, ZH
	rol STRING_DISPLAY
	mov ZH, STRING_DISPLAY

	ldi i, 16

	; Move strings from Program Memory to Data Memory
	LOOPDISP: 
	lpm r7, Z+
	st Y+, r7
	dec i
	brne LOOPDISP

	rcall LCDWrLn1

	rjmp DONEOPPDISP

	DISPRHAND:
	mul r13, reg16				; Stores result in R0
	
	ldi ZL, low(ROCK_OPP)
	ldi ZH, high(ROCK_OPP)

	add ZL, R0
	adc ZH, R8

	// Load address of LCD screen
	ldi YL, $00
	ldi YH, $01

	//Bitshift low bit of Z
	mov STRING_DISPLAY, ZL
	rol STRING_DISPLAY
	mov ZL, STRING_DISPLAY

	// Bitshift High bit of Z
	mov STRING_DISPLAY, ZH
	rol STRING_DISPLAY
	mov ZH, STRING_DISPLAY

	ldi i, 16

	; Move strings from Program Memory to Data Memory
	LOOPDISP2: 
	lpm r7, Z+
	st Y+, r7
	dec i
	brne LOOPDISP2
	
	rcall LCDWrLn1

	
	DONEOPPDISP:

	cp r9, r14
	breq DISPOURHAND

	mul ctr, reg16				; Stores result in R0
	
	ldi ZL, low(ROCK_OPP)
	ldi ZH, high(ROCK_OPP)

	add ZL, R0
	adc ZH, R8

	// Load address of LCD screen
	ldi YL, $10
	ldi YH, $01

	//Bitshift low bit of Z
	mov STRING_DISPLAY, ZL
	rol STRING_DISPLAY
	mov ZL, STRING_DISPLAY

	// Bitshift High bit of Z
	mov STRING_DISPLAY, ZH
	rol STRING_DISPLAY
	mov ZH, STRING_DISPLAY

	ldi i, 16

	; Move strings from Program Memory to Data Memory
	LOOPLOAD5: 
	lpm r7, Z+
	st Y+, r7
	dec i
	brne LOOPLOAD5

	rcall LCDWrLn2

	rjmp DISPDONE

	DISPOURHAND:
	mul ctr1, reg16				; Stores result in R0
	
	ldi ZL, low(ROCK_OPP)
	ldi ZH, high(ROCK_OPP)

	add ZL, R0
	adc ZH, R8

	// Load address of LCD screen
	ldi YL, $10
	ldi YH, $01

	//Bitshift low bit of Z
	mov STRING_DISPLAY, ZL
	rol STRING_DISPLAY
	mov ZL, STRING_DISPLAY

	// Bitshift High bit of Z
	mov STRING_DISPLAY, ZH
	rol STRING_DISPLAY
	mov ZH, STRING_DISPLAY

	ldi i, 16

	; Move strings from Program Memory to Data Memory
	LOOPLOAD6: 
	lpm r7, Z+
	st Y+, r7
	dec i
	brne LOOPLOAD6
	
	rcall LCDWrLn2

	//pop reg16

	DISPDONE:
		ldi     waitcnt, 150		; Small Wait to help with multiple presses
		rcall   Wait

    cp ctr, r26          ; Compare R16 (Player 1) and R17 (Player 2)
    breq tie			  ; Branch to 'tie' if moves are equal

    ; Player 1 plays Rock (0)
    cpi ctr, 0
    brne check_paper     ; If not rock, check for other moves

    cpi r26, $02	         ; If Player 2 has scissors (2), Player 1 wins
    breq p1_wins		  
    rjmp p2_wins         ; Otherwise, Player 2 wins

check_paper:
    ; Player 1 plays Paper (1)
    cpi ctr, 1
    brne check_scissors  ; If not paper, check scissors
    cpi r26, $00           ; If Player 2 has rock (0), Player 1 wins
    breq p1_wins
    rjmp p2_wins         ; Otherwise, Player 2 wins

check_scissors:
    ; Player 1 plays Scissors (2)
    cpi r26, $01           ; If Player 2 has paper (1), Player 1 wins
    breq p1_wins
    rjmp p2_wins         ; Otherwise, Player 2 wins

p1_wins:
    ; You Win
	LOOPWIN: 
	lpm r7, Z+
	st Y+, r7
	dec i
	brne LOOPWIN

	ldi YL, $00
	ldi YH, $01

	ldi ZL, low(WIN_START<<1)
	ldi ZH, high(WIN_START<<1)

	ldi i, 16

	; Move strings from Program Memory to Data Memory
	LOOPWIN2: 
	lpm r7, Z+
	st Y+, r7
	dec i
	brne LOOPWIN2

	rcall LCDWrLn1

    rjmp ENDfun

p2_wins:
    ; You Lose
	LOOPLOSE: 
	lpm r7, Z+
	st Y+, r7
	dec i
	brne LOOPLOSE

	ldi YL, $00
	ldi YH, $01

	ldi ZL, low(LOSE_START<<1)
	ldi ZH, high(LOSE_START<<1)

	ldi i, 16

	; Move strings from Program Memory to Data Memory
	LOOPLOSE2: 
	lpm r7, Z+
	st Y+, r7
	dec i
	brne LOOPLOSE2

	rcall LCDWrLn1

    rjmp ENDfun

tie:
	; You Tie
	LOOPTIE: 
	lpm r7, Z+
	st Y+, r7
	dec i
	brne LOOPTIE

	ldi YL, $00
	ldi YH, $01

	ldi ZL, low(TIE_START<<1)
	ldi ZH, high(TIE_START<<1)

	ldi i, 16

	; Move strings from Program Memory to Data Memory
	LOOPTIE2: 
	lpm r7, Z+
	st Y+, r7
	dec i
	brne LOOPTIE2

	rcall LCDWrLn1

	rjmp ENDfun

ENDfun:
	pop reg16
	pop i
	pop r7
	sei

    ret

;----------------------------------------------------------------
; Sub:	Wait
; Desc:	A wait loop that is 16 + 159975*waitcnt cycles or roughly
;		waitcnt*10ms.  Just initialize wait for the specific amount
;		of time in 10ms intervals. Here is the general eqaution
;		for the number of clock cycles in the wait loop:
;			(((((3*ilcnt)-1+4)*olcnt)-1+4)*waitcnt)-1+16
;----------------------------------------------------------------
Wait:
		push	waitcnt			; Save wait register
		push	r18			; Save ilcnt register
		push	r19			; Save olcnt register

LoopW:	ldi		r19, 224		; load olcnt register
OLoop:	ldi		r18, 237		; load ilcnt register
ILoop:	dec		r18			; decrement ilcnt
		brne	ILoop			; Continue Inner Loop
		dec		r19		; decrement olcnt
		brne	OLoop			; Continue Outer Loop
		dec		waitcnt		; Decrement wait
		brne	LoopW			; Continue Wait loop

		pop		r19		; Restore olcnt register
		pop		r18		; Restore ilcnt register
		pop		waitcnt		; Restore wait register
		ret					; Return from subroutine
;***********************************************************
;*	Stored Program Data
;***********************************************************

;-----------------------------------------------------------
; An example of storing a string. Note the labels before and
; after the .DB directive; these can help to access the data
;-----------------------------------------------------------
STRING_START:
    .DB		"Welcome!        "		; Declaring data in ProgMem
STRING_END:

STRING_START2:
	.DB		"Please press PD7"
STRING_END2:

ROCK_START:
	.DB		"Rock    "
ROCK_END:

PAPER_START:
	.DB		"Paper   "
PAPER_END:

SCISSORS_START:
	.DB		"Scissor "
SCISSORS_END:

STRING_ROCK2:
	.DB		"|Rock   "
STRING_ROCK_END2:

STRING_PAPER2:
	.DB		"|Paper  "
STRING_PAPER_END2:

STRING_SCISSORS2:
	.DB		"|Scissor"
STRING_SCISSORS_END2:

WIN_START:
	.DB		"You Win!        "
WIN_END:

TIE_START:
	.DB		"Tie             "
TIE_END:

LOSE_START:
	.DB		"You Lose        "
LOSE_END:

READY_START:
	.DB		"Ready. Waiting  "
READY_END:

READY2_START:
	.DB		"for the opponent"
READY2_END:

GAME_START:
	.DB		"Game Start      "
GAME_END:

ROCK_OPP:
	.DB		"Rock            "
ROCK_OPPEND:

PAPER_OPP:
	.DB		"Paper           "
PAPER_OPPEND:

SCISSORS_OPP:
	.DB		"Scissor         "
SCISSORS_OPPEND:


;***********************************************************
;*	Additional Program Includes
;***********************************************************
.include "LCDDriver.asm"		; Include the LCD Driver


