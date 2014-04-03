
FRAMERATE	equ	8	; �����̒lx2ms�œ����܂�

ATTR_BASE	equ	$e000
ATTR_SIZE	equ	$0200
VRAM_BASE	equ	$e200
VRAM_SIZE	equ	$0200

keep_fa27	equ	$dff0	;1w
keep_fa2d	equ	$dff2	;1w
counter_2ms	equ	$dff4	;1w
jobno		equ	$dff6	;1b



COL_WALL1	equ	$20	;�Â���
COL_WALL2	equ	$21	;���邢��
COL_SPACE	equ	$22	;�ǂ͖���

ldf00	equ	$df00	;
ldf01	equ	$df01	;
ldf02	equ	$df02	;1b	rand
ldf03	equ	$df03	;

BAS_BX	equ	$df10	;1b	X
BAS_BY	equ	$df11	;1b	Y
BAS_NY	equ	$df12	;1b	new Y
;	equ	$df13	;1b
;	equ	$df14	;1b
;	equ	$df15	;1b
;	equ	$df16	;1b
;	equ	$df17	;1b
BAS_SC	equ	$df18	;8b	score
BAS_SC_NUM	equ	8	;�ő�8��

JOBNO_INIT		equ	0
JOBNO_TITLE		equ	1
JOBNO_TITLE_WAIT	equ	2

;=======================================================================
	org	$4000
;-----------------------------------------------------------------------
	db	'AB'
	dw	entry
;-----------------------------------------------------------------------
main_loop:

	;sync
main_loop_sync:
	ld	a,(counter_2ms)
	cp	FRAMERATE
	jr	c,main_loop_sync

	ld	a,'*'	;over
	jr	nz,sync_over
	ld	a,' '
sync_over:
	ld	hl,VRAM_BASE+$1f;��ʉE��
	ld	(hl),a

	ld	hl,0
	ld	(counter_2ms),hl


	call	job_main


	jr	main_loop_sync

;-----------------------------------------------------------------------
job_main:
	ld	a,(jobno)
	add	a,a
	ld	e,a
	ld	d,0
	ld	hl,job_table
	add	hl,de
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	jp	(hl)

job_table:
	dw	job_init
	dw	job_title
	dw	job_title_wait
	dw	job_game
	dw	job_over
	dw	job_over_wait

;-----------------------------------------------------------------------
job_init:

job_next:
	ld	hl,jobno
	inc	(hl)
	ret

;-----------------------------------------------------------------------
job_title:
	call	init_game_screen

	ld	hl,str_title
	ld	de,VRAM_BASE+13+6*$20
	call	draw_text

	ld	hl,str_press_space
	ld	de,VRAM_BASE+10+8*$20
	call	draw_text

	jp	job_next

str_title:
	db	'FLAPPY6',0

str_press_space:
	db	'PRESS [SPACE]',0


;-----------------------------------------------------------------------
init_game_screen:
	call	clear_screen

	;�n��
	ld	hl,ATTR_BASE+0+15*$20
	ld	de,ATTR_BASE+1+15*$20
	ld	bc,32-1
	ld	a,COL_WALL2	;���邢��
	ld	(hl),a
	ldir

	;�|�b�`��
	ld	a,COL_WALL1	;�Â���
	ld	(ATTR_BASE+15+15*$20),a
	ld	(ATTR_BASE+31+15*$20),a

	ret

;-----------------------------------------------------------------------
job_title_wait:
	call	$1061
	bit	7,a
	ret	z

	;�X�^�[�g!!
	call	init_game_screen
	call	ld000;�I���W�i���̃X�N���[��������

	ld	a,4
	ld	(BAS_BX),a
	ld	a,7
	ld	(BAS_BY),a

	xor	a
	ld	hl,BAS_SC
	ld	de,BAS_SC+1
	ld	bc,BAS_SC_NUM-1
	ldir

	jp	job_next

;-----------------------------------------------------------------------
job_game:

	ld	a,(BAS_BY)

	;�ړ�����

	ld	(BAS_NY),a

	;���L��������
	ld	de,VRAM_BASE
	ld	hl,(BAS_BX)
	ld	a,' '
	push	hl
	call	put_char
	pop	hl
	;attr��
	ld	de,ATTR_BASE
	call	pos2vram
	ld	a,COL_SPACE
	ld	(hl),a

	;���L�����`��
	ld	de,VRAM_BASE
	ld	a,(BAS_NY)
	ld	h,a
	ld	a,(BAS_BX)
	ld	l,a
	ld	a,'6'
	push	hl
	call	put_char
	pop	hl
	;attr��
	ld	de,ATTR_BASE
	call	pos2vram
	ld	a,COL_SPACE
	ld	(hl),a

	;�X�N���[��
	call	ld004

	;�A�^������
	ld	de,ATTR_BASE
	ld	hl,(BAS_BX)
	call	get_char
	cp	COL_SPACE
	jp	nz,job_next	;->gameover

	;�X�R�A
	ld	hl,str_score
	ld	de,VRAM_BASE+12+0*$20
	call	draw_text
	ld	hl,BAS_SC
	ld	de,VRAM_BASE+19+0*$20
	call	draw_score
	call	inc_score

	ret

str_score:
	db	'SCORE:',0

;-----------------------------------------------------------------------
inc_score:
	ld	b,BAS_SC_NUM
	ld	hl,BAS_SC+BAS_SC_NUM-1
inc_score_lp:
	ld	a,(hl)
	inc	a
	ld	(hl),a
	cp	10
	ret	c	;�J��オ��Ȃ��̂ŏI��

	;�����
	sub	10
	ld	(hl),a	;�ۑ�������
	dec	hl
	djnz	inc_score_lp
	ret

;-----------------------------------------------------------------------
; in	h	y
;	l	x
;	de	*base
;	a	char
;-----------------------------------------------------------------------
put_char:
	ld	c,a;push
	call	pos2vram
	ld	(hl),c
	ret

;-----------------------------------------------------------------------
get_char:
	call	pos2vram
	ld	a,(hl)
	ret

;-----------------------------------------------------------------------
; in	de	*base
;	h	y
;	l	x
; out	hl	*vram
;-----------------------------------------------------------------------
pos2vram:
	ld	a,h;Y
	and	a,$0f;�O�̂���
	sla	a
	sla	a
	sla	a
	sla	a;�����܂ł�cy=1�ɂȂ�Ȃ�
	sla	a;x$20
	ld	h,0
	rl	h

	add	a,l;X
	ld	l,a
;	ld	a,h;;
;	adc	a,0;;���ۂɂ͌����͔������Ȃ��̂Ŗ����Ă�����
;	ld	h,a;;
	add	hl,de

	ret

;-----------------------------------------------------------------------
job_over:
	ld	hl,str_gameover
	ld	de,VRAM_BASE+12+6*$20
	call	draw_text

	ld	hl,str_replay
	ld	de,VRAM_BASE+11+8*$20
	call	draw_text

	jp	job_next

str_gameover:
	db	'GAME OVER',0

str_replay:
	db	'REPLAY(Y/N)?',0

;-----------------------------------------------------------------------
job_over_wait:
	call	$1061
	bit	0,a
	ret	z

	ld	a,JOBNO_TITLE
	ld	(jobno),a

	ret

;-----------------------------------------------------------------------
; in	hl	*str (asciz)
;	de	*vram
;-----------------------------------------------------------------------
draw_text:
	ld	a,(hl)
	and	a
	ret	z
	ld	(de),a
	push	af
	dec	d
	dec	d
	ld	a,COL_SPACE
	ld	(de),a
	inc	d
	inc	d
	pop	af
	inc	hl
	inc	de
	jr	draw_text

;-----------------------------------------------------------------------
; in	hl	*score
;	de	*vram
;-----------------------------------------------------------------------
draw_score:
	ld	c,0	;�\���t���O
	ld	b,8	;�ő�8��

draw_score_lp:
	ld	a,c
	and	a
	jr	nz,draw_score_draw

	;skip 0
	ld	a,(hl)
	and	a
	jr	nz,draw_score_on
	;0�ł��Ō�̌��͕\��
	ld	a,b
	dec	a
	jr	nz,draw_score_skip
draw_score_on:
	inc	c	;on!

draw_score_draw:
	ld	a,(hl)
	add	a,'0'
	ld	(de),a
	inc	de
draw_score_skip:
	inc	hl
	djnz	draw_score_lp

	ret

;-----------------------------------------------------------------------
;-----------------------------------------------------------------------
entry:
	;�X�^�b�N������/2ms�^�C�}�[�n���h���o�^
	di
;	ld	(keep_sp),sp
;	ld	hl,LOCAL_STACK
;	ld	sp,hl
	ld	hl,timer_handler
	ld	($fa06),hl
	ei

	;�|�[�g$b0�ۑ�
	ld	a,($fa27)
	ld	(keep_fa27),a

	;�L�[�N���b�N��OFF
	ld	a,($fa2d)
	ld	(keep_fa2d),a
	xor	a
	ld	($fa2d),a

	;��ʏ�����
	call	init_screen

	;���C�����[�v��
	ld	a,JOBNO_INIT
	ld	(jobno),a
	ld	hl,0
	ld	(counter_2ms),hl
	jp	main_loop

;-----------------------------------------------------------------------
;	2ms�^�C�}�[�n���h��
;-----------------------------------------------------------------------
timer_handler:
	push	hl
	ld	hl,(counter_2ms)
	inc	hl
	ld	(counter_2ms),hl
	pop	hl
	ei
	ret

;-----------------------------------------------------------------------
;	��ʏ�����
;-----------------------------------------------------------------------
init_screen:
	;�\��OFF
	ld	a,%00000010
	out	($93),a

	call	clear_screen
	;�\���y�[�W2
	ld	a,%00000010
	ld	b,%00000110
	call	$1b54		;�|�[�g$b0�Z�b�g

	;�\��ON
	ld	a,%00000011
	out	($93),a

	ret

;-----------------------------------------------------------------------
clear_screen:
	;attribute
	ld	hl,ATTR_BASE
	ld	de,ATTR_BASE+1
	ld	bc,ATTR_SIZE-1
	ld	a,COL_SPACE;%00100010
	ld	(hl),a
	ldir

	;vram
	ld	hl,VRAM_BASE
	ld	de,VRAM_BASE+1
	ld	bc,VRAM_SIZE-1
	ld	a,$20	;space
	ld	(hl),a
	ldir

	ret
;-----------------------------------------------------------------------
;-----------------------------------------------------------------------
;-----------------------------------------------------------------------
;-----------------------------------------------------------------------
;=======================================================================
;-----------------------------------------------------------------------
;-----------------------------------------------------------------------
;-----------------------------------------------------------------------
;	entry 1 / initialize
;-----------------------------------------------------------------------
ld000:
	call	ld08d	;���[�N������
	ret

;-----------------------------------------------------------------------
;	entry 2
;-----------------------------------------------------------------------
ld004:
	call	ld00b	;�A�g���r���[�g�G���A�����X�N���[��
	call	ld021	;�E�[�ɒ��Ƃ����
	ret

;-----------------------------------------------------------------------
;	�A�g���r���[�g�G���A�����X�N���[��
;-----------------------------------------------------------------------
ld00b:
	ld	hl,ATTR_BASE
	ld	a,$10
ld010:
	push	af
	ld	a,$1f
ld013:
	inc	hl
	ld	b,(hl)
	dec	hl
	ld	(hl),b
	inc	hl
	dec	a
	jr	nz,ld013
	inc	hl
	pop	af
	dec	a
	jr	nz,ld010
	ret

;-----------------------------------------------------------------------
;	�E�[�ɒ��Ƃ����
;-----------------------------------------------------------------------
ld021:
	ld	a,(ldf00)
	inc	a
	ld	(ldf00),a
	sub	$09
	jr	c,ld042

	;9�ȏ�
	ld	a,COL_WALL2	;���邢��
	ld	(ldf03),a
	ld	a,(ldf01)
	inc	a
	dec	a
	jr	z,ld053
	ld	a,COL_WALL1	;�Â���
	ld	(ldf03),a
	ld	a,(ldf01);������K�v�Ȃ�!!
	jr	ld053

	;8�ȉ�
ld042:
	;�E�[�N���A
	ld	a,$0f
	ld	bc,$0020
	ld	hl,ATTR_BASE+$1f	;1�s�ڂ̉E�[
ld04a:
	ld	(hl),COL_SPACE	;�ǂ�����
	add	hl,bc
	dec	a
	jr	nz,ld04a
	;�ŏ��̕ǂ͖��邢!
	ld	(hl),COL_WALL2	;���邢��
	ret

	;(ldf03) = ���̐F
ld053:
	ld	a,(ldf02)	;rand
	ld	bc,$0020
	ld	hl,ATTR_BASE+$3f	;2�s�ڂ̉E�[
ld05c:
	push	af
	ld	a,(ldf03)
	ld	(hl),a
	pop	af
	add	hl,bc
	dec	a
	jr	nz,ld05c

	ld	a,$06
ld068:
	ld	(hl),$22	;���̐F
	add	hl,bc
	dec	a
	jr	nz,ld068
	ld	a,(ldf02)	;rand
	ld	d,a
	ld	a,$0b
	sub	d
ld075:
	push	af
	ld	a,(ldf03)
	ld	(hl),a
	pop	af
	add	hl,bc
	dec	a
	jr	nz,ld075
	ld	a,(ldf01)
	inc	a
	ld	(ldf01),a
	sub	$04
	ret	c

	call	ld08d	;���[�N������
	ret

;-----------------------------------------------------------------------
;	���[�N������
;-----------------------------------------------------------------------
ld08d:
	xor	a
	ld	(ldf00),a
	ld	(ldf01),a
	ld	a,r
	and	$07
	inc	a
	ld	(ldf02),a	;rand
	ret

;-----------------------------------------------------------------------
;-----------------------------------------------------------------------
;-----------------------------------------------------------------------
;-----------------------------------------------------------------------
;-----------------------------------------------------------------------
;=======================================================================
