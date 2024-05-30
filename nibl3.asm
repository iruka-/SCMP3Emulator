; This listing was reverse engineered and commented from a dump of the 8073N ROM
; It may look like valid SC/MP-III assembler, but probably isn't. This is purely for
; reference - not for feeding into an assembler program.
; Analysed and commented by Holger Veit (20140315)
		cpu 8070
; locations in on-chip RAM
MULOV	=	0xffc0					; DW high 16 bit from MPY
INPMOD	=	0xffc2					; DB input mode: 0x00 interactive, <>0 in INPUT, 01: running
CURRNT	= 	0xffc3					; DW current line number executed
RUNMOD	=	0xffc5					; DB runmode 'R', 0x00
EXTRAM	=	0xffc6					; DW start of variables (26 words)
AESTK	=	0xffc8					; DW start of arithmetic stack (13 words)
SBRSTK	=	0xffca					; DW start of GOSUB stack (10 words)
DOSTK	=	0xffcc					; DW start of DO stack (10 words)
FORSTK	=	0xffce					; DW start of FOR stack (28 words)

BUFAD	=	0xffd0					; DW
STACK	=	0xffd2					; DW top of stack
TXTBGN	=	0xffd4					; DW start of program area
TXTUNF	=	0xffd6					; DW
TXTEND	=	0xffd8					; DW end of program area
DOPTR	=	0xffda					; DW ptr to DO level?
FORPTR	=	0xffdc					; DW ptr to FOR level?
SBRPTR	= 	0xffde					; DW ptr to GOSUB level?

INTVEC	=	0xffe0					; DW current interrupt vector
INTAVC	=	0xffe2					; DW Interrupt A vector
INTBVC	=	0xffe4					; DW Interrupt B vector
BRKFLG	=	0xffe6					; DB if 0 check for BREAK from serial
NOINT	=	0xffe7					; DB flag to suppress INT after having set STAT

ONE		= 	0xffe8					; DW constant 1
ZERO	= 	0xffea					; DW constant 0
DLYTIM	=	0xffec					; DW delay value for serial I/O
CONTP	=	0xffee					; DW buffer pointer for CONT

TMPF0	=	0xfff0					; DW temporary for moving program code for insertion
TMPF2	=	0xfff2					; DW temp store for current program pointer

RNDNUM	=	0xfff4					; DW rnd number

TMPF6	=	0xfff6					; DB,DW temporary
UNUSE1	=	0xfff8					; DW unused
TMPFB	=	0xfffb					; DB,DW temporary
TMPFC	=	0xfffc					; DB,DW temporary (overlaps TMPFB)
TMPFE	=	0xfffe					; DW temporary, alias

; more constants
RAMBASE	=	0x1000					; start of RAM
ROMBASE	=	0x1400					; potential start of a ROM (BASIC AREA)
BAUDFLG	=	0xFD00					; address of baudrate selection bits

BS		=	0x08					; back space
CR		=	0x0d					; carriage return
LF		=	0x0a					; line feed
NAK		=	0x15					; CTRL-U, NAK
SPACE	=	' '						; space character
GTR		=	'>'						; prompt for interactive mode
QUEST	=	'?'						; prompt for input mode
CARET	=	'^'						; prefix for CTRL output


; interpreter starts here
; assumptions "should be" refer to 1K RAM at 0x1000-0x13ff)
			ORG	0
			NOP    					; lost byte because of PC preincrement
			JMP 	COLD			; Jump to cold start
			JMP		INTA			; Jump to interrupt a handler
			JMP 	INTB			; Jump to interrupt b handler
COLD:		LD		EA, =ROMBASE	; bottom address of ROM
COLD1:		ST		EA, TXTBGN		; set begin of text to ROM
			LD		EA, =RAMBASE	; set P2 to point to base of RAM
			LD 		P2, EA			;
COLD2:		JSR 	TSTRAM1			; test for RAM at loc P2
			BNZ 	COLD2			; not zero: no RAM, loop
			LD 		EA, P2			; found RAM, get address
			SUB 	EA, =1			; subtract 1 to get the current position
			BNZ 	COLD2			; is not at xx00, search next
			BRA 	COLD3			; found a page skip over call tbl, continue below

; short CALL table
			DW		RELEXP-1			; call 0 (RELEXP)
			DW		FACTOR-1  		; call 1 (FACTOR)
			DW		SAVOP-1    		; call 2 (SAVOP)
			DW		COMPAR-1		; call 3 (COMPAR)
			DW		APUSH-1			; call 4 (APUSH)
			DW		APULL-1			; call 5 (APULL)
			DW		ENDCMD-1		; call 6 (ENDCMD)
			DW		PUTC-1			; call 7 (PUTC)
			DW		CRLF-1			; call 8 (CRLF)
			DW		GETCHR-1		; call 9 (GETCHR)
			DW		NEGATE-1		; call 10 (NEGATE)
			DW		CMPTOK-1		; call 11 (CMPTOK)
			DW		EXPECT-1		; call 12 (EXPECT c, offset)
			DW		NUMBER-1		; call 13 (NUMBER, offset)
			DW		PRTLN-1			; call 14 (PRTLN)
			DW		ERROR-1			; call 15 (ERROR)

; continues here from cold start
COLD3:		ST		EA, EXTRAM		; arrive here with xx00, store it (should be 0x1000)
			ADD		EA, =0x0100		; add 256
			ST		EA, STACK		; store as STACK address (should be 0x1100)
			LD		SP, EA    		; initialize stack pointer
COLD4:		JSR 	TSTRAM1			; check RAM at current pos P2 (should be 0x1000)
			BZ		COLD4			; advance until no longer RAM
									; P2 points to last RAM+2
			LD		A, @-2, P2		; subtract 2 from P2
			LD		EA, P2    		; get last RAM address
			ST		EA, TXTEND		; store at end of text (should be 0x13ff)
			LD		EA, TXTBGN		; load begin of ROM text (0x8000)
			LD		P2, EA    		; put into P2
			JSR 	TSTRAM1			; is there RAM?
			BZ		COLD5			; yes, skip
			JMP		RUN				; no, this could be a ROM program, run it
COLD5:		LD		EA, STACK		; get stack top
			SUB		EA, TXTBGN		; subtract begin of program
			LD		A, S   			; get carry bit
			BP		COLD6			; not set, skip
			LD		EA, STACK		; get stack top
			ST 		EA, TXTBGN		; make it new TXTBGN
COLD6:		LD 		A, RUNMOD  		; get mode
			XOR 	A, ='R'			; is it 'R'?
			BZ		MAINLP			; yes, skip
			JSR		INITAL			; intialize all interpreter variables
			BRA		MAIN			; continue

ENDRAM1:
			LD		A, =0xff		; if P2>=0x8000 then return NonZero(RAM END)
			RET
TSTRAM1:
			LD		EA,P2
			LD		A,E
			SUB		A, =0x80
			BP		ENDRAM1

	; check RAM at loc P2; return 0 if found, nonzero if no RAM
TSTRAM:		LD		A, @1, P2		; get value from RAM, autoincrement
			LD		E, A    		; save old value into E (e.g. 0x55)
			XOR		A, =0xff			; complement value (e.g. 0xAA)
			ST		A, -1, P2    	; store it back (0xAA)
			XOR		A, -1, P2		; read back and compare (should be 0x00)
			XCH		A, E    		; A=old value, E=0x00 (if RAM)
			ST		A, -1, P2    	; store back old value
			XOR		A, -1, P2		; read back and compare (should be 0x00)
			OR		A, E   			; or both tests, should be 0x00 if RAM)
			RET						; return zero, if RAM, nonzero if none

; NEW command
NEW:		JSR		INITAL			; initialize interpreter variables
			LD		A, 0, P2		; get a char from current program position (initially ROMBASE)
			XOR		A, =CR			; is char a CR?
			BZ		MAIN			; yes, skip to program
			CALL	0
			CALL	5    			; APULL
			JMP		COLD1    		; back to cold start

MAIN: 		LD		EA, TXTBGN		; get start of program area
			ST		EA, TXTUNF		; store as end of program
			LD		P2, EA			; point P2 to it
			LD		A, =0x7f    		; set end of program flag
			ST		A, 0, P2    	; at that position

; main interpreter loop
MAINLP:		LD		EA, STACK		; reinitialize stack
			LD		SP, EA    
			LD		EA, EXTRAM		; start of RAM		
			ADD		EA, =52			; offset to AESTK    
			ST		EA, AESTK		; set position of arithmetic stack
			LD		P3, EA			; P3 is arith stack pointer
			JSR		INITBD			; initialize baud rate
			CALL 	8				; CRLF
			LD		A, INPMOD		; mode flag?
			BZ 		MAINL2			; zero, skip
									; no, this is a break CTRL-C
			LD		EA, P2			; current pointion of buffer
			ST		EA, CONTP		; save position (for CONT)
			PLI		P2, =STOPMSG	; STOP message
			CALL	14				; PRTLN
			POP		P2				; restore P2
			JSR		PRTAT			; print AT line#
MAINL1:		CALL	8				; CRLF
MAINL2:		LD 		EA, AESTK		; initialize P3 with AESTK
			LD		P3, EA    
			LD		EA, =0			; initialize constant ZERO
			ST		EA, ZERO		
			ST		A, INPMOD   	; set cmd mode=0
			LD		A, =1			; initialize constant ONE
			ST		EA, ONE			
			JSR		GETLN			; read a line into buffer
			CALL	9				; GETCHR
			CALL 	13				; NUMBER
			DB		0x85  			; not a number, skip to DIRECT
			LD		EA, TXTBGN		; start of program
			SUB		EA, ONE    		; minus 1
			SUB		EA, TXTUNF		; subtract end of program
			LD		A, S    		; get status
			BP		MAINL3   			; overflow? no, skip
			CALL	15				; ERROR
			DB 		1				; 1 (out of mem)
MAINL3:		LD		EA, P2    		; get buffer pointer
			ST		EA, TMPF0		; save it
			JSR		FINDLN			; find line in program
			BNZ		MAINL4			; no match, skip
			PUSH	P2				; save p2 (line begin)
			JSR		TOEOLN			; advance to end of line
			LD		EA, 0, SP		; get line begin (P2)
			LD		P3, EA			; into P3
			LD		EA, P2			; get end of line from TOEOLN
			CALL	10    			; NEGATE
			PUSH	EA				; save -endline
			ADD		EA, ONE			; add one (for CR)
			ADD		EA, TXTUNF		; add end of program area
			ST		EA, TMPFE		; store number of bytes to move
			POP		EA				; restore -endline
			ADD		EA, 0, SP		; subtract from start to get number of bytes to move
			ADD		EA, TXTUNF		; add end of program area
			ST		EA, TXTUNF		; set a new end of program
			JSR		BMOVE			; move area
			POP		P2				; restore start of line
; replace or add line
MAINL4:		LD		EA, P2			; copy into P3
			LD		P3, EA    
			LD		EA, TMPF0		; buffer pointer
			LD		P2, EA			; into P2
			CALL	9				; GETCHR
			XOR		A, =CR			; is it a single line number?
			BZ		MAINL2			; yes, ignore that
			LD		EA, BUFAD		; address of buffer
			LD		P2, EA			; into P2
			CALL	9				; GETCHR
			LD		EA, P2			; save buffer pointer
			ST		EA, TMPF6
			JSR		TOEOLN			; advance to end of line
			LD		EA, P2			; get end of line
			SUB		EA, TMPF6		; subtract to get length of buffer
			ST		EA, TMPFE		; store number of bytes to move
			ADD		EA, TXTUNF		; add temporary end of buffer
			SUB		EA, TXTEND		; store as new end of program
			SUB		EA, ONE			; subtract one
			XCH		A, E			; is result negative?
			BP		OMERR			; out of memory error
			PUSH	P3				; save P3
			LD		EA, TXTUNF		; get tmp area
			LD		P2, EA			; into P2
			LD		EA, P3			; line to insert
			SUB		EA, TXTUNF		; subtract tmp buf
			CALL	10				; NEGATE
			ST		EA, TMPFB		; number of bytes to expand
			OR		A, E			; is result zero?
			PUSH	A    			; save it for later check
			LD		EA, TXTUNF		; tmp buf
			ADD		EA, TMPFE		; add length of line
			ST		EA, TXTUNF		; store
			LD		P3, EA			; into P3
			LD		A, 0, P2		; copy a byte
			ST		A, 0, P3
			POP		A				; restore result from above (sets Z flag)
			BZ		MAINL6			; was zero, skip
MAINL5:		LD		A, @-1, P2		; otherwise copy backwards TMPFB bytes
			ST		A, @-1, P3
			DLD		A, TMPFB		; decrement byte counter
			BNZ		MAINL5
			LD		A, TMPFB+1
			BZ		MAINL6			; exit loop if zero
			DLD		A, TMPFB+1
			BRA		MAINL5			; loop
MAINL6:		POP		P3				; restore target location
			LD		EA, TMPF6		
			LD		P2, EA			; restore source location
			JSR		BMOVE			; move new line into program
MAINL7:		JMP		MAINL2			; done, continue in main loop

; parse a direct command
DIRECT:		LD		A, 0, P2		; get char from buffer
			XOR		A, =CR			; is it a CR?
			BZ		MAINL7			; yes, continue in main loop
			PLI		P3, =CMDTB1		; load first CMD table
			CALL	11				; CMPTOK

; out of memory error
OMERR:		CALL	15				; ERROR
			DB		1				; 1 (out of memory)
;--------------------------------------------------------------------------------------------------

; move TMPFE bytes ascending from @P2 to @P3
BMOVE:		LD		A, @1, P2		; get char from first pos
			ST		A, @1, P3		; store into second
			DLD		A, TMPFE    	; decrement byte counter 16 bit
			BNZ		BMOVE
			LD		A, TMPFE+1
			BZ		BMOVE1   		; exit if zero
			DLD		A, TMPFE+1
			BRA		BMOVE			; loop
BMOVE1:		RET
;--------------------------------------------------------------------------------------------------
; find line in program, 0 = found, 1 = insert before, -1 = not found, line in P2
; line number to find is on AESTK
FINDLN:		LD 		EA, TXTBGN		; get start of program
			LD 		P2, EA    		; into P2
FINDL1:		LD		EA, P2			; get P2
			ST		EA, TMPFB		; save temporary
			CALL	9				; GETCHR
			CALL	13				; NUMBER
			DB 		0x18			; skip if not number to FINDL4
			CALL 	5				; APULL
			SUB 	EA, -2, P3		; subtract number from the one on stack (the line number found)
			XCH		A, E			; is larger?
			BP		FINDL2			; yes skip
			JSR		TOEOLN			; advance to end of line
			BRA		FINDL1			; loop
FINDL2:		OR		A, E
			BZ		FINDL3			; is exactly the same?
			LD		A, =01			; no, return 1
FINDL3:		PUSH	A
			CALL	5				; APULL
			LD		EA, TMPFB		; get start of this line
			LD		P2, EA    		; into P2
			POP		A				; restore result
			RET						; return with 0, if exact match, 1 if insert
FINDL4:		LD		A, =0xff		; return with -1: end of program
			BRA		FINDL3		

;--------------------------------------------------------------------------------------------------
; advance to end of line
TOEOLN:		LD		A, =CR			; search for end of line
			SSM 	P2				; should be within next 256 bytes
			BRA		UCERR			; didn't find one, error 3
			RET						; found one, return with P2 pointing to char after CR

;--------------------------------------------------------------------------------------------------
; set of DIRECT commands
CMDTB1:		DB 		'LIST'
			DB 		0x93			; to LIST
			DB 		'NEW'
			DB 		0x8a			; to NEW2
			DB 		'RUN'
			DB 		0xb5			; to RUN
			DB 		'CONT'
			DB 		0xa7			; to CONT
			DB		0xd2			; default case to EXEC1

;--------------------------------------------------------------------------------------------------
; NEW command
NEW2:		JMP		NEW				; do new command

;--------------------------------------------------------------------------------------------------
UCERR:		CALL 	15				; ERROR
			DB 		3				; 3 (unexpected char)

;--------------------------------------------------------------------------------------------------
; LIST command
LIST:		CALL	13				; NUMBER
			DB		3				; if no number, skip to LIST0
			BRA		LIST1
LIST0:		LD		EA, ZERO		; no number given, start with line 0
			CALL	4				; APUSH put on stack
LIST1:		JSR		FINDLN			; find line in program, or next one
LIST2:		CALL	9 		  		; GETCHR from location found
			PUSH	P2    
			CALL	13				; NUMBER 
			DB		0x0a			; if error, goto LIST3
			CALL	5				; APULL
			POP		P2    
			CALL	14				; PRTLN
			CALL	8				; CRLF
			JSR		CHKBRK			; test break
			BRA		LIST2
LIST3:		POP		P2
MAIN1:		JMP		MAINLP

;--------------------------------------------------------------------------------------------------
CMDTB6:		DB		'THEN'			; then table
			DB		0xad			; to EXEC1
			DB		0xac			; default case to EXEC1

;--------------------------------------------------------------------------------------------------
; CONT command
CONT:		LD		EA, CONTP		; restore program pointer from CONT
			LD		P2, EA
			LD		A, =01			; set program mode
			ST		A, INPMOD
			BRA		ENDCM1

;--------------------------------------------------------------------------------------------------
; RUN command
RUN:		JSR		INITAL			; initialize interpreter variables
			LD		A, =01			; set "running mode"
			ST		A, INPMOD
			LD		EA, TXTBGN		; start at first line
			LD		P2, EA			; in buffer
			BRA		RUN2			; skip
RUN1:		LD		A, INPMOD
			BZ		MAIN1
RUN2:		LD		EA, ZERO		; load 0
			CALL	4				; APUSH

RUN3:		JSR		FINDL1			; find line from current position
			BP		RUN4			; found one
			LD		A, =00			; set 'not running'
			ST		A, INPMOD
			BRA		MAIN1			; back to mainloop
RUN4:		CALL	13				; parse line NUMBER
			DB		 8				; not found: syntax error, goto SNERR1
			CALL	 5				; APULL line number
			ST		EA, CURRNT		; set as current line


EXEC1:		PLI		P3, =CMDTB2		; run loop
			CALL	11				; process commands

SNERR1:		CALL	15				; ERROR
			DB 		4				; 4 (syntax error)

;--------------------------------------------------------------------------------------------------
; handle end of CMD, check for break or interrupts... (call 6)
ENDCMD:		POP		EA				; drop return address
			LD		A, 0xffe7		; flag set?
			BNZ		ENDCM1			; yes, skip
			LD		A, INPMOD		; interactive mode?
			BZ		ENDCM1			; yes skip
			LD		EA, INTVEC		; interrupt pending?
			OR		A, E
			BNZ		ENDCM3			; yes, skip

ENDCM1:		LD		A, =0			
			ST		A, NOINT
			JSR		CHKBRK			; check for break
			CALL	12				; EXPECT
			DB		':'				; colon?
			DB		0x03			; no, to ENDCM2
			BRA		EXEC1			; continue run loop
ENDCM2:		LD		A, @1, P2		; advance to next char
			XOR		A, =CR			; is it end of line?
			BNZ		UCERR			; error unexpected char
			BRA		RUN1			; continue

ENDCM3:		LD		EA, INTVEC		; get pending int vector
			CALL	4				; APUSH
			LD		EA, ZERO		; 
			ST		EA, INTVEC		; clear pending int
			BRA		GOSUB1			; jump into GOSUB (process interrupt)

CMDTB2:		DB		'LET'
			DB 		0xa6			; to LET
			DB		'IF'
			DB		0xf3			; to IFCMD
			DB		'LINK'
			DB		0xf7			; to LINK
			DB		'NEXT'
			DB		0x9c			; to NEXT
			DB		'UNTIL'
			DB		0xdb			; to UNTIL
			DB		'GO'
			DB		0x96			; to GOCMD
			DB		'RETURN'
			DB		0xbd			; to RETURN
			DB		'REM'
			DB		0xcf			; to REMCMD
			DB		0x80			; default case to EXEC2

EXEC2:		PLI		P3, =CMDTB7		; load table 7
			CALL	11    			; CMPTOK

;------------------------------------------------------------------------------
; forward to assignment
LET:		JMP		ASSIGN			; ignore LET and continue with general assigment

;------------------------------------------------------------------------------
; forward to NEXT cmd
NEXT:		JMP		NEXT0			; handle NEXT

;------------------------------------------------------------------------------
; handle GOTO or GOSUB
GOCMD:  	PLI		P3, =CMDTB5  	; check for TO or SUB
			CALL	11

CMDTB5:		DB		'TO'
			DB		0x85			; to GOTO
			DB		'SUB'
			DB		0x8d
			DB		0x80			; default case to GOTO

;------------------------------------------------------------------------------
; GOTO command
GOTO:		CALL	0				; RELEXP
GOTO1:		LD		A, =1			;
			ST		A, INPMOD		; set 'running mode'
			JSR		FINDLN			; find line in buffer
			BZ		RUN4			; skip to line number check
			CALL	15				; error    
			DB		7				; 7 (goto target does not exist)    

;------------------------------------------------------------------------------
; GOSUB command
GOSUB:		CALL	0				; RELEXP 
GOSUB1:		LD		EA, SBRPTR		; get SBR stack pointer
			PUSH	P3				; save P3
			LD		P3, EA			; SBR stack in P3
			LD		EA, DOSTK		; mark do stack pointer
			ST		A, TMPF6		; in temporary
			LD		EA, P3			; get SBR stack ptr
			JSR		CHKSBR			; check for overflow			
			LD		EA, P2			; get buffer pointer
			ST		EA, @2, P3		; 
			LD		EA, P3			; save new SBR pointer
			ST		EA, SBRPTR
			POP		P3				; restore P3
			BRA		GOTO1			; do GOTO

;------------------------------------------------------------------------------
; RETURN command
RETURN:		LD		EA, SBRPTR		; get SBR ptr
			SUB		EA, SBRSTK		; is stack empty?
			BZ		RETERR			; yes error 8
			LD		EA, SBRPTR		; decrement SBR ptr
			SUB		EA, =2
			ST		EA, SBRPTR		; store it back
			LD		P2, EA			; into P2
			LD		EA, 0, P2		; restore buffer pointer
			LD		P2, EA
			CALL	6				; ENDCMD

;------------------------------------------------------------------------------
RETERR:		CALL	15				; ERROR
			DB		8				; 8 (return without gosub)

;------------------------------------------------------------------------------
; forward to UNTIL
UNTIL:		BRA		UNTIL0			; redirect to real code

;------------------------------------------------------------------------------
; REM
REMCMD:		JSR		TOEOLN			; advance to end of line
			LD		A, @-1, P2	; back one char
			CALL	6				; ENDCMD

;------------------------------------------------------------------------------
; IF
IFCMD:		CALL	0				; RELEXP get condition
			CALL	5				; APULL pop it into EA
			OR		A, E			; check for zero
			BZ		REMCMD			; false: advance to end of line
			PLI		P3, =CMDTB6		; process THEN (may be missing)
			CALL	11				; CMPTOK

;------------------------------------------------------------------------------
; LINK
LINK:		CALL	0				; RELEXP get link address
			PLI		P2, =DOLAL6-1	; save P2, put return vector into P2
			CALL	5				; APULL pop link address
			PUSH	P3				; push P3 on stack
			PUSH	P2				; put return vector on stack
			SUB		EA, ONE			; adjust link address
			PUSH	EA				; push on stack
			LD		EA, EXTRAM		; load P2 with base of variables
			LD		P2, EA
			RET						; return to link address
; note: the stack frame is (before RET):
;		P2 = variables
;		Top:	linkaddress-1	(pulled by RET here)
;				returnvector-1	(pulled by RET in called program)
;				saved P3		(restored in returnvector stub)
;				saved P2		(restored in returnvector stub)

;------------------------------------------------------------------------------
CMDTB7:		DB		'FOR'
			DB		0xe4			; to FOR
			DB		'DO'
			DB		0xa7			; to DO
			DB		'ON'
			DB		0x8f			; to ON
			DB		'CLEAR'
			DB		0x85			; to CLEAR
			DB		0x80			; to EXEC3

;------------------------------------------------------------------------------
; handle several commands for direct/program mode
EXEC3:		PLI		P3, =CMDTB8
			CALL	11				; CMPTOK

;------------------------------------------------------------------------------
; CLEAR cmd
CLEAR:		JSR		INITA1			; do warm initialization
			CALL	6				; ENDCMD

;------------------------------------------------------------------------------
; ON cmd
ON:			CALL	0				; RELEXP get expression
			CALL	12				; EXPECT check if comma follows
			DB		','    
			DB		1				; if not, continue next instruction
ON1:		CALL	5				; APULL get expression
			AND		A, =1			; has it bit 0 set?
			BZ		ON2				; no, skip
			ST		A, BRKFLG		; store nonzero in BRKFLG
			CALL	0				; RELEXP get INTA vector expression
			CALL	5				; APULL into EA
			ST		EA, INTAVC		; set as INTA call vector
			CALL	6				; ENDCMD done

; assume here another bit set
ON2:		CALL	0				; RELEXP get INTB vector expression
			CALL	5				; APULL into EA
			ST		EA, INTBVC		; set as INTB call vector
			CALL	6				; ENDCMD done

;------------------------------------------------------------------------------
; DO cmd
DO:			LD		EA, DOPTR		; get DO stack ptr
			PUSH	P3				; 	save P3
			LD		P3, EA			; into P3
			LD		EA, FORSTK		; put end of stack (FORSTK is adjacent)
			ST		A, TMPF6		; into temporary
			LD		EA, P3			; DO stack pointer
			JSR		CHKSBR			; check stack overflow
			LD		EA, P2			; get current program pointer
			ST		EA, @02, P3		; push on DO stack
			LD		EA, P3    		; and save new DO stack ptr
			POP		P3				;   restore P3
DO1:		ST		EA, DOPTR
			CALL	6				; ENDCMD done
;;			RET						; done

;------------------------------------------------------------------------------
	;UNTIL command
UNTIL0:		CALL	0				; RELEXP get condition
			LD		EA, DOPTR		; get DO stack ptr
			SUB		EA, DOSTK		; subtrack stack base
			OR		A,E				; is empty?
			BNZ		UNTIL1			; no, continue
									; otherwise throw error 11
			CALL	15				; ERROR
			DB		0x0b			; 11 (UNTIL without DO)
UNTIL1:		CALL	5				; APULL condition into EA
			OR		A,E				; is false?
			BZ		UNTIL2			; yes, skip
			LD		EA, DOPTR		; no, discard DO loop from stack
			SUB		EA, =0002		; 1 level
			BRA		DO1				; store back DO stack ptr and exit
UNTIL2:		LD		EA, DOPTR		; do loop again
			LD		P2, EA			; get DO stack ptr
			LD		EA, -2, P2		; get last level stored
			LD		P2, EA			; as new program pointer -> redo loop
			CALL	6				; ENDCMD
;;			RET						; done	

;------------------------------------------------------------------------------
; for comparison of FOR keyword STEP
CMDTB9:		DB		'STEP'
			DB		0x96			; to FOR2
			DB		0x98			; to FOR3

; for comparison of FOR keyword TO
CMDT10:		DB		'TO'
			DB		0x8d			; to FOR1
			DB		0xfd			; to SNERR2 (syntax error)

FOR:		JSR		GETVAR			; get a variable address on stack
			DB		0x7a			; none found: goto SNERR2 (syntax error)
			CALL	12				; EXPECT a '='
			DB		'='
			DB		0x77			; none found: goto SNERR2 (syntax error)
			CALL	0				; RELEXP get initial expression
			PLI		P3, =CMDT10		; expect TO keyword (SNERR if not)
			CALL	11				; CMPTOK

FOR1:		CALL	0				; RELEXP get end expression
			PLI		P3, =CMDTB9		; check for STEP keyword, to FOR2 if found, to FOR3 if not
			CALL	11				; CMPTOK

FOR2:		CALL	0				; RELEXP get step expression
			BRA		FOR4			; skip
FOR3:   	LD		EA, ONE			; push 1 as STEP on stack
			ST		EA, @2, P3
FOR4:		LD		EA, FORPTR		; get the FOR stack ptr
			PUSH	P2				;   save current program ptr
			LD		P2, EA			; into P2
			LD		EA, BUFAD		; put end of stack (BUFAD is adjacent)
			ST		A, TMPF6		; into temporary
			LD		EA, P2			; FOR stack ptr
			JSR		CHKSBR			; check stack overflow
			CALL	5				; APULL restore step value
			ST		EA, @2, P2		; save at forstack+0
			CALL	5				; APULL restore end value
			ST		EA, @2, P2		; save at forstack+2
			CALL	5				; APULL restore initial value
			LD		T, EA			; save in T
			CALL	5				; APULL restore variable address
			ST		EA, TMPF6		; store address in temporary
			ST		A, @1, P2		; save low offset of var at forstack+4
			LD		EA, 0, SP		; get current program ptr
			ST		EA, @2, P2		; save at forstack+5
			LD		EA, P2			; save new FOR stack ptr
			ST		EA, FORPTR
			LD		EA, TMPF6		; get variable address
			LD		P2, EA			; into P2
			LD		EA, T			; initial value
			ST		EA, 0, P2		; save in variable
FOR5:		POP		P2				; restore program pointer
			CALL	6				; ENDCMD
; note the FOR stack frame looks like the following:
;		offset 0: DW step value
;		offset 2: DW end value
;		offset 4: DB variable low offset
;		offset 5: DW program pointer of first statement of loop

NXERR:		CALL	15				; ERROR
			DB		10				; 10 (NEXT without FOR)

; NEXT command
NEXT0:		JSR		GETVAR			; get variable address on stack
			DB		0x38			; no var found, goto SNERR2 (syntax error)
			CALL	5				; APULL restore address
			LD		T, EA			; put into T
NEXT1:		LD		EA, FORPTR		; get FOR stack ptr
			SUB		EA, FORSTK		; subtract base
			BZ		NXERR			; is empty? yes, NEXT without FOR error
			LD		EA, FORPTR		; get FOR stack ptr again
			SUB		EA, =0007		; discard current frame
			ST		EA, FORPTR		; save it for the case loop ends
			PUSH	P2				; save program pointer
			LD		P2, EA			; point to base of current FOR frame
			LD		EA, T			; get var address
			SUB		A, 4, P2		; subtract var addr of this frame
			BZ		NEXT2			; is the same?, yes skip (found)
			POP		P2				; restore P2
			BRA		NEXT1			; try another loop - assume jump out of loop
NEXT2:		LD		A, 1, P2		; step value (high byte)
			BP		NEXT3			; is step positive? yes, skip
			JSR		NXADD			; add step and compare with end value
			XOR		A, =0xff		; compare with -1
			BZ		NEXT5			; zero? yes, end of loop not yet reached
			BRA		NEXT4			; skip
NEXT3:		JSR		NXADD			; add step and compare with end value
NEXT4:		BP		FOR5			; end of loop done, continue after NEXT
NEXT5: 		LD		EA, 5, P2		; get start of loop program pointer
			POP		P2				; drop P2
			LD		P2, EA			; set start of loop again
			LD		EA, FORPTR		; get FOR stack ptr
			ADD		EA, =0007		; push loop frame again
			ST		EA, FORPTR		; save new FOR ptr
			CALL	6				; ENDCMD
;;			RET						; done

SNERR2:		CALL	15				; ERROR
			DB		4				; 4 (syntax error)

;------------------------------------------------------------------------------
; add step and compare with end value
NXADD:		LD		EA, EXTRAM		; variable base
			LD		A, 4, P2    	; get variable offset
			PUSH	P3				;   save P3
			LD		P3, EA			; into EA
			LD		EA, 0, P3		; get variable value
			ADD		EA, 0, P2		; add step value
			ST		EA, 0, P3		; store new variable
			POP		P3				;  restore P3
			SUB		EA, 2, P2		; compare with end value
			BZ		NXADD2			; same?
			XCH		A, E			; no, swap: A = high byte
NXADD1:		AND		A, =0x80		; mask out sign bit
			RET						; return
NXADD2:		XCH		A, E			; swap: A = high byte
			BNZ		NXADD1			; not same? get high byte
			LD		A, =0xff		; set A = -1
			RET						; return

;------------------------------------------------------------------------------	
; check for SBR stack overflow
; EA contains current stack pointer, TMPF6 contains limit
CHKSBR:		SUB		A, TMPF6		; subrack limit
			BP		NSERR			; beyond limit?
			RET						; no, exit
									; otherwise nesting too deep error
NSERR:		CALL	15				; ERROR
			DB		9				; 9 (nesting too deep)

;------------------------------------------------------------------------------
SUERR:		CALL	15				; ERROR
			DB		2				; 2 (stmt used improperly)

;------------------------------------------------------------------------------
; INPUT handler
INPUT0:		LD		A, INPMOD		; is in direct mode?
			BZ		SUERR			; yes, this is an error!
			LD		EA, P2			; save current program ptr temporarily
			ST		EA, TMPF2
INPUT1:		JSR		GETVAR			; get variable address on stack
			DB		0x29			; no variable, goto INPUT3 (could be $)
			LD		A, =03			; set mode 3, swap buffers (P2 is input buffer)
			JSR		SWPBUF
			JSR		GETLN			; get line into input buffer
INPUT2:		CALL	0				; RELEXP get expression from input buffer
			CALL	5				; APULL into EA
			LD		T, EA			; save into T
			CALL	5				; APULL get variable address
			PUSH	P3				;   save P3
			LD		P3, EA			; into P3
			LD		EA, T			; obtain expression
			ST		EA, 0, P3		; save into variable
			POP		P3				;   restore P3
			LD		A, =01			; set mode 1, swap buffers (P2 is program ptr)
			JSR		SWPBUF
			CALL	12				; EXPECT a comma
			DB		','
			DB		0x2c			; if not found, exit via INPUT5
			JSR		GETVAR			; get another variable
			DB		0xd6			; if none found, goto SUERR (error 2)
									; does not accept $ any more here
			LD		A, =03			; set mode 3, swap buffers (P2 is input buffer)
			JSR		SWPBUF
			CALL	12				; EXPECT an optional comma in input buffer
			DB		','
			DB		1				; none found, ignore
			BRA		INPUT2			; process the next variable

; process $expr for string input
INPUT3:		CALL	12				; EXPECT a $ here
			DB		'$'
			DB		0xc9			; none found, goto SUERR
			CALL	1				; FACTOR get string buffer address
			LD		A, =03			; set mode 3, swap buffers (P2 is input buffer)
			JSR		SWPBUF
			JSR		GETLN			; get line of input
			CALL	5				; APULL get buffer address
			PUSH	P3				;   save P3
			LD		P3, EA			; into P3
INPUT4:		LD		A, @1, P2		; copy input from buffer into string
			ST		A, @1, P3
			XOR		A, =CR			; until CR seen
			BNZ		INPUT4
			POP		P3				;   restore P3
			LD		A, =01			; set mode 1 again, swap buffers (P2 is program ptr)
			JSR		SWPBUF			
INPUT5:		CALL	6				; ENDCMD done

;------------------------------------------------------------------------------
; save input mode and swap buffers
SWPBUF:		ST		A, INPMOD		; store new input mode
			LD		EA, TMPF0		; swap buffer addresses
			XCH		P2, EA			; TMPF0 normally contains input buffer address
			ST		EA, TMPF0
			RET

;------------------------------------------------------------------------------
; several more commands
CMDTB8:		DB		'DELAY'
			DB		0x9a			; to DELAY
			DB		'INPUT'
			DB		0x8f			; to INPUT
			DB		'PRINT'
			DB		0x8b			; to PRINT
			DB		'PR'
			DB		0x88			; to PRINT
			DB		'STOP'
			DB		0x91			; to STOP
			DB		0x9d			; default to ASSIGN

;------------------------------------------------------------------------------
; INPUT cmd
INPUT:		BRA		INPUT0			; INPUT handler

;------------------------------------------------------------------------------
; PRINT cmd
PRINT:		JMP		PRINT0			; PRINT handler

;------------------------------------------------------------------------------
; DELAY cmd
DELAY:		CALL	0				; RELEXP get delay expression
			CALL	5				; APULL into EA
			LD		T, =0x003f		; multiply with 63
			MPY		EA, T
			LD		EA, T			; into EA
			JSR		DELAYC			; do delay
			CALL	6				; ENDCMD
;;;			RET						; done

;------------------------------------------------------------------------------
; STOP cmd
STOP:		JMP		MAINLP			; directly enter main loop

;------------------------------------------------------------------------------
; left hand side (LHS) operators for assigment
CMDTB4:		DB		'STAT'
			DB		0x89			; to STATLH
			DB		'@'
			DB		0x92			; to ATLH
			DB		'$'
			DB		0xb1			; to DOLALH
			DB		0x9e			; default case to ASSIG1   

;------------------------------------------------------------------------------
; handle assignments
ASSIGN:		PLI		P3, =CMDTB4
			CALL	11				; CMPTOK

;------------------------------------------------------------------------------
; STAT on left hand side
STATLH:		CALL	12 				; EXPECT an equal symbol
			DB		'='				;  
			DB		0x67			; not found, goto SNERR    
			CALL	0				; RELEXP get the right hand side
			CALL	5				; APULL into EA
			LD		S, A			; put into SR (only low byte)  
			LD		A, =1			; suppress potential INT that could
			ST		A, NOINT		; result from changing SA/SB
			CALL	6				; ENDCMD

;------------------------------------------------------------------------------
; @ on left hand side (POKE)
ATLH:		CALL	1				; FACTOR get non-boolean expression
			CALL	12				; EXPECT an equal symbol
			DB		'='
			DB		0x5b			; not found, goto SNERR (syntax error)
			CALL	0				; RELEXP get right hand side
			CALL	5				; APULL into EA
			LD		T, EA			; into T
			CALL	5				; APULL get target address
			PUSH	P3				;   save P3
			LD		P3, EA			; into P3
			LD		EA, T			; RHS into EA
			ST		A, 0, P3		; store low byte at address
			POP		P3
			CALL	6				; ENDCMD
;;;			RET

;------------------------------------------------------------------------------
; default case for assign (VAR = expr)
ASSIG1:		JSR		GETVAR			; get a variable
			DB		0x4c			; if not var, goto DOLAL4 (assume $xxxx)
			CALL	12				; EXPECT an equal symbol
			DB		'='
			DB		0x49			; not found, go to SNERR
			CALL	0				; RELEXP get right hand side
			CALL	5				; APULL into EA
			LD		T, EA			; into T
			CALL	5				; APULL get variable address
			PUSH	P3				;   save P3
			LD		P3, EA			; into P3
			LD		EA, T			; get RHS
			ST		EA, 0, P3		; store result into variable
			POP		P3				;   restore P3
			CALL	6				; ENDCMD done

;------------------------------------------------------------------------------
; $ on left hand side
DOLALH:		CALL	1				; FACTOR get target address
			CALL	12				; EXPECT an equal symbol
			DB		'='
			DB		0x3a			; if not found, goto SNERR
			LD		A, 0, P2		; get next char from program
			XOR		A, =0x22		; is double quote?
			BNZ		DOLAL3			; not a constant string, may be string assign
			LD		A, @1, P2		; skip over quote
			CALL	5				; APULL get target address
			PUSH	P3				;   save P3
			LD		P3, EA			; into P3
DOLAL1:		LD		A, @1, P2		; get string char from program buffer
			XOR		A, =0x22		; is double quote?
			BZ		DOLAL2			; yes, end of string, skip
			XOR		A, =0x2f		; is CR?
			BZ		EQERR			; yes, ending quote missing error 
			XOR		A, =0x0d		; convert back to original char
			ST		A, @1, P3		; store into target buffer
			BRA		DOLAL1			; loop

DOLAL2:		LD		A, =CR			; terminate target string
			ST		A, 0, P3
			POP		P3				;   restore P3
			CALL	9				; GETCHR get next char from program
			CALL	6				; ENDCMD done

; assume string assign
DOLAL3:		CALL	12				; EXPECT a $
			DB		'$'
			DB		0x15			; not found, goto SNERR
			CALL	1				; FACTOR get source address
			CALL	5				; APULL into EA
			PUSH	P2				;   save P2
			LD		P2, EA			; into P2

DOLAL4:		CALL	5				; APULL get target address
			PUSH	P3				;   save P3
			LD		P3, EA			; into P3
DOLAL5:		LD		A, @1, P2		; move byte from source to targer
			ST		A, @1, P3
			XOR		A, =CR			; compare with CR
			BNZ		DOLAL5			; not yet, continue copying

;------------------------------------------------------------------------------
; This location is also the return point form LINK
DOLAL6:		POP		P3				;   restore P3
			POP		P2				;   restore P2
			CALL	6				; ENDCMD

;------------------------------------------------------------------------------
EQERR:		CALL	15				; ERROR
			DB		6				; 6 (ending quote missing)

;------------------------------------------------------------------------------
SNERR:		CALL	15				; ERROR    
			DB		4				; 4 (syntax error)

;------------------------------------------------------------------------------
; PRINT handler
PRINT0:		LD		A, 0, P2		; get char from program
			XOR		A, =0x22		; is double quote?
			BNZ		PRINT2			; no, not a string print

; print a string constant
			LD		A, @1, P2		; skip over quote
PRINT1:		LD		A, @1, P2		; get next char
			XOR		A, =0x22		; is double quote?
			BZ		PRINT4			; yes, done with print
			XOR		A, =0x2f		; is CR?
			BZ		EQERR			; yes, error missing end quote
			XOR		A, =0x0d		; convert back to original char
			CALL	7				; PUTC emit 
			BRA		PRINT1			; loop

; print a string variable
PRINT2:		CALL	12				; EXPECT a $
			DB		'$'
			DB		0x09			; if not found, goto PRINT3 (could be expression)
			CALL	1				; FACTOR get source address
			CALL	5				; APULL into EA
			PUSH	P2				;   save P2
			LD		P2, EA			; into P2
			CALL	14				; PRTLN print the string
			POP		P2				;   restore P2
			BRA		PRINT4			; continue in PRINT

; print an expression
PRINT3:		CALL	0				; RELEXP get expression
			JSR		PRNUM			; print numeric

; print next field
PRINT4:		CALL	9				; GETCHR get next character
			CALL	12				; EXPECT a comma
			DB		','
			DB		3				; if not found, goto PRINT5 (check for semicolon)
			BRA		PRINT0			; process next field

PRINT5:		CALL	12				; EXPECT a semicolon
			DB		';'
			DB		2				; if not found, goto PRINT6 do a CRLF
			CALL	6				; ENDCMD semicolon: terminate without CRLF
PRINT6:		CALL	8				; CRLF do a new line
			CALL	6				; ENDCMD done

;------------------------------------------------------------------------------
; pop number off stack and print it
PRNUM:		LD 		EA, -2, P3		; get last number on stack
			XCH		A, E    		; check high byte
			BP		PRNUM1			; is positive? yes, skip
			XCH		A, E    		; restore original number
			CALL	10    			; NEGATE number
			ST		EA, -2, P3		; store as positive number on stack
			LD		A, ='-'			; load minus symbol
			CALL	7				; PUTC emit it
			BRA		PRNUM2			; skip
PRNUM1:		LD		A, =SPACE		; emit a blank
			CALL	7    			; PUTC
PRNUM2:		LD		A, =0			; clear counter for characters
			ST		A, TMPFE		; 
			CALL	5				; APULL get number  (is positive)
  			PLI		P3, =TMPF6		; save P3 and load TMPF6
PRNUM3:		LD		T, =10			; load divisor 10    
			ST		EA, TMPFC		; store dividend temporary
			DIV		EA, T			; divide by 10
			PUSH	EA				; save remainder
			LD		T, =10			; multiplier 10
			MPY		EA, T			; multiply, is now (VAL DIV 10) * 10, i.e. last digit stripped
			LD		EA, T			; get this
			CALL	10    			; NEGATE
			ADD		EA, TMPFC		; extract least digit
			ST		A, @1, P3		; push onto stack
			ILD		A, TMPFE		; increment char counter
			POP		EA    			; restore remainder
			BNZ		PRNUM3			; unless zero, loop for another digit
			XCH		A, E			; also high byte
			BZ		PRNUM4			; if zero, go emitting
			XCH		A, E    		; restore remainder
			BRA		PRNUM3			; loop for another digit
PRNUM4:  	LD		A, @-1, P3		; get last pushed digit first
			ADD		A, ='0'			; make it ASCII digit    
			CALL	7				; PUTC
			DLD		A, TMPFE		; decrement count	
			BNZ		PRNUM4    		; loop until all digits done
			LD		A, =SPACE		; emit space
			CALL	7				; PUTC
			POP		P3				; restore arithmetic stack pointer
			RET
;------------------------------------------------------------------------------
; print string pointed to by P2, until char has bit 7 is set or is CR
PRTLN:		LD		A, @1, P2		; get next char from buffer
			XOR		A, =CR			; is CR?
			BZ		PRTLN1			; yes exit
			XOR 	A, =CR			; make original char again
			CALL 	7				; PUTC emit it
			BP		PRTLN			; if positive, loop
PRTLN1		RET						; exit
;------------------------------------------------------------------------------
; get next char from buffer
GETNXC:		LD		A, @1, P2		; advance P2
;------------------------------------------------------------------------------
; get character from buffer pointed to by P2, into A (call 9)
GETCHR:		LD		A, 0, P2		; char from buffer
			AND		A, =0x7f		; mask 7 bits
			LD		E, A			; into E
			XOR		A, =SPACE		; is space?    
			BZ		GETNXC			; skip over it, loop to next    
			XOR		A, =0x2a		; is LF (SPACE xor 0x0a)?
			BZ		GETNXC			; yes, skip over it, loop to next    
			LD		A, E			; back into A
			BZ		GETNXC			; if zero, loop over it
			RET
;------------------------------------------------------------------------------
; EXPECT char following in text, if not found (call 12)
; call it as:
;			CALL 12
;			DB	'chartomatch'
;			DB	offset to jump to if no match
EXPECT:		POP		EA				; get return addr
			ADD		EA, ONE    		; advance to following byte
			PUSH	EA				; put return on stack again (continue here if matched)
			PUSH	P3				; save P3
			LD		P3, EA			; point to char to match
			LD		A, 0, P3		; load char to match
			XOR		A, 0, P2		; compare with buffer
			POP		P3				; restore P3
			BZ		GETVA3			; char matched, advance to next and exit
			BRA		GETVA1			; otherweise error

;------------------------------------------------------------------------------
; expect variable, and push it
; call as:
;			JSR GETVAR
;			DB	offset to jump to if not variable
GETVAR:		LD		A, 0, P2		; get character from buffer
			LD		E, A			; save in E
			SUB		A, ='Z'+1		; subtract 'Z'+1
			BP		GETVA1			; is >=, skip
			LD		A, E			; restore char
			SUB		A, ='A'			; subtract 'A'
			BP		GETVA2			; is an alpha char, skip

; go to the offset that return address points to
GETVA1:		POP		EA				; pop return address (pointing to error code)
			ST		EA, TMPF6		; save in temporary
			PUSH	P3				; save P3
			LD		P3, EA			; get return addr in P3
			LD		EA, ZERO		; clear EA
			LD		A, 1, P3		; get next location offset
			ADD		EA, TMPF6		; add return addr
			POP		P3				; restore P3
			LD		PC, EA			; go to that offset (no variable found)

GETVA2:		SL		A				; is variable, make offset into var table
			XCH		A, E			; put into E
			LD		A, =0			; clear A
			XCH		A, E			; make 16 bit unsigned
			ADD		EA, EXTRAM		; add ext ram base
			CALL	4				; APUSH

GETVA3:		LD		A, @1, P2		; advance to next buffer pos
GETVA4:		CALL	9				; GETCHR
			POP		EA				; return addr
			ADD		EA, ONE			; skip over error jump
			LD		PC, EA			; continue in interpreter
;------------------------------------------------------------------------------
; NUMBER	expect a number and push it (call 13)
; call as:
;			CALL 13
;			DB offset to jump to if no number
NUMBER:		LD		A, 0, P2		; get char from buffer
			BND		GETVA1, PC		; if not digit, skip to next loc
			LD		EA, ZERO		; load 0
			ST		EA, TMPF6		; store temporary
NUMBE1:		LD		T, EA			; store into T
NUMBE11:	LD		A, @1, P2		; get digit and advance
			BND		NUMBE4, PC		; skip if no more digits
			ST		A, TMPF6		; store digit    
			LD		EA, =10			; factor 10
			MPY		EA, T			; multiply
			OR		A, E			; check overflow?
			BNZ		NUMBE3			; yes, skip
			LD		EA, T			; move result to EA
			ADD		EA, TMPF6		; add digit
			LD		T, EA			; store intermediate result
			LD		A, E			; high byte
			BP		NUMBE2			; skip if no overflow (became negative)
			BRA		NUMBE3			; not okay
NUMBE2:		LD		A, S			; get status    
			AND		A, =0xc0		; mask out OV, CY
			BZ		NUMBE11			; loop unless error
NUMBE3:		CALL	15				; ERROR
			DB		5				; 5 (value format)
NUMBE4:		LD		A, @-1, P2	; point back to non digit
			LD		EA, T			; get accumulated value    
			CALL	4				; APUSH
			BRA		GETVA4			; advance to next position and skip over error offset
;------------------------------------------------------------------------------
	; intialize interpreter variables
INITAL:		LD		EA, =0x0000		; constant 0
			ST		EA, CURRNT		; reset current line number
INITA1:		LD		EA, EXTRAM		; get start addr of external RAM
			ADD		EA, =52			; add offset to next field (26 variables)
			ST		EA, AESTK 		; store start of arithmetic stack
			ADD		EA, =26			; add offset to next field
			ST		EA, SBRSTK		; store start of GOSUB stack
			ST		EA, SBRPTR		; store pointer to GOSUB level
			ADD		EA, =16			; add offset to next field
			ST		EA, DOSTK		; store start of DO stack
			ST		EA, DOPTR		; store pointer to DO level
			ADD		EA, =16			; add offset to next field
			ST		EA, FORSTK		; store start of FOR stack
			ST		EA, FORPTR		; store pointer to FOR level
			ADD		EA, =28			; add offset to next field
			ST		EA, BUFAD		; store pointer to line buffer
			JSR		INITBD			; initialize baud rate
									; BUG! ZERO is not yet initialized on first call!
			LD		A, =52			; size of variable table in bytes
			ST		A, TMPF6		; store it
			LD		EA, EXTRAM		; load RAM BASE into P3
			LD		P3, EA
			LD		EA, =0000		; initialize constant zero
			ST		EA, ZERO
			ST		EA, INTVEC		; clear vector for current interrupt
			ST		EA, INTAVC		; clear vector for Interrupt A
			ST		EA, INTBVC		; clear vector for Interrupt B
			ST		EA, MULOV
			ST		A, BRKFLG		; enable breaks
INITA2:		LD		A, =00			; clear A
			ST		A, @1, P3		; clear variable area
			DLD		A, TMPF6		; decrement counter
			BNZ		INITA2			; until done
			LD		A, =01			; low byte = 01, EA now 0001
			ST		EA, ONE			; store constant 1
			LD		EA, AESTK		; load AESTK into P3
			LD		P3, EA 
			LD		A, ='R'			; store 'R'
			ST		A, RUNMOD
			RET						; exit

;------------------------------------------------------------------------------
; CMPTOK (CALL 11) compare current position with token from list in P3
; table is built this way:
;			DB		'token1'
;			DB		jmp displacement OR 0x80
;			DB		'token2'
;			DB		jmp displacement OR 0x80
;			DB		jmp target if not found OR 0x80
CMPTOK:		POP		EA				; drop return address
CMPTO1:		PUSH	P2				; save buffer pointer position
			LD		A, @1, P3		; get byte from table
			BP		CMPTO4			; if positive, belongs to token to match
									; negative: matched a complete token
			BRA		CMPTO3			; value is location offset to jump to
									; note that the last char in table is negative:
									; the default location always reached if no token matches
CMPTO2:		LD		A, @1, P3		; next char of token from table
			BP		CMPTO4			; is end of token? yes, found one
			CALL	9				; GETCHR, read char from buffer
									; P2 now points to char after recognized token
CMPTO3:		POP		EA				; drop old P2 (start of token)
			LD		EA, ZERO		; preload a zero
			LD		A, @-1, P3		; get the location offset
			AND		A, =0x7f		; discard high bit
			ST		EA, TMPF6    	; store temporary
			LD		EA, P3			; get pointer postion
			ADD		EA, TMPF6    	; add offset
			POP		P3				; restore P3
			LD		PC, EA			; go to location
CMPTO4:		XOR		A, @1, P2		; compare token char with buffer
			AND		A, =0x7f		; only select 7 bits
			BZ		CMPTO2			; matches, loop
			POP		P2				; does not match, reload buffer pointer
CMPTO5:		LD		A, @1, P3		; get char from table, advance until end of token
			BP		CMPTO5    		; loop as long token char
			BRA		CMPTO1			; retry next token from table

;------------------------------------------------------------------------------
; get relational expression (call 0)
; term {<|<=|=|<>|>|>=} term
;
; note the precedence seems to be warped:
; I'd expect something like 
;	X>5 AND X<10 to match an X between 5 and 10,
; but TERM binds the AND operator stronger
; thus it is interpreted as
;   X > (5 AND X) < 10
; which results in an error 3
RELEXP:		JSR 	TERM			; get first operand
			PLI		P3, =OPTBL1		; list of comparison operators
			CALL	11				; CMPTOK
OPTBL1:		DB		'='
			DB		0x8e			; to RELEQ
			DB		'<='
			DB		0x90			; to RELLE
			DB		'<>'
			DB		0x92			; to RELNE
			DB		'<'
			DB		0x95			; to RELLT
			DB		'>='
			DB		0x97    		; to RELGE
			DB		'>'
			DB		0x9a			; to RELGT
			DB		0xa6			; default case to RELEX3

RELEQ:		CALL	3				; COMPAR
			AND		A, =0x02		; is equal?
			BRA		RELEX1
RELLE:		CALL	3				; COMPAR
			AND		A, =0x82		; is less or equal?
			BRA		RELEX1
RELNE:		CALL	3				; COMPAR
			AND		A, =0x81		; is less or greater?
			BRA		RELEX1
RELLT:		CALL	3				; COMPAR
			AND		A, =0x80		; is less?
			BRA		RELEX1
RELGE:		CALL	3				; COMPAR
			AND		A, =0x03		; is greater or equal?
			BRA		RELEX1
RELGT:		CALL	3				; COMPAR
			AND		A, =0x01		; is greater?
RELEX1:		BZ		RELEX2			; condition not matched
			LD		EA, =0xffff		; return -1 (condition matched)
			CALL	4				; APUSH
			RET
RELEX2:		LD		EA, ZERO		; return 0 (condition not matched)
			CALL	4				; APUSH
RELEX3:		RET

;------------------------------------------------------------------------------
; COMPAR	(call 3)
; get a second operand and compare it to the first one on STACK
COMPAR:		JSR		TERM			; get second operand
			CALL	2				; SAVOP
			SUB		EA, TMPF6		; compute 1stOP - 2ndOP
			XCH		A, E			; highbyte
			BP		COMPA1			; positive, i.e. 1st >= 2nd ?
			LD		A, =0x80		; no, set bit 7 (less)
			RET
COMPA1:		OR		A, E			; even zero, i.e. 1st = 2nd ?
			BZ		COMPA2			; yes
			LD		A, =0x01		; no, set bit 0 (greater)
			RET
COMPA2: 	LD		A, =0x02		; set bit 1 (equal)
			RET

;------------------------------------------------------------------------------
; evaluate a TERM:   {+|-} factor {+|-} factor
TERM:		CALL	12				; EXPECT an optional minus symbol
			DB		'-'				; 
			DB		9				; if not found, skip to TERM2
			JSR		MDTERM			; get first mul/div term
			CALL	5				; APULL into EA
			CALL	10				; NEGATE negate
TERM1:		CALL	4				; APUSH again on stack
			BRA		TERM4			; continue
TERM2:		CALL	12				; EXPECT an optional plus symbol
			DB		'+'				;
			DB		1				; if not found, continue at TERM3
TERM3:		JSR		MDTERM			; get a mul/div term
TERM4:		PLI		P3, =CMDT11		; load add/sub/or operator table
			CALL	11				; CMPTOK
CMDT11:
			DB		'+'
			DB		0x86			; to TERM5
			DB		'-'
			DB		0x8c			; to TERM6
			DB		'OR'
			DB		0x91			; to TERM7
			DB		0xc5			; default to FACTOR1 (RET)
; process MDTERM + MDTERM
TERM5:		JSR		MDTERM			; get second mul/div term
			CALL	2				; SAVOP
			ADD		EA, TMPF6		; compute sum
			BRA		TERM1			; loop for further term of this precedence
; process MDTERM - MDTERM
TERM6:		JSR		MDTERM			; get second mul/div term
			CALL	2				; SAVOP
			SUB		EA, TMPF6		; compute difference
			BRA		TERM1			; loop for further term of this precedence
; process MDTERM OR MDTERM
TERM7:		JSR		MDTERM			; get second operand
			CALL	2				; SAVOP
			OR		A, TMPF6		; do byte by byte OR
			XCH		A, E
			OR		A, TMPF6+1
			XCH		A, E
			BRA		TERM1			; loop for further term of this precedence

;------------------------------------------------------------------------------
; evaluate multiplicative term		factor {*|/} factor
MDTERM:		CALL	1				; FACTOR get first factor
MDTER0:		PLI		P3, =CMDT13		; load table of mul/div/and operators
			CALL	11				; CMPTOK
CMDT13:		DB		'*'
			DB		0x87			; to MDTER1
			DB		'/'
			DB		0x8d			; to MDTER3
			DB		'AND'
			DB		0x90			; to MDTER4
			DB		0x9b			; default to FACTO1 (return)

; process	FACTOR * FACTOR
MDTER1:		CALL	1				; FACTOR get 2nd operand
			CALL	2				; SAVOP
			JSR		MULTOP			; multiply EA * TMPF6
MDTER2:		CALL	4				; APUSH push result on stack
			BRA		MDTER0			; loop for further multiplicative term
; process FACTOR / FACTOR (handle division by zero in subroutine)
MDTER3:		CALL	1				; FACTOR get 2nd operand
			CALL	2				; SAVOP
			JSR		DIVOP			; divide EA / TMPF6
			BRA		MDTER2			; loop for further multiplicative term
; process FACTOR AND FACTOR
MDTER4:		CALL	1				; FACTOR get 2nd operand
			CALL	2				; SAVOP
			AND		A, TMPF6		; do byte by byte AND
			XCH		A, E
			AND		A, TMPF6+1
			XCH		A, E
			BRA		MDTER2			; loop for further multiplicative term

;------------------------------------------------------------------------------
; FACTOR	(call 1) get a factor: number, var, function, (RELEXP)
FACTOR:		CALL	13				; NUMBER get number in sequence
			DB		2				; if not found continue at FACTO2
FACTO1:		RET						; has numeric operand on stack, done

FACTO2:		PLI		P3, =CMDT12		; load table of standard functions
			CALL	11				; CMPTOK
CMDT12:
			DB		'('				; left parenthesis (subexpression)
			DB		0xb2			; to LPAREN
			DB		'@'				; right hand side @
			DB		0xb7			; to ATRH
			DB		'#'				; hex operator
			DB		0xe5			; to HASHFN
			DB		'NOT'			; NOT operator
			DB		0xb7			; to NOTFN
			DB		'STAT'			; right hand side STAT
			DB		0xbc			; to STATRH
			DB		'TOP'			; right hand side TOP
			DB		0xbb			; to TOPFN
			DB		'INC'			; INC(X) function
			DB		0xbd			; to INCFN
			DB		'DEC'			; DEC(X) function
			DB		0xc2			; to DECFN
			DB		'MOD'			; MOD(X,Y) function
			DB		0xce			; to MODFN
			DB		'RND'			; RND(X,Y) function
			DB		0xe5			; to RNDFN
			DB		0x80			; default to FACTO3 (variable)
FACTO3:		JSR		GETVAR
			DB		0x12			; if not var, goto SNERR3
			JSR		PEEK
			CALL	4				; APUSH
			RET

;------------------------------------------------------------------------------
; peek word at address on stack
PEEK:		CALL	5				; APULL
			PUSH	P3
			LD		P3, EA
			LD		EA, 0, P3
			POP		P3
			RET

;------------------------------------------------------------------------------
; handle parenthesized expression '(' expr ')'
LPAREN:		CALL	0				; RELEXP get expression
			CALL	12				; EXPECT a closing parenthesis
			DB		')'
			DB		0x02			; if not found, goto SNERR3
			RET

;------------------------------------------------------------------------------
SNERR3:		CALL	15				; ERROR
			DB		4				; 4 (syntax error)

;------------------------------------------------------------------------------
; @ operator
ATRH:		CALL	1				; FACTOR get the address to peek
			JSR		PEEK			; read memory
			BRA		DECFN2			; make 16 bit result on stack

;------------------------------------------------------------------------------
; NOT operator
NOTFN:		CALL	1				; FACTOR get argument
			CALL	5				; APULL into EA
			XOR		A, =0xff		; do byte by byte complement
			XCH		A, E
			XOR		A, =0xff
			XCH		A, E
			CALL	4				; APUSH result on stack
			RET

;------------------------------------------------------------------------------
; STAT function
STATRH:		LD		A, S			; get the current status reg
			BRA		DECFN2			; make 16 bit result on stack

;------------------------------------------------------------------------------
; TOP function
TOPFN:		LD		EA, TXTUNF		; get current top of program area
			ADD		EA, ONE			; add 1 to return next free location
			CALL	4				; APUSH	push on stack
			RET

;------------------------------------------------------------------------------
; INC function
INCFN:		JSR		ARGONE			; get a single function arg into EA
			PUSH	P2				;   save P2
			LD		P2, EA			; put as address into P2
			ILD		A, 0, P2		; increment this cell
			BRA		DECFN1			; return the new result as 16 bit

;------------------------------------------------------------------------------
; DEC function
DECFN:		JSR		ARGONE			; get a single function arg into EA
			PUSH	P2				;   save P2
			LD		P2, EA			; put as address into P2
			DLD		A, 0, P2		; decrement this cell
DECFN1:		POP		P2				;   restore old P2
DECFN2:		XCH		A, E			; save result
			LD		A, =0x00		; make zero high byte
			XCH		A, E			; restore result as low byte
			CALL	4				; APUSH 16 bit result on stack
			RET

;------------------------------------------------------------------------------
; jump to # operator
HASHFN:		BRA		HASHF0			; forward to HEX number interpreter

;------------------------------------------------------------------------------
; MOD function
MODFN:		JSR		ARGTWO			; get two arguments
			CALL	2				; SAVOP: 1st arg=EA, 2nd=TMPF6
MODFN1:		LD		T, EA			; T = 1st arg
			LD		EA, TMPF6		; EA = 2nd arg
			ST		EA, TMPFE		; save in temp
			LD		EA, T			; save 1nd arg in TMPFC
			ST		EA, TMPFC
			JSR		DIVOP			; divide EA / TMPF6
			ST		EA, TMPF6		; quotient into TMPF6
			LD		EA, TMPFE		; multiply with 2nd arg
			JSR		MULTOP			; i.e. EA div F6 * F6
			CALL	10				; NEGATE, i.e. -(EA div F6 * F6)
			ADD		EA, TMPFC		; subtract from 1st: EA - (EA div F6 * F6)
			CALL	4				; APUSH on stack
			RET

;------------------------------------------------------------------------------
; RND function
RNDFN:		JSR		ARGTWO			; get two arguments on stack
			LD		T, RNDNUM		; get random number
			LD		EA, =0x0485		; multiply with 1157
			MPY		EA, T
			LD		EA, T			; use only low 16 bits
			ADD		EA, =0x3619		; add 13849
			ST		EA, RNDNUM		; discard overflow and save as new random value
			CALL	5				; APULL second arg
			ADD		EA, ONE			; add one
			SUB		EA, -2, P3		; subtract 1st arg
			ST		EA, TMPF6		; save as TMPF6
			LD		EA, RNDNUM		; get random value
			XCH		A, E			; make random number positive
			AND		A, =0x7f
			XCH		A, E
			JSR		MODFN1			; MOD(random, (2nd-1st+1))
			CALL	5				; APULL get result
			ADD		EA, -2, P3		; add 1st arg
			ST		EA, -2, P3		; store inplace on stack
			RET

;------------------------------------------------------------------------------
; get a single function argument
ARGONE:		CALL	12				; EXPECT opening paren
			DB		'('
			DB		0x13			; if not found, goto SNERR4
			CALL	0				; RELEXP expression
			CALL	12				; EXPECT closing paren
			DB		')'
			DB		0x0f			; if not found, goto SNERR4
			CALL	5				; APULL argument into EA
			RET

;------------------------------------------------------------------------------
; get a double function arg
ARGTWO:		CALL	12				; EXPECT opening paren
			DB		'('
			DB		0x0a			; if not found goto SNERR4
			CALL	0				; RELEXP get first arg on stack
			CALL	12				; EXPECT a comma
			DB		','
			DB		0x06			; if not found, goto SNERR4
			CALL	0				; RELEXP get 2nd arg on stack
			CALL	12				; EXPECT closing paren
			DB		')'
			DB		0x02			; if not found, goto SNERR4
			RET						; leaves 2 args on stack

SNERR4:		CALL	15				; ERROR
			DB		4				; 4 (syntax error)

;------------------------------------------------------------------------------
; # operator
; handle hexadecimal constants
HASHF0:		LD		EA, ZERO		; initialize temporary
			ST		EA, TMPF6
			LD		T, EA			; also clear T (collects value)
			LD		A, @1, P2		; get first digit
			BND		HASHF1, PC		; if not digit, skip
			BRA		HASHF5			; handle decimal digit (0..9)
HASHF1:		JSR		CVTHEX			; may be 'A'..'F', convert to 0..5
			BP		HASHF4			; if negative, was no hex letter
			CALL	15				; ERROR
			DB		5				; 5 (value error)

HASHF2:		LD		A, @1, P2		; get next char from number
			BND		HASHF3, PC		; if not digit, skip
			BRA		HASHF5			; insert next digit
HASHF3:		JSR		CVTHEX			; may by 'A'..'F', convert to 0..5
			BP		HASHF4			; if a letter, insert it
			LD		EA, T			; done with hex number, put value into EA
			CALL	4				; APUSH on stack
			LD		A, @-1, P2		; re-get the last non-hex char
			CALL	9				; GETCHR
			RET						; done
HASHF4:		ADD		A, =0x0a		; cvt hex 'letter' into range 10..15
HASHF5:		ST		A, TMPF6		; store digit temporary (0..15)
			LD		EA, T			; shift 4 bit left
			SL		EA
			SL		EA
			SL		EA
			SL		EA
			ADD		EA, TMPF6		; add digit
			LD		T, EA			; put back into T
			BRA		HASHF2			; loop

;------------------------------------------------------------------------------
; convert an ASCII hex digit to 0x00...0x05
CVTHEX:		SUB		A, =0x47		; subtract 'G'
			BP		CVTHE1			; is >= 'G', yes, return -1
			ADD		A, =0x06		; adjust into range 0..5 if 'A'..'F'
			RET						; still negative, if < 'A'
CVTHE1:		LD		A, =0xff		; return negative result
			RET

;------------------------------------------------------------------------------
; Multiply EA * TMPF6 -> EA
MULTOP:		JSR		GETSGN			; make operands positive, and save result sign in FB
			LD		T, TMPF6		; compute EA * F6
			MPY		EA, T
			ST		EA, MULOV		; save higher result as overflow
MULTO1:		LD		A, TMPFB		; get resulting sign
			BP		NEGAT1			; if positive, return result unchanged
			LD		EA, T    		; otherwise put result in EA
									; and fall through into NEGATE

;--------------------------------------------------------------------------------------------------
; negate number in EA (call 10)
NEGATE:		XOR		A, =0xff		; 1's complement low byte
			XCH		A, E			; swap
			XOR		A, =0xff		; 1's complement high byte
			XCH		A, E    		; swap back
			ADD		EA, ONE			; add ONE (2's complement)
			RET

NEGAT1:		LD		EA, T			; return positive result
			RET

;------------------------------------------------------------------------------
; divide EA / TMPF6 -> EA
DIVOP:		JSR		GETSGN			; make operands positive, save result sign in FB
			LD		T, EA			; 1st arg in T
			LD		EA, TMPF6		; check 2nd arg
			OR		A, E			; is it zero?
			BZ		DV0ERR			; yes, division by zero error
			LD		EA, T			; EA = 1st arg
			LD		T, TMPF6		; T = 2nd arg
			DIV		EA, T			; divide
			LD		T, EA			; store quotient into T
			BRA		MULTO1			; adjust result sign

DV0ERR:		CALL	15				; ERROR    
			DB		0x0c			; 12 (div by zero)

;------------------------------------------------------------------------------
; make operands of Mul/Div positive, and store result sign in TMPFB
GETSGN:		LD		T, EA			; 1st arg into T
			LD		A, TMPF6+1		; get sign of 2nd arg
			ST		A, TMPFB		; store in FB
			BP		GETSG1			; was positive, skip
			LD		EA, TMPF6		; negate 2nd arg
			CALL	10				; NEGATE
			ST		EA, TMPF6		; store it back
GETSG1:		LD		EA, T			; get 1st arg
			LD		A, E			; get sign
			XOR		A, TMPFB		; exor with sign of 2nd
			ST		A, TMPFB		; save as resulting sign
			LD		EA, T			; get 1st arg
			XCH		A, E			; get sign
			BP		GETSG2			; was positive, restore and exit
			XCH		A, E			; otherwise negate 1nd arg 
			CALL	10				; NEGATE
			RET			
GETSG2:		XCH		A, E			; return 1st arg in EA
			RET

;----------------------------------------------------------------------------------------------
; push a value in EA onto AESTK, pointed to by P3
APUSH:		PUSH	EA				; save value
			LD		EA, P3			; get P3 value
			SUB		EA, SBRSTK		; subtract end of AESTK (= start of SBRSTK)
			XCH		A, E			; get high byte
			BP		APUSH1			; negative?, yes error
			POP		EA				; restore value
			ST		EA, @2, P3		; store in stack, pointed to by P3, autoincrement
			RET
APUSH1:		CALL 	15				; error 9 (stack overflow)
			DB		9				; error code

;----------------------------------------------------------------------------------------------
; SAVOP		(call 2) pull last op and save into TMPF6, then pull 2nd last into EA
SAVOP:		CALL	5				; APULL
			ST 		EA, TMPF6		; save last value

;--------------------------------------------------------------------------------------------------
; pull a value off AESTK pointed to by P3, return in EA (call 5)
APULL:		LD		EA, @-2, P3		; get value from stack, autodecrement
			RET						; return

;--------------------------------------------------------------------------------------------------
; get a line into BUFAD, return P2 = BUFAD
GETLN:		LD		EA, BUFAD		; set P2 = BUFAD
			LD		P2, EA			; 
			LD		A, =0			; clear BUFCNT
			ST		A, TMPFE
			LD		A, INPMOD    	; input mode
			BZ		GETLN1			; if zero, do '>' prompt
			LD		A, =QUEST		; load '?'
			CALL 	7				; PUTC
			LD		A, =SPACE		; load space
			BRA		GETLN2			; continue
GETLN1:		LD		A, =GTR			; load '>'
GETLN2:		CALL 	7				; PUTC
GETCH:		JSR		GECO			; get char with echo in A
			BZ		GETCH			; if zero, ignore
			LD		E, A			; save char into E
			XOR		A, =LF			; is it LF?
			BZ		GETCH			; yes, ignore
			XOR		A, =0x07		; is it CR?		A xor (0a xor 07)
			BZ		EOLN			; yes, skip
			XOR		A, =0x52		; is it '_'?	A xor (0d xor 52)
			BZ		DELCH			; yes skip
			XOR		A, =0x57		; is it 0x08?	A xor (5f xor 57)
			BZ		CTRLH			; yes skip
			XOR		A, =0x1d		; is it 0x15?	A xor (08 xor 1d)
			BZ		CTRLU			; yes skip
			XOR		A, =0x16		; is it 0x03?	A xor (15 xor 16)
			BNZ		CHAR			; no, skip: no control char
			LD		A, =CARET		; load '^'
			CALL	7				; PUTC
			LD		A, ='C'			; load 'C'
			CALL 	7				; PUTC
			CALL	8				; CRLF
			JMP		MAINLP			; back to interpreter
CTRLU:		LD		A, =CARET		; load '^'
			CALL 	7				; PUTC
			LD		A, ='U'			; load 'U'
			CALL	7				; PUTC
			CALL	8				; CRLF
			BRA		GETLN			; restart input line
CTRLH:		LD		A, =SPACE		; load ' '
			CALL	7				; PUTC
			LD		A, =BS			; load backspace
			CALL 	7				; PUTC
DELCH:		LD		A, TMPFE		; load buffer count
			BZ		GETCH			; if at beginning of line, loop
			DLD		A, TMPFE		; decrement buffer count
			LD		A, @-1, P2    	; point one buffer pos back
			BRA		GETCH			; loop 
CHAR:		LD		A, E			; get char back
			ST		A, @1, P2   	; put into buffer
			ILD		A, TMPFE		; increment buffer counter
			XOR		A, =73			; limit of 72 chars reached?
			BNZ		GETCH			; no get another
			LD		A, =CR			; load CR
			CALL	7				; emit

EOLN:		LD		A, =CR			; load CR
			ST		A, @1, P2		; put into buffer
			LD		A, =LF			; load LF
			CALL	7				; PUTC
			LD		EA, BUFAD		; get BUFAD into P2
			LD		P2, EA
			RET						; done

;--------------------------------------------------------------------------------------------------
; handle Interrupt A (will only happen with external I/O, otherwise SA is in use)
INTA:		PUSH	EA				; save EA
			LD		EA, INTAVC		; load vector
			BRA		INT1			; skip

INTB:		PUSH	EA				; save EA
			LD		EA, INTBVC		; load vector
INT1:		ST		EA, INTVEC		; save vector
			OR		A, E			; check if EA=0
			BZ		INT2			; yes ignore
			POP		EA				; restore EA
			RET						; exit
INT2:		POP		EA				; restore EA
			OR		S, =0x01		; enable interrupts
			RET						; exit

;--------------------------------------------------------------------------------------------------
; emit error, code is in byte following CALL 15
ERROR:		POP		EA				; get address of caller
			LD		P3, EA			; into P3
			PUSH	P2    			; save P2
			LD		P2, =ERRMSG		; address of error message
			CALL 	14				; PRTLN
			LD		EA, ZERO		; clear EA
			LD		A, 1, P3    	; get error number from code
			LD		P3, EA			; into P3
			LD 		EA, AESTK		; get AESTK    
			XCH		EA, P3			; put into P3, EA is error code
			CALL	4				; APUSH
			JSR		PRNUM			; print number
			LD		A, INPMOD		; get input mode
			BZ		ERRO1			; was in interactive mode, skip
			XOR		A, =03    		; was 0x03?
			BZ 		ERRO2			; yes, skip
			JSR		PRTAT			; otherwise: print AT line#
ERRO1:		CALL 	8				; CRLF
			POP		P2				; restore P2
			LD		A, =0			; set interactive mode
			ST		A, INPMOD
			JMP		MAINLP    		; back to main loop
ERRO2:		CALL	8				; CRLF
			PLI		P2, =RETMSG		; load retype msg
			CALL 	14				; PRTLN
			POP		P2				; restore P2
			CALL	8				; CRLF
			POP		P2    			; restore P2 from call
			LD		EA, TMPF2		; restore buffer ptr from input save location
			LD		P2, EA			;
			JMP		INPUT1			; back into INPUT

;--------------------------------------------------------------------------------------------------
; print "AT line#"
PRTAT:		LD		P2, =ATMSG		; at msg
			CALL 	14				; PRTLN
			LD		EA, CURRNT		; current line
			CALL	4				; APUSH
			JMP		PRNUM    		; print line number

ERRMSG:		DB		'ERRO', 'R'+0x80
;;;STOPMSG:	DB		'STO', 'P'+0x80  BUG???
STOPMSG:	DB		'STOP', ' '+0x80
ATMSG:		DB		'A', 'T'+0x80
RETMSG:		DB		'RETYP', 'E'+0x80

;--------------------------------------------------------------------------------------------------
; check BREAK from serial, return to mainloop if pressed
; requires BRKFLG=0
CHKBRK:		LD		A, BRKFLG		; get break flag
			BNZ		CHKBR1			; if 1 then not enabled
			LD		A, S			; get status
			AND		A, =0x10		; check SA
			BZ		CHKBR2			; if low, return to main loop
CHKBR1:		RET						; otherwise exit
CHKBR2:		JMP		MAINLP

;--------------------------------------------------------------------------------------------------
; wait for and read a character from input line, return it in A
GECO:		PLI 	P2, =BAUDFLG	; get baudrate flags
			LD 		A, 0, P2		; read bits, here: bit 7
			BP		EXGET			; bit 7=0: call external routine
			POP		P2				; restore P2
			LD		A, S			; get status
			PUSH	A				; save it
			AND		S, =0xfe		; disable IE
			LD		A, =9
			ST		A, TMPFE+1		; store counter for bits
			OR		S, =0x04		; set F2
GECO1:		LD		A, S			; read status
			AND		A, =0x10		; select bit SA
			BNZ		GECO1			; if 1 loop (no start bit)
			JSR		DELAYI			; delay a half bit
			LD		A, S			; sample status
			AND		A, =0x10		; select bit SA
			BNZ		GECO1			; still 1, no start bit yet, loop
			AND		S, =0xfb		; clear F2
			OR		S, =0x02   		; set F1 (echo bit inverted)
GECO2:		JSR		DELAYI2			; do a full bit delay
			NOP						; wast some time
			NOP
			DLD		A, TMPFE+1		; decrement bit count
			BZ		GECO3			; if done, exit
			LD		A, S			; get status
			AND		A, =0x10    	; select bit SA
			SR		A				; put bit into position 02 (for F1)
			SR		A
			SR		A
			ST		A, TMPF6		; store into temporary 
			SR		A				; put bit into position 01
			RRL		A				; rotate into LINK
			XCH		A, E  			; collect bit into E
			SRL		A				; by rotating LINK into E
			XCH		A, E
			LD		A, S			; get status
			OR		A, =0x02		; preload bit 2 with 1
			XOR		A, TMPF6		; map in bit for F1 echo
			LD		S, A			; put out bit
			BRA		GECO2			; loop
GECO3:		POP		A				; restore old status
			AND		A, =0xf9		; clear F1, F2 (stop bits, reader relay)
			LD		S, A			; emit bits
			LD		A, E			; get byte received
			AND		A, =0x7f		; 7 bits only
			LD		E, A			; save into E
			RET						; exit

;--------------------------------------------------------------------------------------------------
; use external GET routine
EXGET:
			DB		2				; getchar(Areg) undefined instruction (I/O Hook)
			POP		P2				; restore P2
			RET						; exit

			NOP
			NOP


ORG_EXGET:	LD		EA, =(EXGET1-1)	; push return to caller on stack
			PUSH	EA
			LD		EA, 1, P2		; get address of routine 0xFD01
			SUB		EA, ONE   		; subtract 1
			LD		PC, EA			; jump indirect into routine

;--------------------------------------------------------------------------------------------------
; emit a CRLF (call 8)
CRLF:		LD		A, =CR			; load CR
			CALL	7				; PUTC
			LD		A, =LF			; load LF
									; fall thru into PUTC
;--------------------------------------------------------------------------------------------------
; emit the character in A (call 7)						
PUTC:
			DB		3				; putchar(Areg) undefined instruction (I/O Hook)
			RET

			NOP
			NOP

ORG_PUTC:
			PUSH 	A				; save A
			PLI 	P2, =BAUDFLG	; push P2 and load baud rate bits
			LD		A, 0, P2		; get baud rate flag, here: bit 7
			BP		EXPUTC   		; bit 7=0: goto external routines
			POP		P2				; restore P2
			POP		A  		  		; restore char
			PUSH	A				; save it again
			SL 		A  		  		; shift left (7 bit), so low bit is in pos 2
									; note: 8th bit is ignored, and first bit to emit is now
									; in the correct position for flag F1
			XCH		A, E    		; save current bits in E
			LD		A, S			; get status
			PUSH	A				; save old state
			AND		S, =0xfa		; clear F2, IE
			JSR		DELAYO			; do some delay (ensure two stop bits)
			JSR 	DELAYO			;
			OR		S, =0x02		; set F1 (start bit)
									; note inverse logic: start bit is 1
			LD		A, =9			; set counter for 9 bits
			ST		A, TMPFB		
PUTC1:		JSR		DELAYO			; wait a bit time
			DLD		A, TMPFB		; decrement bit count
			BZ		PUTC2			; is it zero?, yes skip
			LD		A, E    		; get byte to emit
			AND		A, =0x02		; extract bit to transfer
			ST		A, TMPFE+1		; save bit temporary
			LD		A, E			; get byte to emit
			SR		A    			; advance to next bit
			LD		E, A			; store back
			LD		A, S			; get status
			OR		A, =0x02    	; preload bit 2
			XOR		A, TMPFE+1		; map in inverted data bit
			LD		S, A    		; put out bit at F1
			BRA		PUTC1			; loop bits
PUTC2:		POP		A				; restore saved status
			AND		A, =0xf9		; clear F2, F1 (stop bit)
			LD		S, A			; put out stop bit
			POP		A				; restore char to emit
			RET						; exit
;--------------------------------------------------------------------------------------------------
; call external routine for PUTC
EXPUTC:		LD		EA, 3, P2		; get address at 0xFD03
			LD		P2, EA    		; into P2
			LD		EA, =(EXPUT1-1)	; address of return 
			PUSH	EA 				; save on stack (will be called on return)
			LD		A, 4, SP		; get char to emit from stack
			BRA		-1, P2			; jump to external routine on stack
EXPUT1:		POP		P2    			; restore original P2
			POP A					; restore char to emit
			RET						; return to caller

;--------------------------------------------------------------------------------------------------
; some delay
DELAYC:		PUSH	EA				; save EA
			BRA		DELAY1			; skip into delay routine

;--------------------------------------------------------------------------------------------------
; (half) delay for input
DELAYI:		PUSH	EA				; save EA
			LD		EA, DLYTIM		; get delay time
			SR		EA				; div /2
			BRA		DELAY1			; skip into delay rountine
;--------------------------------------------------------------------------------------------------
; delay for output
DELAYO:		XCH		A, E			; waste some time
			XCH		A, E    		; waste some time
DELAYI2:	PUSH	EA				; save EA
			LD		EA, DLYTIM		; get delay constant
DELAY1:		SUB		EA, ONE			; subtract 1
			BNZ		DELAY1			; loop until xx00
			XCH		A, E			; is also 00xx?
			BZ		DELAY2			; yes exit
			XCH		A, E			; put back high byte
			BRA		DELAY1 			; loop
DELAY2:		POP		EA				; restore EA
			RET						; exit

;--------------------------------------------------------------------------------------------------
	; initialize the variable for baud rate
INITBD:		PLI 	P2, =BAUDFLG	; push P2 and load it with baudrate address
			LD		EA, ZERO		; clear EA
			LD		A, 0, P2		; get baud flags
			AND		A, =0x06    	; mask out bits 1/2
			ADD		EA, =DLYTAB		; add base of DLY constants
			LD		P2, EA   		; into P2
			LD		EA, 0, P2		; get constant
			ST		EA, DLYTIM    	; store it in DLY constant word
EXGET1:		POP		P2				; restore P2
			RET						; exit
DLYTAB:		DW		0x0004			; delay for 4800bd
			DW		0x002e			; for 1200 bd
			DW		0x00d5 		; for 300 bd
			DW		0x0252			; for 110 bd
			END
;
