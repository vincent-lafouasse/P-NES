.segment "HEADER"
	.byte "NES"
	.byte $1a
	.byte $02 ; 2 PRG Banks
	.byte $01 ; 1 CHR Banks
	.byte $00, $00 ; mapper 0
	.byte $00, $00, $00, $00
	.byte $00, $00, $00, $00
