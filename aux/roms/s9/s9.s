;
; File generated by cc65 v 2.19 - Git 2dbc7d169
;
	.fopt		compiler,"cc65 v 2.19 - Git 2dbc7d169"
	.setcpu		"6502"
	.smart		on
	.autoimport	on
	.case		on
	.debuginfo	off
	.importzp	sp, sreg, regsave, regbank
	.importzp	tmp1, tmp2, tmp3, tmp4, ptr1, ptr2, ptr3, ptr4
	.macpack	longbranch
	.forceimport	__STARTUP__
	.export		_main

; ---------------------------------------------------------------
; int __near__ main (void)
; ---------------------------------------------------------------

.segment	"CODE"

.proc	_main: near

.segment	"CODE"

	ldx     #$00
	lda     #$69
	jmp     L0001
L0001:	rts

.endproc

