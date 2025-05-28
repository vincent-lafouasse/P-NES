.segment "HEADER"
	.byte "NES"
	.byte $1a
	.byte $02 ; 2 PRG Banks
	.byte $01 ; 1 CHR Banks
	.byte $00, $00 ; mapper 0
	.byte $00, $00, $00, $00
	.byte $00, $00, $00, $00

.segment "ZEROPAGE"
VAR:	.RES 1 ; reserve one byte

.segment "STARTUP"

RESET:
	INFLOOP:
		JMP INFLOOP

NMI:
	RTI

.segment "VECTORS"
	.word NMI
	.word RESET
	; third hardware interrupt

.segment "CHARS"
	.incbin "rom.chr"
