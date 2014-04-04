
FRAMERATE	equ	8	; ここの値x2msで動きます

ATTR_BASE	equ	$e000
ATTR_SIZE	equ	$0200
VRAM_BASE	equ	$e200
VRAM_SIZE	equ	$0200

COL_PIPE_SHADOW	equ	$20	;pipe (shadow)
COL_PIPE	equ	$21	;pipe (bright)
COL_SPACE	equ	$22	;space (empty)

ldf00		equ	$df00	;
ldf01		equ	$df01	;
ldf02		equ	$df02	;1b	rand
ldf03		equ	$df03	;

BAS_BX		equ	$df10	;1w	X
BAS_BY		equ	$df12	;1w	Y
BAS_NY		equ	$df14	;1w	new Y
;		equ	$df16	;1b
;		equ	$df17	;1b
BAS_SC		equ	$df18	;8b	score
BAS_SC_NUM	equ	8	;最大8桁

pl_spd		equ	$df80	;1w	player speed
pl_acc		equ	$df82	;1w	player acceleration
scroll_counter	equ	$df84	;1b

keep_fa27	equ	$dff0	;1w
keep_fa2d	equ	$dff2	;1w
counter_2ms	equ	$dff4	;1w
jobno		equ	$dff6	;1b
;		equ	$dff7
stick_state	equ	$dffc	;1b
stick_old	equ	$dffd	;1b
stick_trigger	equ	$dffe	;1b
stick_trigger_	equ	$dfff	;1b

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
	ld	hl,VRAM_BASE+$1f	;right-top corner
	ld	(hl),a

	ld	hl,0
	ld	(counter_2ms),hl


	call	update_stick
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

	;ground
	ld	hl,ATTR_BASE+0+15*$20
	ld	de,ATTR_BASE+1+15*$20
	ld	bc,32-1
	ld	a,COL_PIPE
	ld	(hl),a
	ldir

	;marking
	ld	a,COL_PIPE_SHADOW
	ld	(ATTR_BASE+15+15*$20),a
	ld	(ATTR_BASE+31+15*$20),a

	ret

;-----------------------------------------------------------------------
job_title_wait:
	ld	a,(stick_trigger)
	bit	7,a	;push space?
	ret	z

	;START!!
	call	init_game_screen
	call	ld000;init scroll

	ld	hl,4<<8
	ld	(BAS_BX),hl
	ld	hl,7<<8
	ld	(BAS_BY),hl

	;player
	ld	hl,$ffc0;-0.25
	ld	(pl_spd),hl
	ld	hl,$0003
	ld	(pl_acc),hl	;gravity

	;scroll
	xor	a
	ld	(scroll_counter),a

	;score
	xor	a
	ld	hl,BAS_SC
	ld	de,BAS_SC+1
	ld	(hl),a
	ld	bc,BAS_SC_NUM-1
	ldir

	jp	job_next

;-----------------------------------------------------------------------
job_game:

	;check tap
	ld	a,(stick_trigger)
	bit	7,a	;push space?
	jr	z,job_game_notap

	;上昇中のタップ
	ld	de,$fff8;	;ちょっとだけ浮く

	ld	hl,(pl_spd)
	ld	a,h
	and	a
	jp	m,job_game_tap		;上昇中はちょっとだけ浮く
	jr	nz,job_game_tap_down
	ld	a,(pl_spd+0)
	cp	$10
	jr	c,job_game_tap		;下降中も最初の方はちょっとだけしか浮かない
job_game_tap_down:

	;ガッツリ下降中のタップ
	ld	de,$ffa0;

job_game_tap:
	add	hl,de
	ld	(pl_spd),hl

job_game_notap:
	;move player
	;y += speed
	ld	hl,(BAS_BY)
	ex	de,hl
	ld	hl,(pl_spd)
	add	hl,de
	ld	(BAS_NY),hl
	;speed += acc
	ld	hl,(pl_spd)
	ex	de,hl
	ld	hl,(pl_acc)
	add	hl,de
	ld	(pl_spd),hl

	;limit/over
	ld	hl,(BAS_NY)
	ld	de,1<<8
	and	a;cf=0
	sbc	hl,de
	jr	c,job_game_limit_set
	;limit/under
	ld	hl,(BAS_NY)
	ld	de,15<<8
	and	a;cf=0
	sbc	hl,de
	jr	z,job_game_limit_end
	jr	c,job_game_limit_end
job_game_limit_set:
	ex	de,hl
	ld	(BAS_NY),hl
job_game_limit_end:

	;clear player
	ld	de,VRAM_BASE
	ld	a,(BAS_BX+1)	;int(BX)
	ld	l,a
	ld	a,(BAS_BY+1)	;int(BY)
	ld	h,a
	ld	a,' '
	push	hl
	call	put_char
	pop	hl
	;attr
	ld	de,ATTR_BASE
	call	pos2vram
	ld	a,COL_SPACE
	ld	(hl),a

	;change player pattern
	ld	b,'6'
	ld	a,(pl_spd+1)
	and	a
	jp	m,set_player_pattern
	ld	b,'9'
	jr	nz,set_player_pattern
	ld	a,(pl_spd+0)
	cp	$40
	jr	nc,set_player_pattern
	ld	b,$e9;'の'
set_player_pattern:

	;draw player
	ld	de,VRAM_BASE
	ld	a,(BAS_BX+1)	;int(BX)
	ld	l,a
	ld	a,(BAS_NY+1)	;int(NY)
	ld	h,a
	ld	a,b;;'6'
	push	hl
	call	put_char
	pop	hl
	;attr
	ld	de,ATTR_BASE
	call	pos2vram
	ld	a,COL_SPACE
	ld	(hl),a

	;update pos
	ld	hl,(BAS_NY)
	ld	(BAS_BY),hl

	;check scroll
	ld	a,(scroll_counter)
	inc	a
	and	$07
	ld	(scroll_counter),a
	jr	nz,skip_scroll

	;scroll
	call	ld004

	;dead or alive
	ld	de,ATTR_BASE
	ld	a,(BAS_BX+1)	;int(BX)
	ld	l,a
	ld	a,(BAS_BY+1)	;int(BY)
	ld	h,a
	call	get_char
	cp	COL_SPACE
	jp	nz,job_next	;->gameover

	;score
	ld	hl,str_score
	ld	de,VRAM_BASE+12+0*$20
	call	draw_text
	ld	hl,BAS_SC
	ld	de,VRAM_BASE+19+0*$20
	call	draw_score
	call	inc_score

skip_scroll:

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
	ret	c	;no carry -> finish

	;carry over
	sub	10
	ld	(hl),a	;re-store
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
	and	a,$0f;念のため
	sla	a
	sla	a
	sla	a
	sla	a;ここまではcy=1にならない
	sla	a;x$20
	ld	h,0
	rl	h

	add	a,l;X
	ld	l,a
;	ld	a,h;;
;	adc	a,0;;実際には桁上りは発生しないので無くてもいい
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
	ld	a,(stick_trigger)
	bit	0,a	;shift
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
	ld	c,0	;表示フラグ
	ld	b,8	;最大8桁

draw_score_lp:
	ld	a,c
	and	a
	jr	nz,draw_score_draw

	;skip 0
	ld	a,(hl)
	and	a
	jr	nz,draw_score_on
	;0でも最後の桁は表示
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
	;init stack & register 2m-timer handler
	di
;	ld	(keep_sp),sp
;	ld	hl,LOCAL_STACK
;	ld	sp,hl
	ld	hl,timer_handler
	ld	($fa06),hl
	ei

	;keep port $b0
	ld	a,($fa27)
	ld	(keep_fa27),a

	;turn off click sound
	ld	a,($fa2d)
	ld	(keep_fa2d),a
	xor	a
	ld	($fa2d),a

	;initialize devices
	call	init_screen
	call	init_stick

	;メインループへ
	ld	a,JOBNO_INIT
	ld	(jobno),a
	ld	hl,0
	ld	(counter_2ms),hl
	jp	main_loop

;-----------------------------------------------------------------------
;	2ms-timer handler
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
;	initialize screen
;-----------------------------------------------------------------------
init_screen:
	;表示OFF
	ld	a,%00000010
	out	($93),a

	call	clear_screen
	;表示ページ2
	ld	a,%00000010
	ld	b,%00000110
	call	$1b54		;ポート$b0セット

	;表示ON
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
init_stick:
	xor	a
	ld	(stick_state),a
	call	update_stick
	ret

;-----------------------------------------------------------------------
update_stick:
	;update stick
	ld	a,(stick_state)
	ld	(stick_old),a
	ld	b,a	;keep old
	call	$1061
	ld	(stick_state),a
	ld	c,a	;keep state

	;(state XOR old) AND state = trigger
	xor	b	;state XOR old
	and	c	;AND state
	ld	(stick_trigger),a

	;(state XOR old) AND old = ~trigger
	ld	a,b
	xor	c	;state XOR old
	and	b	;AND old
	ld	(stick_trigger_),a

	ret

;-----------------------------------------------------------------------
;-----------------------------------------------------------------------
;=======================================================================
;-----------------------------------------------------------------------
;-----------------------------------------------------------------------
;-----------------------------------------------------------------------
;	entry 1 / initialize
;-----------------------------------------------------------------------
ld000:
	call	ld08d	;ワーク初期化
	ret

;-----------------------------------------------------------------------
;	entry 2 / scroll
;-----------------------------------------------------------------------
ld004:
	call	ld00b	;アトリビュートエリアを左スクロール
	call	ld021	;右端に柱とか作る
	ret

;-----------------------------------------------------------------------
;	アトリビュートエリアを左スクロール
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
;	右端に土管を作る
;-----------------------------------------------------------------------
ld021:
	ld	a,(ldf00)
	inc	a
	ld	(ldf00),a
	sub	$09
	jr	c,ld042

	;9以上
	ld	a,COL_PIPE
	ld	(ldf03),a
	ld	a,(ldf01)
	inc	a
	dec	a
	jr	z,ld053
	ld	a,COL_PIPE_SHADOW
	ld	(ldf03),a
	ld	a,(ldf01);※これ必要ない!!
	jr	ld053

	;8以下
ld042:
	;右端クリア
	ld	a,$0f
	ld	bc,$0020
	ld	hl,ATTR_BASE+$1f	;1行目の右端
ld04a:
	ld	(hl),COL_SPACE	;何も無い
	add	hl,bc
	dec	a
	jr	nz,ld04a
	;土管の最初は明るい!
	ld	(hl),COL_PIPE
	ret

	;(ldf03) = 土管の色
ld053:
	ld	a,(ldf02)	;rand
	ld	bc,$0020
	ld	hl,ATTR_BASE+$3f	;2行目の右端
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
	ld	(hl),COL_SPACE	;何もない
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

	call	ld08d	;ワーク初期化
	ret

;-----------------------------------------------------------------------
;	ワーク初期化
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
