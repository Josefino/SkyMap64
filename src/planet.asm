; =====================================================================
;  SkyMap64 v1.1 - graphics engine (Czech / English build) (ACME assembler)
;  Hires bitmap at $E000 (VIC bank 3), screen/colour RAM at $CC00.
;  Called from BASIC with SYS 8192. Parameter block at $2003.
; =====================================================================
!cpu 6502
!to "planet_ml.bin", plain

!ifndef LANG { LANG = 0 }        ; 0 = Czech, 1 = English (acme -DLANG=1)
!if LANG = 0 {
ST_AZ   = 3         ; status bar layout
ST_ALT  = 8
ST_FOV  = 16
DSEP    = '.'
DP_D    = 23
DP_M    = 26
DP_Y    = 29
} else {
ST_AZ   = 2
ST_ALT  = 7
ST_FOV  = 15
DSEP    = '-'
DP_D    = 31
DP_M    = 28
DP_Y    = 23
}
BITMAP  = $e000
SCREEN  = $cc00
OUTBUF  = $a000         ; 5 bytes per star: sx(2) sy(2) flag
SEGSTK  = $c000         ; clip stack, 8 bytes/entry, 64 entries
ZPSAVE  = $c200
SQ2LO   = $c400
SQ2HI   = $c600
SQSL    = $c800
SQSH    = $c900
OCC     = $b800             ; label occupancy, 40x25
GETIN   = $ffe4
MAXSEG  = 64

; ---- zero page (saved/restored $02-$72) ----
ma      = $02
mb      = $04
mr      = $06   ; 4
m8a     = $0a
m8b     = $0b
m8p     = $0c   ; 2
mtmp    = $0e   ; 2
acc     = $10   ; 4
dvd     = $14   ; 4
dvs     = $18   ; 2
vp      = $1a
mp      = $1c
rp      = $1e
px      = $20
py      = $22
bp      = $24
sp0     = $26
op      = $28
cnt     = $2a
pX      = $2c
pY      = $2e
pD      = $32
sx      = $34
sy      = $36
pflag   = $38
t0      = $39
t1      = $3a
t2      = $3b
t3      = $3c
t6      = $3f
t7      = $40
lx0     = $41
ly0     = $43
lx1     = $45
ly1     = $47
ldx_    = $49
ldy_    = $4b
lerr    = $4d
lsx     = $4f
lsy     = $50
dotted  = $51
dotc    = $52
strp    = $53
cx      = $55
cy      = $56
ccol    = $57
tmpw    = $58
tmpw2   = $5a
sgn     = $5c
oc0     = $5d
oc1     = $5e
segsp   = $5f
ip      = $60
fres    = $62
res     = $64
jv      = $66
fp      = $68
sres    = $6a
cp      = $6c
pat     = $6e
qacc    = $70
zp_     = $72

*= $2000
        jmp main
; ---- parameter block ($2003) written/read by BASIC ----
lst_base  !word 0       ; +0  local sidereal time at base moment (65536 = 360 deg)
lat       !word 0       ; +2  latitude (signed angle)
basemin   !word 0       ; +4  local clock minutes of day
offmin    !word 0       ; +6  time offset in minutes (signed)
exitcode  !byte 0       ; +8
keepview  !byte 0       ; +9
planets   !fill 42,0    ; +10 7 x (x,y,z) s1.14 equatorial unit vectors
pday      !byte 24      ; +52 base date
pmon      !byte 11      ; +53
pyear     !word 2026    ; +54
pmode     !byte 0       ; +56 1 = show title screen only
          !byte 0

; ---- variables ----
az      !word $8000
alt     !word 5461
zoom    !byte 1
showl   !byte 1
shown   !byte 1
showm   !byte 1
lst     !word 0
kval    !word 0
dmin    !word 0
kd2     !byte 0
kd3     !byte 0
maglim  !byte 0
skycol  !byte $10
ch      !word 0
sh      !word 0
matA    !fill 18,0      ; rows N,E,U
matV    !fill 18,0      ; rows R,UP,F (view, in N,E,U)
matM    !fill 18,0      ; V*A : rows R,UP,F in equatorial
Qlo     !fill 40,0
Qhi     !fill 40,0
hvec    !fill 6,0
tgtv    !fill 6,0       ; searched object (equatorial vector)
tgtf    !byte 0
fbuf    !fill 17,0
flen    !byte 0
dday    !byte 0
dmon    !byte 0
dyear   !word 0
hn      !word 0
he      !word 0
hu      !word 0
blo     !word 0
bhi     !word 0
bscore  !word 0
bang    !word 0
cang    !word 0
cend    !word 0
cstep   !word 0
qv      !fill 3,0
qmat    !fill 12,0
qw      !word 0
ubx     !word 0
uby     !word 0
qa      !byte 0
qb      !byte 0
qs      !byte 0
qx      !byte 0
qabove  !byte 0
qzmin   !word 0
fm_lo   !fill 9,0
fm_hi   !fill 9,0
fm_sg   !fill 9,0
zcnt    !byte 0
zcone   !word 0
lmask   !byte 0
lcnt    !word 0
occchk  !byte 0
lyl     !byte 0
hprevx  !word 0
hprevy  !word 0
hprevf  !byte 0
sbuf    !fill 41,0
sv0     !word 0
sv1     !word 0
saverep !byte 0
sL      !word 0
cL      !word 0
sP      !word 0
cP      !word 0
sA      !word 0
cA      !word 0

; =====================================================================
main
        ldx #2
-       lda $00,x
        sta ZPSAVE,x
        inx
        cpx #$74
        bne -
        lda $028a
        sta saverep
        lda #$80
        sta $028a               ; repeat all keys
        lda pmode
        beq +
        jsr title
        jmp exitrest
+       lda keepview
        bne +
        lda #$00
        sta az
        lda #$80
        sta az+1                ; looking south
        lda #<5461
        sta alt
        lda #>5461
        sta alt+1               ; 30 deg up
        lda #1
        sta zoom
        sta showl
        sta shown
+       jsr gen_sq2
        jsr gfx_on
redraw
        jsr compute_lst
        jsr render
        lda #0
        sta $c6                 ; flush keyboard buffer
waitkey
        jsr GETIN
        cmp #0
        bne gotkey
        lda $dc00               ; joystick port 2
        and #$0f
        cmp #$0f
        beq waitkey
        lsr
        bcs +
        jmp k_up
+       lsr
        bcs +
        jmp k_down
+       lsr
        bcs +
        jmp k_left
+       jmp k_right
gotkey
        ldx #0
-       ldy keytab,x
        beq waitkey
        cmp keytab,x
        beq +
        inx
        inx
        inx
        bne -
+       lda keytab+1,x
        sta jv
        lda keytab+2,x
        sta jv+1
        jmp (jv)

keytab
        !byte $91
        !word k_up
        !byte $11
        !word k_down
        !byte $9d
        !word k_left
        !byte $1d
        !word k_right
        !byte '+'
        !word k_zin
        !byte '-'
        !word k_zout
        !byte ','
        !word k_tm10
        !byte '.'
        !word k_tp10
        !byte ':'
        !word k_tm60
        !byte ';'
        !word k_tp60
!if LANG = 0 {
        !byte $53               ; S sever
        !word k_n
        !byte $56               ; V
        !word k_e
        !byte $4a               ; J
        !word k_s
        !byte $5a               ; Z
        !word k_w
        !byte $4e               ; N nazvy
        !word k_names
        !byte $48               ; H hledat
        !word k_find
} else {
        !byte $4e               ; N north
        !word k_n
        !byte $45               ; E
        !word k_e
        !byte $53               ; S
        !word k_s
        !byte $57               ; W
        !word k_w
        !byte $4c               ; L labels
        !word k_names
        !byte $46               ; F find
        !word k_find
}
        !byte $43               ; C
        !word k_lines
        !byte $44               ; D
        !word k_date
        !byte $51               ; Q
        !word k_quit
        !byte $4d               ; M
        !word k_mess
        !byte $49               ; I
        !word k_info
        !byte $0d               ; RETURN
        !word k_recalc
        !byte 0

k_up    ldx zoom
        lda alt
        clc
        adc zsteplo,x
        sta alt
        lda alt+1
        adc zstephi,x
        sta alt+1
        ; clamp to <= 16384 (90 deg)
        lda alt
        cmp #<16385
        lda alt+1
        sbc #>16385
        bvc +
        eor #$80
+       bmi +
        lda #<16384
        sta alt
        lda #>16384
        sta alt+1
+       jmp redraw
k_down  ldx zoom
        lda alt
        sec
        sbc zsteplo,x
        sta alt
        lda alt+1
        sbc zstephi,x
        sta alt+1
        ; clamp to >= -20 deg (-3641)
        lda alt
        cmp #<(-3641)
        lda alt+1
        sbc #>(-3641)
        bvc +
        eor #$80
+       bpl +
        lda #<(-3641)
        sta alt
        lda #>(-3641)
        sta alt+1
+       jmp redraw
k_left  ldx zoom
        lda az
        sec
        sbc zsteplo,x
        sta az
        lda az+1
        sbc zstephi,x
        sta az+1
        jmp redraw
k_right ldx zoom
        lda az
        clc
        adc zsteplo,x
        sta az
        lda az+1
        adc zstephi,x
        sta az+1
        jmp redraw
k_zin   lda zoom
        cmp #NZOOM-1
        bcs +
        inc zoom
        jmp redraw
+       jmp waitkey
k_zout  lda zoom
        beq +
        dec zoom
        jmp redraw
+       jmp waitkey
k_tm10  lda #<(-10)
        ldx #>(-10)
        jmp addtime
k_tp10  lda #10
        ldx #0
        jmp addtime
k_tm60  lda #<(-60)
        ldx #>(-60)
        jmp addtime
k_tp60  lda #60
        ldx #0
!zone
addtime clc
        adc offmin
        sta tmpw
        txa
        adc offmin+1
        sta tmpw+1
        bmi .neg
        lda tmpw
        cmp #<12961
        lda tmpw+1
        sbc #>12961
        bcs .rej
        bcc .ok
.neg    lda tmpw
        cmp #<(-12960)
        lda tmpw+1
        sbc #>(-12960)
        bcc .rej
.ok     lda tmpw
        sta offmin
        lda tmpw+1
        sta offmin+1
        jmp redraw
.rej    jmp waitkey
k_n     lda #$00
        jmp setaz
k_e     lda #$40
        jmp setaz
k_s     lda #$80
        jmp setaz
k_w     lda #$c0
setaz   sta az+1
        lda #0
        sta az
        jmp redraw
k_lines lda showl
        eor #1
        sta showl
        jmp redraw
k_names lda shown
        eor #1
        sta shown
        jmp redraw
k_mess  lda showm
        eor #1
        sta showm
        jmp redraw
k_info  lda #4
        jmp exit
k_quit  lda #1
        jmp exit
k_date  lda #2
        jmp exit
k_recalc lda #3
exit    sta exitcode
        jsr gfx_off
exitrest
        lda saverep
        sta $028a
        lda #0
        sta $c6
        ldx #2
-       lda ZPSAVE,x
        sta $00,x
        inx
        cpx #$74
        bne -
        rts

; ---------------------------------------------------------------------
gfx_on  lda #0
        sta $d020
        lda #<nmirti
        sta $fffa
        lda #>nmirti
        sta $fffb
        lda $dd02
        ora #3
        sta $dd02
        lda $dd00
        and #$fc                ; bank 3 ($c000-$ffff)
        sta $dd00
        lda #$38                ; screen $cc00, bitmap $e000
        sta $d018
        lda #$08
        sta $d016
        lda #$3b
        sta $d011
        rts
gfx_off lda $dd00
        ora #3
        sta $dd00
        lda #$15
        sta $d018
        lda #$c8
        sta $d016
        lda #$1b
        sta $d011
        rts
nmirti  rti

; ---------------------------------------------------------------------
compute_lst
        lda offmin
        sta ma
        lda offmin+1
        sta ma+1
        lda #<11682             ; 45.6334 * 256 units per minute
        sta mb
        lda #>11682
        sta mb+1
        jsr mul16s
        lda lst_base
        clc
        adc mr+1
        sta lst
        lda lst_base+1
        adc mr+2
        sta lst+1
        rts

; =====================================================================
render
        sei
        lda #$35
        sta $01
        lda $d011
        and #$ef
        sta $d011               ; blank screen while drawing
        ldx zoom
        lda zklo,x
        sta kval
        lda zkhi,x
        sta kval+1
        lda zklo,x              ; K << 18 : bytes 2,3 of the dividend
        asl
        sta kd2
        lda zkhi,x
        rol
        sta kd3
        asl kd2
        rol kd3
        lda zdlo,x
        sta dmin
        lda zdhi,x
        sta dmin+1
        lda zmag,x
        sta maglim
        lda zuxlo,x
        sta ubx
        lda zuxhi,x
        sta ubx+1
        lda zuylo,x
        sta uby
        lda zuyhi,x
        sta uby+1
        lda zconelo,x
        sta zcone
        lda zconehi,x
        sta zcone+1
        lda zqlo,x
        sta qzmin
        lda zqhi,x
        sta qzmin+1
        jsr build_matrices
        jsr fsetup
        jsr clear_bitmap
        jsr sun_check
        jsr fill_colors
        jsr draw_horizon
        jsr project_stars
        lda showl
        beq +
        jsr draw_lines
+       jsr draw_stars
        jsr clear_occ
        lda #1
        sta occchk
        jsr draw_cardinals
        jsr draw_planets
        jsr draw_target
        lda shown
        beq +
        jsr draw_conlabels
        jsr draw_starlabels
+       jsr draw_messier
        lda #0
        sta occchk
        jsr draw_status
        lda $d011
        ora #$10
        sta $d011
        lda #$37
        sta $01
        cli
        rts

; ---------------------------------------------------------------------
; sin/cos lookup. in: tmpw = angle. out: sres
getcos  lda tmpw+1
        clc
        adc #$40
        sta tmpw+1
getsin  lda tmpw
        clc
        adc #32
        sta t0
        lda tmpw+1
        adc #0
        sta t1
        lsr
        lsr
        lsr
        lsr
        lsr
        lsr
        clc
        adc #>sinlo
        sta ip+1
        lda t1
        asl
        asl
        sta ip
        lda t0
        clc
        rol
        rol
        rol
        and #3
        ora ip
        sta ip
        ldy #0
        lda (ip),y
        sta sres
        lda ip+1
        clc
        adc #4
        sta ip+1
        lda (ip),y
        sta sres+1
        rts

; helpers: load angle into tmpw, get sin/cos into a variable
!macro sincos .ang, .s, .c {
        lda .ang
        sta tmpw
        lda .ang+1
        sta tmpw+1
        jsr getsin
        lda sres
        sta .s
        lda sres+1
        sta .s+1
        lda .ang
        sta tmpw
        lda .ang+1
        sta tmpw+1
        jsr getcos
        lda sres
        sta .c
        lda sres+1
        sta .c+1
}
!macro multo .a, .b, .dst {     ; dst = a*b >> 14
        lda .a
        sta ma
        lda .a+1
        sta ma+1
        lda .b
        sta mb
        lda .b+1
        sta mb+1
        jsr fixmul
        lda fres
        sta .dst
        lda fres+1
        sta .dst+1
}
!macro neg .v {
        lda #0
        sec
        sbc .v
        sta .v
        lda #0
        sbc .v+1
        sta .v+1
}
!macro copyw .src, .dst {
        lda .src
        sta .dst
        lda .src+1
        sta .dst+1
}

build_matrices
        +sincos lst, sL, cL
        +sincos lat, sP, cP
        +sincos az, sA, cA
        +sincos alt, sh, ch
        ; A row N = [-sP*cL, -sP*sL, cP]
        +multo sP, cL, matA
        +neg matA
        +multo sP, sL, matA+2
        +neg matA+2
        +copyw cP, matA+4
        ; A row E = [-sL, cL, 0]
        +copyw sL, matA+6
        +neg matA+6
        +copyw cL, matA+8
        lda #0
        sta matA+10
        sta matA+11
        ; A row U = [cP*cL, cP*sL, sP]
        +multo cP, cL, matA+12
        +multo cP, sL, matA+14
        +copyw sP, matA+16
        ; V row R = [-sA, cA, 0]
        +copyw sA, matV
        +neg matV
        +copyw cA, matV+2
        lda #0
        sta matV+4
        sta matV+5
        ; V row UP = [-sh*cA, -sh*sA, ch]
        +multo sh, cA, matV+6
        +neg matV+6
        +multo sh, sA, matV+8
        +neg matV+8
        +copyw ch, matV+10
        ; V row F = [ch*cA, ch*sA, sh]
        +multo ch, cA, matV+12
        +multo ch, sA, matV+14
        +copyw sh, matV+16
        ; M[i][j] = sum_k V[i][k]*A[k][j]
        lda #0
        sta t2                  ; i*6
--      lda #0
        sta t3                  ; j*2
-       lda #0
        sta acc
        sta acc+1
        sta acc+2
        sta acc+3
        ldx #0                  ; k
---     stx t6
        txa
        asl
        clc
        adc t2
        tay
        lda matV,y
        sta ma
        lda matV+1,y
        sta ma+1
        txa
        asl
        sta t7
        asl
        clc
        adc t7                  ; k*6
        adc t3
        tay
        lda matA,y
        sta mb
        lda matA+1,y
        sta mb+1
        jsr mul16s
        jsr addacc
        ldx t6
        inx
        cpx #3
        bne ---
        jsr accshift
        lda t2
        clc
        adc t3
        tay
        lda fres
        sta matM,y
        lda fres+1
        sta matM+1,y
        lda t3
        clc
        adc #2
        sta t3
        cmp #6
        bne -
        lda t2
        clc
        adc #6
        sta t2
        cmp #18
        bne --
        ldx #0
        ldy #0
-       lda matA+12,y
        cmp #$80
        lda matA+13,y
        adc #0
        sta qmat,x
        lda matM+12,y
        cmp #$80
        lda matM+13,y
        adc #0
        sta qmat+3,x
        lda matM,y
        cmp #$80
        lda matM+1,y
        adc #0
        sta qmat+6,x
        lda matM+6,y
        cmp #$80
        lda matM+7,y
        adc #0
        sta qmat+9,x
        iny
        iny
        inx
        cpx #3
        bne -
        rts

addacc  clc
        lda acc
        adc mr
        sta acc
        lda acc+1
        adc mr+1
        sta acc+1
        lda acc+2
        adc mr+2
        sta acc+2
        lda acc+3
        adc mr+3
        sta acc+3
        rts
accshift                        ; fres = acc >> 14
        lda acc+1
        sta t0
        lda acc+2
        sta fres
        lda acc+3
        sta fres+1
        asl t0
        rol fres
        rol fres+1
        asl t0
        rol fres
        rol fres+1
        rts

; =====================================================================
; math
; fast unsigned 16x16 -> 32 (quarter squares, self-modifying)
umul16  lda ma
        sta f1a+1
        sta f3a+1
        sta f1b+1
        sta f3b+1
        eor #$ff
        sta f2a+1
        sta f4a+1
        sta f2b+1
        sta f4b+1
        lda ma+1
        sta g1a+1
        sta g3a+1
        sta g1b+1
        sta g3b+1
        eor #$ff
        sta g2a+1
        sta g4a+1
        sta g2b+1
        sta g4b+1
        ldy mb
        sec
f1a     lda sqlo,y
f2a     sbc SQ2LO,y
        sta mr
f3a     lda sqhi,y
f4a     sbc SQ2HI,y
        sta mr+1
        sec
g1a     lda sqlo,y
g2a     sbc SQ2LO,y
        sta m8a
g3a     lda sqhi,y
g4a     sbc SQ2HI,y
        sta m8b
        ldy mb+1
        sec
f1b     lda sqlo,y
f2b     sbc SQ2LO,y
        sta m8p
f3b     lda sqhi,y
f4b     sbc SQ2HI,y
        sta m8p+1
        sec
g1b     lda sqlo,y
g2b     sbc SQ2LO,y
        sta mr+2
g3b     lda sqhi,y
g4b     sbc SQ2HI,y
        sta mr+3
        clc
        lda mr+1
        adc m8a
        sta mr+1
        lda mr+2
        adc m8b
        sta mr+2
        bcc +
        inc mr+3
+       clc
        lda mr+1
        adc m8p
        sta mr+1
        lda mr+2
        adc m8p+1
        sta mr+2
        bcc +
        inc mr+3
+       rts

gen_sq2 ldx #0
-       txa
        eor #$ff
        tay
        lda sqlo,y
        sta SQ2LO,x
        lda sqhi,y
        sta SQ2HI,x
        lda sqlo+1,x
        sta SQ2LO+256,x
        lda sqhi+1,x
        sta SQ2HI+256,x
        inx
        bne -
-       txa
        bpl +
        eor #$ff
        clc
        adc #1
+       tay
        lda sqlo,y
        sta SQSL,x
        lda sqhi,y
        sta SQSH,x
        inx
        bne -
        rts

; ---- quick 8-bit dot products (scale 4096 = 1.0) ----
mkqv    ldy #0
        ldx #0
-       lda (vp),y
        cmp #$80
        iny
        lda (vp),y
        adc #0
        sta qv,x
        iny
        inx
        cpx #3
        bne -
        rts
!macro qterm .m, .v, .first {
        lda .m
        clc
        adc .v
        tax
        lda .m
        sec
        sbc .v
        tay
!if .first {
        lda SQSL,x
        sec
        sbc SQSL,y
        sta qacc
        lda SQSH,x
        sbc SQSH,y
        sta qacc+1
} else {
        lda qacc
        clc
        adc SQSL,x
        sta qacc
        lda qacc+1
        adc SQSH,x
        sta qacc+1
        lda qacc
        sec
        sbc SQSL,y
        sta qacc
        lda qacc+1
        sbc SQSH,y
        sta qacc+1
}
}
qdotA   +qterm qmat, qv, 1
        +qterm qmat+1, qv+1, 0
        +qterm qmat+2, qv+2, 0
        rts
qdotM   +qterm qmat+3, qv, 1
        +qterm qmat+4, qv+1, 0
        +qterm qmat+5, qv+2, 0
        rts
qdotR   +qterm qmat+6, qv, 1
        +qterm qmat+7, qv+1, 0
        +qterm qmat+8, qv+2, 0
        rts
qdotU   +qterm qmat+9, qv, 1
        +qterm qmat+10, qv+1, 0
        +qterm qmat+11, qv+2, 0
        rts
; C=1 if |qacc| - 250 > ub * qw  (point is outside the screen box)
qbox    lda qacc+1
        bpl +
        lda #0
        sec
        sbc qacc
        sta qacc
        lda #0
        sbc qacc+1
        sta qacc+1
+       lda qacc
        sec
        sbc #250
        sta qacc
        lda qacc+1
        sbc #0
        sta qacc+1
        bcc ++                  ; within slack -> inside
        +copyw qw, ma
        jsr umul16
        lda mr+2
        cmp qacc
        lda mr+3
        sbc qacc+1              ; C=0 if prod < qacc
        bcc +
++      clc
        rts
+       sec
        rts

; full sky projection of vector at vp with horizon test
skyproj jsr mkqv
        jsr qdotA                ; quick altitude
        lda qacc
        cmp #<(-246)
        lda qacc+1
        sbc #>(-246)
        bvc +
        eor #$80
+       bmi .fail
        lda qacc
        cmp #<246
        lda qacc+1
        sbc #>246
        bvc +
        eor #$80
+       sta qabove
        jsr qdotM               ; quick depth
        lda qacc
        cmp qzmin
        lda qacc+1
        sbc qzmin+1
        bvc +
        eor #$80
+       bmi .fail
        lda qacc
        clc
        adc #<4096
        sta qw
        lda qacc+1
        adc #>4096
        sta qw+1
        jsr qdotR
        +copyw ubx, mb
        jsr qbox
        bcs .fail
        jsr qdotU
        +copyw uby, mb
        jsr qbox
        bcs .fail
        lda qabove
        bpl +
        lda #<(matA+12)
        sta rp
        lda #>(matA+12)
        sta rp+1
        jsr dot3
        lda fres+1
        bmi .fail
+       jmp projM
.fail   lda #0
        sta pflag
        rts

mul16s  jsr umul16
        lda ma+1
        bpl +
        lda mr+2
        sec
        sbc mb
        sta mr+2
        lda mr+3
        sbc mb+1
        sta mr+3
+       lda mb+1
        bpl +
        lda mr+2
        sec
        sbc ma
        sta mr+2
        lda mr+3
        sbc ma+1
        sta mr+3
+       rts

fixmul  jsr mul16s
shr14   lda mr+1
        sta t0
        lda mr+2
        sta fres
        lda mr+3
        sta fres+1
        asl t0
        rol fres
        rol fres+1
        asl t0
        rol fres
        rol fres+1
        rts

; dvd(32) / dvs(16) -> quotient dvd(16), needs dvd+2..3 < dvs
udiv    ldx #16
-       asl dvd
        rol dvd+1
        rol dvd+2
        rol dvd+3
        bcs +
        lda dvd+2
        cmp dvs
        lda dvd+3
        sbc dvs+1
        bcc ++
+       lda dvd+2
        sec
        sbc dvs
        sta dvd+2
        lda dvd+3
        sbc dvs+1
        sta dvd+3
        inc dvd
++      dex
        bne -
        rts

; dot product: rp -> row (3 words), vp -> vector (3 words); fres = result
dot3    lda #0
        sta acc
        sta acc+1
        sta acc+2
        sta acc+3
        ldy #0
-       lda (rp),y
        sta ma
        lda (vp),y
        sta mb
        iny
        lda (rp),y
        sta ma+1
        lda (vp),y
        sta mb+1
        iny
        sty t7
        jsr mul16s
        jsr addacc
        ldy t7
        cpy #6
        bne -
        jmp accshift

; set dvd = |ma| << 14 (ma >= 0)
setdvd  lda ma+1
        sta dvd+3
        lda ma
        sta dvd+2
        lda #0
        sta dvd+1
        sta dvd
        lsr dvd+3
        ror dvd+2
        ror dvd+1
        lsr dvd+3
        ror dvd+2
        ror dvd+1
        rts


; ---- matrix-specialised multiply for M (set up once per frame) ----------
ft0 = $0a
ft1 = $0b
ft2 = $0c
ft3 = $0d
ft4 = $0e
ft5 = $0f
facc = acc
!macro fterm .n, .off, .first, ~.su {
        ldy #.off
        lda (vp),y
        sta mb
        iny
        lda (vp),y
        sta mb+1
        tay
        sec
.a1     lda sqlo,y
.a2     sbc SQ2LO,y
        sta ft0
.a3     lda sqhi,y
.a4     sbc SQ2HI,y
        sta ft1
        sec
.b1     lda sqlo,y
.b2     sbc SQ2LO,y
        sta ft3
.b3     lda sqhi,y
.b4     sbc SQ2HI,y
        sta ft4
        ldy mb
        sec
.c1     lda sqlo,y
.c2     sbc SQ2LO,y
        sta ft5
.c3     lda sqhi,y
.c4     sbc SQ2HI,y
        tax
        lda ft0
        clc
        adc ft5
        sta ft0
        txa
        adc ft1
        sta ft1
        lda #0
        adc ft4
        sta ft2
        lda ft1
        clc
        adc ft3
        sta ft1
        bcc +
        inc ft2
+       lda mb+1
        bpl .bp
        lda ft1
        sec
        sbc fm_lo+.n
        sta ft1
        lda ft2
        sbc fm_hi+.n
        sta ft2
.bp
!if .first {
        lda fm_sg+.n
        bmi .neg1
        lda ft0
        sta facc
        lda ft1
        sta facc+1
        lda ft2
        sta facc+2
        jmp .end
.neg1   lda #0
        sec
        sbc ft0
        sta facc
        lda #0
        sbc ft1
        sta facc+1
        lda #0
        sbc ft2
        sta facc+2
        jmp .end
} else {
        lda fm_sg+.n
        bmi .sub
        lda facc
        clc
        adc ft0
        sta facc
        lda facc+1
        adc ft1
        sta facc+1
        lda facc+2
        adc ft2
        sta facc+2
        jmp .end
.sub    lda facc
        sec
        sbc ft0
        sta facc
        lda facc+1
        sbc ft1
        sta facc+1
        lda facc+2
        sbc ft2
        sta facc+2
        jmp .end
}
.su     lda matM+2*.n
        ldx matM+2*.n+1
        ldy #0
        cpx #$80
        bcc .st
        eor #$ff
        clc
        adc #1
        pha
        txa
        eor #$ff
        adc #0
        tax
        pla
        ldy #$ff
.st     sty fm_sg+.n
        sta fm_lo+.n
        stx fm_hi+.n
        sta .a1+1
        sta .a3+1
        eor #$ff
        sta .a2+1
        sta .a4+1
        txa
        sta .b1+1
        sta .b3+1
        sta .c1+1
        sta .c3+1
        eor #$ff
        sta .b2+1
        sta .b4+1
        sta .c2+1
        sta .c4+1
        rts
.end
}
fdotR   +fterm 0, 0, 1, ~fsu0
        +fterm 1, 2, 0, ~fsu1
        +fterm 2, 4, 0, ~fsu2
        jmp fdone
fdotU   +fterm 3, 0, 1, ~fsu3
        +fterm 4, 2, 0, ~fsu4
        +fterm 5, 4, 0, ~fsu5
        jmp fdone
fdotF   +fterm 6, 0, 1, ~fsu6
        +fterm 7, 2, 0, ~fsu7
        +fterm 8, 4, 0, ~fsu8
fdone   asl facc
        rol facc+1
        rol facc+2
        asl facc
        rol facc+1
        rol facc+2
        lda facc+1
        sta fres
        lda facc+2
        sta fres+1
        rts
fsetup  jsr fsu0
        jsr fsu1
        jsr fsu2
        jsr fsu3
        jsr fsu4
        jsr fsu5
        jsr fsu6
        jsr fsu7
        jmp fsu8

; projection through M using the specialised multiplies
projM   jsr fdotF
        lda fres
        sta pD
        lda fres+1
        clc
        adc #$40
        sta pD+1
        lda pD
        cmp dmin
        lda pD+1
        sbc dmin+1
        bcs +
        jmp pfail
+       jsr fdotR
        +copyw fres, pX
        jsr fdotU
        +copyw fres, pY
        jmp ptail

; =====================================================================
; projection of vector at vp through matrix at mp (rows R,UP,F)
; out: sx, sy (signed 16), pflag: $80 valid, $40 on screen
project lda mp
        clc
        adc #12
        sta rp
        lda mp+1
        adc #0
        sta rp+1
        jsr dot3                ; Z
        lda fres
        sta pD
        lda fres+1
        clc
        adc #$40
        sta pD+1                ; D = 1 + Z  (0..32768)
        lda pD
        cmp dmin
        lda pD+1
        sbc dmin+1
        bcs *+5
        jmp pfail
        lda mp
        sta rp
        lda mp+1
        sta rp+1
        jsr dot3
        +copyw fres, pX
        lda mp
        clc
        adc #6
        sta rp
        lda mp+1
        adc #0
        sta rp+1
        jsr dot3
        +copyw fres, pY
ptail   ; KD = (K << 18) / D
        lda #0
        sta dvd
        sta dvd+1
        lda kd2
        sta dvd+2
        lda kd3
        sta dvd+3
        +copyw pD, dvs
        jsr udiv
        +copyw dvd, mb
        +copyw pX, ma
        jsr mul16s
        jsr shr18
        lda res
        clc
        adc #160
        sta sx
        lda res+1
        adc #0
        sta sx+1
        +copyw pY, ma
        jsr mul16s
        jsr shr18
        lda #96
        sec
        sbc res
        sta sy
        lda #0
        sbc res+1
        sta sy+1
        lda #$80
        sta pflag
        lda sx+1
        beq +
        cmp #1
        bne pdone
        lda sx
        cmp #64
        bcs pdone
+       lda sy+1
        bne pdone
        lda sy
        cmp #192
        bcs pdone
        lda #$c0
        sta pflag
pdone   rts
pfail   lda #0
        sta pflag
        rts

; res = mr >> 18 (signed)
shr18   lda mr+3
        cmp #$80
        ror
        sta res+1
        lda mr+2
        ror
        sta res
        lda res+1
        cmp #$80
        ror res+1
        ror res
        rts

; =====================================================================
clear_bitmap
        lda #<BITMAP
        sta bp
        lda #>BITMAP
        sta bp+1
        lda #0
        ldx #31
        ldy #0
-       sta (bp),y
        iny
        bne -
        inc bp+1
        dex
        bne -
-       sta (bp),y              ; last partial page ($fe00-$ff3f)
        iny
        cpy #$40
        bne -
        rts

sun_check                       ; daytime -> blue sky
        lda #<(matA+12)
        sta rp
        lda #>(matA+12)
        sta rp+1
        lda #<planets
        sta vp
        lda #>planets
        sta vp+1
        jsr dot3
        lda #$10
        ldx fres+1
        bmi +
        lda #$16
+       sta skycol
        rts

; ---- per-cell sky/ground colours --------------------------------------
; ground where B(row) < Q(col): sign of the altitude of the inverse-projected
; cell centre, s = 2W*cos(h) + (1-U^2-W^2)*sin(h), U=dx/K, W=-dy/K
fill_colors
        ; Q(col) for 40 columns: dx = 8c-156
        ldx #0
-       stx t6
        stx ma
        lda #0
        sta ma+1
        asl ma
        rol ma+1
        asl ma
        rol ma+1
        asl ma
        rol ma+1
        lda ma
        sec
        sbc #156
        sta ma
        lda ma+1
        sbc #0
        sta ma+1                ; signed dx
        jsr divk                ; res = dx*16384/K
        +copyw res, ma
        +copyw res, mb
        jsr fixmul              ; U^2
        +copyw fres, ma
        +copyw sh, mb
        jsr fixmul
        ldx t6
        lda fres
        sta Qlo,x
        lda fres+1
        sta Qhi,x
        inx
        cpx #40
        bne -
        lda #<SCREEN
        sta cp
        lda #>SCREEN
        sta cp+1
        lda #0
        sta t6                  ; row
--      lda t6                  ; dy = 8r-92 ; W = -dy
        asl
        asl
        asl
        sta t0
        lda #92
        sec
        sbc t0
        sta ma
        lda #0
        sbc #0
        sta ma+1
        jsr divk                ; W
        +copyw res, tmpw2
        +multo tmpw2, ch, tmpw  ; W*ch
        asl tmpw
        rol tmpw+1              ; 2*W*ch
        +multo tmpw2, tmpw2, ma ; W^2
        lda #0
        sec
        sbc ma
        sta ma
        lda #$40
        sbc ma+1
        sta ma+1                ; 1 - W^2
        +copyw sh, mb
        jsr fixmul
        lda fres
        clc
        adc tmpw
        sta tmpw
        lda fres+1
        adc tmpw+1
        sta tmpw+1              ; B
        ldy #0
-       lda tmpw                ; B < Q ?  (signed)
        cmp Qlo,y
        lda tmpw+1
        sbc Qhi,y
        bvc +
        eor #$80
+       bmi +
        lda skycol
        bne ++
+       lda #$19
++      sta (cp),y
        iny
        cpy #40
        bne -
        lda cp
        clc
        adc #40
        sta cp
        bcc +
        inc cp+1
+       inc t6
        lda t6
        cmp #24
        beq *+5
        jmp --
        ldy #39
        lda #$1b                ; status bar: white on dark grey
-       sta (cp),y
        dey
        bpl -
        rts

; res = ma(signed pixels) * 16384 / K
divk    lda ma+1
        sta sgn
        bpl +
        +neg ma
+       jsr setdvd
        +copyw kval, dvs
        jsr udiv
        +copyw dvd, res
        lda sgn
        bpl +
        +neg res
+       rts

; =====================================================================
; horizon: 60 points, view matrix
draw_horizon
        lda #0
        sta dotted
        sta hprevf
        sta hvec+4
        sta hvec+5
        sta t3                  ; point counter
-       lda t3
        sta ma
        lda #0
        sta ma+1
        lda #<1638
        sta mb
        lda #>1638
        sta mb+1
        jsr umul16
        lda mr
        sta tmpw
        lda mr+1
        sta tmpw+1
        jsr getcos
        +copyw sres, hvec
        lda t3
        sta ma
        lda #0
        sta ma+1
        jsr umul16
        lda mr
        sta tmpw
        lda mr+1
        sta tmpw+1
        jsr getsin
        +copyw sres, hvec+2
        lda #<hvec
        sta vp
        lda #>hvec
        sta vp+1
        lda #<matV
        sta mp
        lda #>matV
        sta mp+1
        jsr project
        lda pflag
        bpl +++
        lda hprevf
        bpl ++
        +copyw hprevx, lx0
        +copyw hprevy, ly0
        +copyw sx, lx1
        +copyw sy, ly1
        jsr clipline
++      +copyw sx, hprevx
        +copyw sy, hprevy
+++     lda pflag
        sta hprevf
        inc t3
        lda t3
        cmp #41
        beq *+5
        jmp -
        rts

; =====================================================================
project_stars
        lda #<stars
        sta sp0
        lda #>stars
        sta sp0+1
        lda #<OUTBUF
        sta op
        lda #>OUTBUF
        sta op+1
        lda #<zones
        sta zp_
        lda #>zones
        sta zp_+1
        lda #NZONES
        sta zcnt
.zone   ldy #10
        lda (zp_),y
        sta cnt                 ; stars in this zone
        lda zp_
        sta vp
        lda zp_+1
        sta vp+1
        jsr mkqv
        jsr qdotA               ; centre altitude vs -sin(r)
        ldy #8
        lda qacc
        cmp (zp_),y
        iny
        lda qacc+1
        sbc (zp_),y
        bvc +
        eor #$80
+       bmi .cull
        jsr qdotM               ; centre depth vs cos(cone + r)
        ldy #6
        lda (zp_),y
        clc
        adc zcone
        sta tmpw
        iny
        lda (zp_),y
        adc zcone+1
        sta tmpw+1
        bmi .vis                ; cone + r >= 180 deg
        jsr getcos
        lda sres+1              ; s1.14 -> q scale (>>2), minus slack
        cmp #$80
        ror
        sta tmpw2+1
        lda sres
        ror
        sta tmpw2
        lda tmpw2+1
        cmp #$80
        ror tmpw2+1
        ror tmpw2
        lda tmpw2
        sec
        sbc #<260
        sta tmpw2
        lda tmpw2+1
        sbc #>260
        sta tmpw2+1
        lda qacc
        cmp tmpw2
        lda qacc+1
        sbc tmpw2+1
        bvc +
        eor #$80
+       bmi .cull
.vis    lda sp0
        sta vp
        lda sp0+1
        sta vp+1
        jsr skyproj
        ldy #0
        lda sx
        sta (op),y
        iny
        lda sx+1
        sta (op),y
        iny
        lda sy
        sta (op),y
        iny
        lda sy+1
        sta (op),y
        iny
        lda pflag
        sta (op),y
        jsr advstar
        dec cnt
        bne .vis
        jmp .znext
.cull   ldy #4
        lda #0
        sta (op),y
        jsr advstar
        dec cnt
        bne .cull
.znext  lda zp_
        clc
        adc #11
        sta zp_
        bcc +
        inc zp_+1
+       dec zcnt
        beq +
        jmp .zone
+       rts
advstar lda sp0
        clc
        adc #7
        sta sp0
        bcc +
        inc sp0+1
+       lda op
        clc
        adc #5
        sta op
        bcc +
        inc op+1
+       rts

; op = OUTBUF + tmpw*5
recaddr lda tmpw
        sta op
        lda tmpw+1
        sta op+1
        asl op
        rol op+1
        asl op
        rol op+1
        lda op
        clc
        adc tmpw
        sta op
        lda op+1
        adc tmpw+1
        clc
        adc #>OUTBUF
        sta op+1
        rts

draw_lines
        lda #1
        sta dotted
        lda #<segs
        sta ip
        lda #>segs
        sta ip+1
        lda #<NSEGS
        sta cnt
        lda #>NSEGS
        sta cnt+1
--      ldy #0
        lda (ip),y
        sta tmpw
        iny
        lda (ip),y
        sta tmpw+1
        jsr recaddr
        ldy #4
        lda (op),y
        bpl +
        ldy #0
        lda (op),y
        sta lx0
        iny
        lda (op),y
        sta lx0+1
        iny
        lda (op),y
        sta ly0
        iny
        lda (op),y
        sta ly0+1
        ldy #2
        lda (ip),y
        sta tmpw
        iny
        lda (ip),y
        sta tmpw+1
        jsr recaddr
        ldy #4
        lda (op),y
        bpl +
        ldy #0
        lda (op),y
        sta lx1
        iny
        lda (op),y
        sta lx1+1
        iny
        lda (op),y
        sta ly1
        iny
        lda (op),y
        sta ly1+1
        lda ip
        pha
        lda ip+1
        pha
        jsr clipline
        pla
        sta ip+1
        pla
        sta ip
+       lda ip
        clc
        adc #4
        sta ip
        bcc +
        inc ip+1
+       lda cnt
        bne +
        dec cnt+1
+       dec cnt
        lda cnt
        ora cnt+1
        bne --
        lda #0
        sta dotted
        rts

; ---- line clipping by midpoint subdivision ------------------------------
!zone
clipline
        lda #0
        sta segsp
        jsr pushseg
.next   lda segsp
        bne +
        rts
+       jsr popseg
        +copyw lx0, tmpw
        +copyw ly0, tmpw2
        jsr outcode
        sta oc0
        +copyw lx1, tmpw
        +copyw ly1, tmpw2
        jsr outcode
        sta oc1
        ora oc0
        bne +
        jsr bres
        jmp .next
+       lda oc0
        and oc1
        bne .next
        ; small?  |dx|<2 and |dy|<2
        lda lx1
        sec
        sbc lx0
        sta t0
        lda lx1+1
        sbc lx0+1
        jsr small
        bcc .split
        lda ly1
        sec
        sbc ly0
        sta t0
        lda ly1+1
        sbc ly0+1
        jsr small
        bcc .split
        jmp .next
.split  ; midpoint
        lda lx0
        clc
        adc lx1
        sta tmpw
        lda lx0+1
        adc lx1+1
        sta tmpw+1
        cmp #$80
        ror tmpw+1
        ror tmpw
        lda ly0
        clc
        adc ly1
        sta tmpw2
        lda ly0+1
        adc ly1+1
        sta tmpw2+1
        cmp #$80
        ror tmpw2+1
        ror tmpw2
        ; push (mid -> p1) and (p0 -> mid)
        lda segsp
        cmp #MAXSEG-2
        bcc *+5
        jmp .next
        +copyw lx0, sv0         ; save p0
        +copyw ly0, sv1
        +copyw tmpw, lx0
        +copyw tmpw2, ly0
        jsr pushseg             ; mid -> p1
        +copyw sv0, lx0
        +copyw sv1, ly0
        +copyw tmpw, lx1
        +copyw tmpw2, ly1
        jsr pushseg             ; p0 -> mid
        jmp .next

; C=1 if 16-bit (A:hi, t0:lo) value is in -1..1
small   cmp #0
        beq +
        cmp #$ff
        bne ++
        lda t0
        cmp #$ff
        beq +++
        clc
        rts
+       lda t0
        cmp #2
        bcs ++
+++     sec
        rts
++      clc
        rts

pushseg lda segsp
        asl
        asl
        asl
        tax
        ldy #0
-       lda lx0,y
        sta SEGSTK,x
        inx
        iny
        cpy #8
        bne -
        inc segsp
        rts
popseg  dec segsp
        lda segsp
        asl
        asl
        asl
        tax
        ldy #0
-       lda SEGSTK,x
        sta lx0,y
        inx
        iny
        cpy #8
        bne -
        rts

; outcode of (tmpw, tmpw2)
!zone
outcode lda #0
        sta t6
        lda tmpw+1
        bpl +
        lda #1
        sta t6
        jmp .y
+       cmp #2
        bcs .r
        cmp #1
        bne .y
        lda tmpw
        cmp #64
        bcc .y
.r      lda #2
        sta t6
.y      lda tmpw2+1
        bpl +
        lda t6
        ora #4
        sta t6
        jmp .d
+       bne .b
        lda tmpw2
        cmp #192
        bcc .d
.b      lda t6
        ora #8
        sta t6
.d      lda t6
        rts

; ---- Bresenham (both endpoints on screen) --------------------------------
!zone
!macro xstep {
        lda lsx
        bmi .l
        lsr lmask
        bcc .d
        ror lmask
        lda bp
        clc
        adc #8
        sta bp
        bcc .d
        inc bp+1
        bcs .d
.l      asl lmask
        bcc .d
        rol lmask
        lda bp
        sec
        sbc #8
        sta bp
        bcs .d
        dec bp+1
.d
}
!macro ystep {
        lda lsy
        bmi .u
        inc lyl
        lda lyl
        cmp #8
        bne .in
        lda #0
        sta lyl
        lda bp
        clc
        adc #<313
        sta bp
        lda bp+1
        adc #>313
        sta bp+1
        jmp .d
.in     inc bp
        bne .d
        inc bp+1
        jmp .d
.u      lda lyl
        bne .in2
        lda #7
        sta lyl
        lda bp
        sec
        sbc #<313
        sta bp
        lda bp+1
        sbc #>313
        sta bp+1
        jmp .d
.in2    dec lyl
        lda bp
        bne .nb
        dec bp+1
.nb     dec bp
.d
}
!macro lplot {
        lda dotted
        beq .pl
        lda dotc
        eor #1
        sta dotc
        bne .s
.pl     ldy #0
        lda (bp),y
        ora lmask
        sta (bp),y
.s
}
bres    lda lx1
        sec
        sbc lx0
        sta ldx_
        lda lx1+1
        sbc lx0+1
        sta ldx_+1
        ldx #1
        bcs +
        +neg ldx_
        ldx #$ff
+       stx lsx
        lda ly1
        sec
        sbc ly0
        ldx #1
        bcs +
        eor #$ff
        adc #1
        ldx #$ff
+       sta ldy_
        stx lsy
        ; start address and mask
        ldy ly0
        lda ytlo,y
        sta bp
        lda ythi,y
        sta bp+1
        lda lx0
        and #$f8
        clc
        adc bp
        sta bp
        lda lx0+1
        adc bp+1
        sta bp+1
        lda lx0
        and #7
        tax
        lda bitt,x
        sta lmask
        lda ly0
        and #7
        sta lyl
        ; major axis?
        lda ldx_+1
        bne .xmaj
        lda ldx_
        cmp ldy_
        bcs .xmaj
        jmp .ymaj
.xmaj   lda ldx_                ; count = dx+1, err = dx/2
        clc
        adc #1
        sta lcnt
        lda ldx_+1
        adc #0
        sta lcnt+1
        lda ldx_+1
        lsr
        sta lerr+1
        lda ldx_
        ror
        sta lerr
.xl     +lplot
        +xstep
        lda lerr
        sec
        sbc ldy_
        sta lerr
        lda lerr+1
        sbc #0
        sta lerr+1
        bpl +
        lda lerr
        clc
        adc ldx_
        sta lerr
        lda lerr+1
        adc ldx_+1
        sta lerr+1
        +ystep
+       lda lcnt
        bne +
        dec lcnt+1
+       dec lcnt
        lda lcnt
        ora lcnt+1
        beq +
        jmp .xl
+       rts
.ymaj   ldx ldy_                ; count = dy+1, err = dy/2 (8-bit)
        inx
        stx lcnt
        lda ldy_
        lsr
        sta lerr
.yl     +lplot
        +ystep
        lda lerr
        sec
        sbc ldx_
        sta lerr
        bcs +
        adc ldy_
        sta lerr
        +xstep
+       dec lcnt
        beq +
        jmp .yl
+       rts

; ---- pixel plotting ------------------------------------------------------
plotfast
        ldy py
        lda ytlo,y
        sta bp
        lda ythi,y
        sta bp+1
        lda px
        and #$f8
        clc
        adc bp
        sta bp
        lda px+1
        adc bp+1
        sta bp+1
        lda px
        and #7
        tax
        ldy #0
        lda (bp),y
        ora bitt,x
        sta (bp),y
        rts

; px, py signed 16-bit; plot if on screen (y < 192)
plotchk lda px+1
        bmi +
        beq ++
        cmp #1
        bne +
        lda px
        cmp #64
        bcs +
++      lda py+1
        bne +
        lda py
        cmp #192
        bcs +
        jmp plotfast
+       rts

; draw pattern (pat) at sx, sy
drawpat ldy #0
        lda (pat),y
        sta t7
        iny
-       lda (pat),y
        sta t0
        ldx #0
        cmp #$80
        bcc +
        dex
+       clc
        adc sx
        sta px
        txa
        adc sx+1
        sta px+1
        iny
        lda (pat),y
        sta t0
        ldx #0
        cmp #$80
        bcc +
        dex
+       clc
        adc sy
        sta py
        txa
        adc sy+1
        sta py+1
        iny
        sty t6
        jsr plotchk
        ldy t6
        dec t7
        bne -
        rts

; =====================================================================
!zone
draw_stars
        lda #<stars
        sta sp0
        lda #>stars
        sta sp0+1
        lda #<OUTBUF
        sta op
        lda #>OUTBUF
        sta op+1
        lda #<NSTARS
        sta cnt
        lda #>NSTARS
        sta cnt+1
--      ldy #4
        lda (op),y
        and #$40
        beq .skip
        ldy #6
        lda (sp0),y
        cmp maglim
        bcs .skip
        ldx #0
        cmp #25
        bcc +
        inx
        cmp #35
        bcc +
        inx
        cmp #45
        bcc +
        inx
        cmp #53
        bcc +
        inx
+       lda pattab,x
        sta pat
        lda pattab+5,x
        sta pat+1
        ldy #0
        lda (op),y
        sta sx
        iny
        lda (op),y
        sta sx+1
        iny
        lda (op),y
        sta sy
        iny
        lda (op),y
        sta sy+1
        jsr drawpat
.skip   lda sp0
        clc
        adc #7
        sta sp0
        bcc +
        inc sp0+1
+       lda op
        clc
        adc #5
        sta op
        bcc +
        inc op+1
+       lda cnt
        bne +
        dec cnt+1
+       dec cnt
        lda cnt
        ora cnt+1
        bne --
        rts
pattab  !byte <pat0,<pat1,<pat2,<pat3,<pat4
        !byte >pat0,>pat1,>pat2,>pat3,>pat4

; =====================================================================
!zone
draw_planets
        lda #6
        sta t3
--      lda t3
        asl
        sta t0
        asl
        clc
        adc t0
        adc #<planets
        sta vp
        lda #>planets
        adc #0
        sta vp+1
        jsr skyproj
        bit pflag
        bvc .nxt
        ldx t3
        lda plpatlo,x
        sta pat
        lda plpathi,x
        sta pat+1
        jsr drawpat
        ldx t3
        lda plnamlo,x
        sta strp
        lda plnamhi,x
        sta strp+1
        lda #$70
        sta ccol
        jsr labelright
.nxt    dec t3
        bpl --
        rts
plpatlo !byte <patsun,<patmoon,<patpl,<patpl,<patpl,<patpl,<patpl
plpathi !byte >patsun,>patmoon,>patpl,>patpl,>patpl,>patpl,>patpl
plnamlo !byte <pn0,<pn1,<pn2,<pn3,<pn4,<pn5,<pn6
plnamhi !byte >pn0,>pn1,>pn2,>pn3,>pn4,>pn5,>pn6

; label to the right of (sx, sy)
labelright
        lda sx
        clc
        adc #6
        sta tmpw
        lda sx+1
        adc #0
        lsr
        lda tmpw
        ror
        lsr
        lsr
        sta cx
        lda sy
        sec
        sbc #3
        bcs +
        lda #0
+       lsr
        lsr
        lsr
        sta cy
        cmp #24
        bcs +
        jmp drawtext
+       rts

; label centred on (sx, sy)
labelcentre
        jsr strlen
        lsr
        sta t0
        lda sx+1
        lsr
        lda sx
        ror
        lsr
        lsr
        sec
        sbc t0
        sta cx
        lda sy
        lsr
        lsr
        lsr
        sta cy
        cmp #24
        bcs +
        jmp drawtext
+       rts

clear_occ
        lda #0
        ldx #0
-       sta OCC,x
        sta OCC+256,x
        sta OCC+512,x
        sta OCC+744,x
        inx
        bne -
        rts

; check cells cx-1 .. cx+len on row cy; C=1 if any used, else mark them
occtest jsr strlen
        clc
        adc #2
        sta t6                  ; cells to test
        ldx cy
        lda scrlo,x
        sta ip
        lda scrhi,x
        sec
        sbc #>(SCREEN-OCC)
        sta ip+1
        ldx cx
        dex
        stx t7
        lda t6
        sta t2
-       ldy t7
        cpy #40
        bcs +
        lda (ip),y
        beq +
        sec
        rts
+       inc t7
        dec t2
        bne -
        ldx cx
        dex
        stx t7
-       ldy t7
        cpy #40
        bcs +
        lda #1
        sta (ip),y
+       inc t7
        dec t6
        bne -
        clc
        rts

strlen  ldy #0
-       lda (strp),y
        beq +
        iny
        bne -
+       tya
        rts

; draw string strp at cell cx (signed), cy; colour ccol (fg nibble)
!zone
drawtext
        lda cy
        cmp #25
        bcc *+5
        jmp .done
        lda occchk
        beq .go
        jsr occtest
        bcc .go
        rts
.go
-       ldy #0
        lda (strp),y
        bne *+5
        jmp .done
        lda cx
        cmp #40
        bcs .skip               ; also skips negative (>=128)
        ; bitmap address
        lda cy
        asl
        asl
        asl
        tay
        lda ytlo,y
        sta bp
        lda ythi,y
        sta bp+1
        lda cx
        asl
        asl
        asl
        sta t0
        lda cx
        lsr
        lsr
        lsr
        lsr
        lsr
        sta t1
        lda bp
        clc
        adc t0
        sta bp
        lda bp+1
        adc t1
        sta bp+1
        ; font pointer
        ldy #0
        lda (strp),y
        sec
        sbc #32
        sta fp
        lda #0
        sta fp+1
        asl fp
        rol fp+1
        asl fp
        rol fp+1
        asl fp
        rol fp+1
        lda fp
        clc
        adc #<font
        sta fp
        lda fp+1
        adc #>font
        sta fp+1
        ldy #7
--      lda (fp),y
        ora (bp),y
        sta (bp),y
        dey
        bpl --
        ; colour cell
        ldx cy
        lda scrlo,x
        clc
        adc cx
        sta bp
        lda scrhi,x
        adc #0
        sta bp+1
        ldy #0
        lda (bp),y
        and #$0f
        ora ccol
        sta (bp),y
.skip   inc cx
        inc strp
        beq *+5
        jmp -
        inc strp+1
        jmp -
.done   rts

; =====================================================================
!zone
draw_conlabels
        lda #<conlab
        sta sp0
        lda #>conlab
        sta sp0+1
        lda #NCONS
        sta t3
--      lda sp0
        sta vp
        lda sp0+1
        sta vp+1
        jsr skyproj
        bit pflag
        bvc .nxt
        ldy #6
        lda (sp0),y
        sta strp
        iny
        lda (sp0),y
        sta strp+1
        lda #$e0
        ldx skycol
        cpx #$10
        beq +
        lda #$30                ; cyan on daytime blue sky
+       sta ccol
        jsr labelcentre
.nxt    lda sp0
        clc
        adc #8
        sta sp0
        bcc +
        inc sp0+1
+       dec t3
        bne --
        rts

!zone
draw_starlabels
        lda #<starlab
        sta ip
        lda #>starlab
        sta ip+1
        lda #NNAMED
        sta t3
--      ldy #0
        lda (ip),y
        sta tmpw
        iny
        lda (ip),y
        sta tmpw+1
        jsr recaddr
        ldy #4
        lda (op),y
        and #$40
        beq .nxt
        ldy #0
        lda (op),y
        sta sx
        iny
        lda (op),y
        sta sx+1
        iny
        lda (op),y
        sta sy
        iny
        lda (op),y
        sta sy+1
        ldy #2
        lda (ip),y
        sta strp
        iny
        lda (ip),y
        sta strp+1
        lda #$f0
        sta ccol
        lda ip
        pha
        lda ip+1
        pha
        jsr labelright
        pla
        sta ip+1
        pla
        sta ip
.nxt    lda ip
        clc
        adc #4
        sta ip
        bcc +
        inc ip+1
+       dec t3
        bne --
        rts

!zone
draw_cardinals
        lda #0
        sta t3
        sta hvec+4
        sta hvec+5
--      lda t3
        asl
        asl
        asl
        asl
        asl
        sta tmpw+1              ; az = k*45 deg = k*$2000
        lda #0
        sta tmpw
        jsr getcos
        +copyw sres, hvec
        lda t3
        asl
        asl
        asl
        asl
        asl
        sta tmpw+1
        lda #0
        sta tmpw
        jsr getsin
        +copyw sres, hvec+2
        lda #<hvec
        sta vp
        lda #>hvec
        sta vp+1
        lda #<matV
        sta mp
        lda #>matV
        sta mp+1
        jsr project
        bit pflag
        bvc .nxt
        ldx t3
        lda cardlo,x
        sta strp
        lda cardhi,x
        sta strp+1
        lda sy
        clc
        adc #8
        sta sy
        lda #$70
        sta ccol
        jsr labelcentre
.nxt    inc t3
        lda t3
        cmp #8
        bne --
        rts
cardlo  !byte <cd0,<cd1,<cd2,<cd3,<cd4,<cd5,<cd6,<cd7
cardhi  !byte >cd0,>cd1,>cd2,>cd3,>cd4,>cd5,>cd6,>cd7
!if LANG = 0 {
cd0     !text "S",0
cd1     !text "SV",0
cd2     !text "V",0
cd3     !text "JV",0
cd4     !text "J",0
cd5     !text "JZ",0
cd6     !text "Z",0
cd7     !text "SZ",0
} else {
cd0     !text "N",0
cd1     !text "NE",0
cd2     !text "E",0
cd3     !text "SE",0
cd4     !text "S",0
cd5     !text "SW",0
cd6     !text "W",0
cd7     !text "NW",0
}

; =====================================================================
; status line:  "JV 135@ VYSKA +25@ POLE 120@ 23:47 +1D*"
draw_status
        ldx #39
        lda #' '
-       sta sbuf,x
        dex
        bpl -
        lda #0
        sta sbuf+40
        ; direction name from az (nearest 45 deg)
        lda az+1
        clc
        adc #$10
        lsr
        lsr
        lsr
        lsr
        lsr
        tax
        lda cardlo,x
        sta strp
        lda cardhi,x
        sta strp+1
        ldy #0
        lda (strp),y
        sta sbuf
        iny
        lda (strp),y
        beq +
        sta sbuf+1
+       ; azimuth degrees = (az*360 + 32768) >> 16
        +copyw az, ma
        lda #<360
        sta mb
        lda #>360
        sta mb+1
        jsr umul16
        lda mr+1
        clc
        adc #$80
        lda mr+2
        adc #0
        sta tmpw
        lda mr+3
        adc #0
        sta tmpw+1
        lda tmpw                ; 360 -> 0
        cmp #<360
        lda tmpw+1
        sbc #>360
        bcc +
        lda #0
        sta tmpw
        sta tmpw+1
+       ldx #ST_AZ
        jsr num3
        lda #'@'
        sta sbuf+ST_AZ+3
        ; altitude "VÝŠ+30@" / "ALT+30@"
        lda #ALT1
        sta sbuf+ST_ALT
        lda #ALT2
        sta sbuf+ST_ALT+1
        lda #ALT3
        sta sbuf+ST_ALT+2
        +copyw alt, ma
        lda #'+'
        sta sbuf+ST_ALT+3
        lda alt+1
        bpl +
        lda #'-'
        sta sbuf+ST_ALT+3
        +neg ma
+       lda #<360
        sta mb
        lda #>360
        sta mb+1
        jsr umul16
        lda mr+1
        clc
        adc #$80
        lda mr+2
        adc #0
        sta tmpw
        lda #0
        sta tmpw+1
        ldx #ST_ALT+4
        jsr num2z
        lda #'@'
        sta sbuf+ST_ALT+6
        ; field of view "ZP 90@" / "FOV 90@"
        lda #FOV1
        sta sbuf+ST_FOV
        lda #FOV2
        sta sbuf+ST_FOV+1
!if LANG = 1 {
        lda #'V'
        sta sbuf+ST_FOV+2
}
        ldx zoom
        lda zfov,x
        sta tmpw
        lda #0
        sta tmpw+1
        ldx #18
        jsr num3
        lda #'@'
        sta sbuf+21
        ; clock = basemin + offmin, day offset in t3
        lda basemin
        clc
        adc offmin
        sta tmpw
        lda basemin+1
        adc offmin+1
        sta tmpw+1
        lda #0
        sta t3
-       lda tmpw+1
        bpl +
        lda tmpw
        clc
        adc #<1440
        sta tmpw
        lda tmpw+1
        adc #>1440
        sta tmpw+1
        dec t3
        jmp -
+       nop
-       lda tmpw
        cmp #<1440
        lda tmpw+1
        sbc #>1440
        bcc +
        lda tmpw
        sbc #<1440
        sta tmpw
        lda tmpw+1
        sbc #>1440
        sta tmpw+1
        inc t3
        jmp -
+       ldx #0                  ; hours = tmpw/60
-       lda tmpw
        cmp #60
        lda tmpw+1
        sbc #0
        bcc +
        lda tmpw
        sbc #60
        sta tmpw
        lda tmpw+1
        sbc #0
        sta tmpw+1
        inx
        jmp -
+       lda tmpw
        pha
        stx tmpw
        lda #0
        sta tmpw+1
        ldx #34
        jsr num2z
        lda #':'
        sta sbuf+36
        pla
        sta tmpw
        ldx #37
        jsr num2z
        lda offmin
        ora offmin+1
        beq +
        lda #'*'
        sta sbuf+39
+       ; date = base date + t3 days
        lda pday
        sta dday
        lda pmon
        sta dmon
        +copyw pyear, dyear
-       lda t3
        beq ++
        bmi +
        jsr nextday
        dec t3
        jmp -
+       jsr prevday
        inc t3
        jmp -
++      lda dday
        sta tmpw
        ldx #DP_D
        jsr num2z
        lda #DSEP
!if LANG = 0 {
        sta sbuf+25
        sta sbuf+28
} else {
        sta sbuf+27
        sta sbuf+30
}
        lda dmon
        sta tmpw
        ldx #DP_M
        jsr num2z
        +copyw dyear, tmpw      ; year: century, then 2 digits
        ldy #0
-       lda tmpw
        cmp #100
        lda tmpw+1
        sbc #0
        bcc +
        lda tmpw
        sbc #100
        sta tmpw
        lda tmpw+1
        sbc #0
        sta tmpw+1
        iny
        bne -
+       lda tmpw
        pha
        sty tmpw
        ldx #DP_Y
        jsr num2z
        pla
        sta tmpw
        ldx #DP_Y+2
        jsr num2z
statusout
        lda #<sbuf
        sta strp
        lda #>sbuf
        sta strp+1
        lda #0
        sta cx
        lda #24
        sta cy
        lda #$10
        sta ccol
        jmp drawtext

; ---- calendar helpers (1901-2099) ----
mdays   ldx dmon
        lda mdtab-1,x
        cpx #2
        bne +
        lda dyear
        and #3
        bne ++
        lda #29
        rts
++      lda #28
+       rts
mdtab   !byte 31,28,31,30,31,30,31,31,30,31,30,31
nextday inc dday
        jsr mdays
        cmp dday
        bcs +
        lda #1
        sta dday
        inc dmon
        lda dmon
        cmp #13
        bcc +
        lda #1
        sta dmon
        inc dyear
        bne +
        inc dyear+1
+       rts
prevday dec dday
        bne +
        dec dmon
        bne ++
        lda #12
        sta dmon
        lda dyear
        bne +++
        dec dyear+1
+++     dec dyear
++      jsr mdays
        sta dday
+       rts

; =====================================================================
; object search
!zone
k_find  lda #0
        sta flen
.redraw jsr showinput
.key    jsr GETIN
        cmp #0
        beq .key
        cmp #$0d
        beq .go
        cmp #$03                ; RUN/STOP
        beq .cancel
        cmp #$5f                ; <- key
        beq .cancel
        cmp #$14                ; DEL
        bne +
        ldx flen
        beq .key
        dec flen
        jmp .redraw
+       cmp #' '
        beq .acc
        cmp #'0'
        bcc .key
        cmp #'9'+1
        bcc .acc
        cmp #'A'
        bcc .key
        cmp #'Z'+1
        bcs .key
.acc    ldx flen
        cpx #16
        bcs .key
        sta fbuf,x
        inc flen
        jmp .redraw
.cancel jmp redraw
.go     lda flen
        bne +
        lda #0                  ; empty input: remove marker
        sta tgtf
        jmp redraw
+       jsr findobj
        bcs .nf
        ldy #5
-       lda (vp),y
        sta tgtv,y
        dey
        bpl -
        lda #1
        sta tgtf
        jsr aimat
        jmp redraw
.nf     ldx #0
-       lda txtnf,x
        beq +
        sta sbuf,x
        inx
        bne -
+       ldy #0
-       cpy flen
        beq +
        lda fbuf,y
        sta sbuf,x
        inx
        iny
        bne -
+       lda #' '
-       cpx #40
        beq +
        sta sbuf,x
        inx
        bne -
+       lda #0
        sta sbuf+40
        jsr statusmsg
        lda #0
        sta $c6
        jmp waitkey
!if LANG = 0 {
txtnf   !text "NENALEZENO: ",0
txthl   !text "HLEDAT (RETURN/STOP): ",0
} else {
txtnf   !text "NOT FOUND: ",0
txthl   !text "FIND (RETURN/STOP): ",0
}

showinput
        ldx #0
-       lda txthl,x
        beq +
        sta sbuf,x
        inx
        bne -
+       ldy #0
-       cpy flen
        beq +
        lda fbuf,y
        sta sbuf,x
        inx
        iny
        bne -
+       lda #'_'
        sta sbuf,x
        inx
        lda #' '
-       cpx #40
        beq +
        sta sbuf,x
        inx
        bne -
+       lda #0
        sta sbuf+40
; draw sbuf into the status bar (bitmap under the KERNAL ROM)
statusmsg
        sei
        lda #$35
        sta $01
        ldx #0
        txa
-       sta $fe00,x
        sta $fe40,x
        inx
        bne -
        lda #0
        sta occchk
        jsr statusout
        lda #$37
        sta $01
        cli
        rts

; prefix compare fbuf with (strp): C=0 match
prefix  ldy #0
-       cpy flen
        beq +
        lda (strp),y
        beq ++
        cmp #96                 ; accented letter -> compare as plain letter
        bcc .pf
        tax
        lda foldtab-96,x
.pf     cmp fbuf,y
        bne ++
        iny
        bne -
+       clc
        rts
++      sec
        rts

; find object; out: vp -> equatorial vector, C=0 found
findobj ldx #0                  ; planets
-       stx t3
        lda plnamlo,x
        sta strp
        lda plnamhi,x
        sta strp+1
        jsr prefix
        bcs +
        lda t3
        asl
        sta t0
        asl
        clc
        adc t0
        adc #<planets
        sta vp
        lda #>planets
        adc #0
        sta vp+1
        clc
        rts
+       ldx t3
        inx
        cpx #7
        bne -
        lda #<starlab           ; named stars
        sta ip
        lda #>starlab
        sta ip+1
        lda #NNAMED
        sta t3
-       ldy #2
        lda (ip),y
        sta strp
        iny
        lda (ip),y
        sta strp+1
        jsr prefix
        bcs +
        ldy #0                  ; vp = stars + idx*7 = idx*8 - idx
        lda (ip),y
        sta tmpw
        iny
        lda (ip),y
        sta tmpw+1
        lda tmpw
        sta vp
        lda tmpw+1
        sta vp+1
        asl vp
        rol vp+1
        asl vp
        rol vp+1
        asl vp
        rol vp+1
        lda vp
        sec
        sbc tmpw
        sta vp
        lda vp+1
        sbc tmpw+1
        sta vp+1
        lda vp
        clc
        adc #<stars
        sta vp
        lda vp+1
        adc #>stars
        sta vp+1
        clc
        rts
+       lda ip
        clc
        adc #4
        sta ip
        bcc +
        inc ip+1
+       dec t3
        bne -
        lda #<messier           ; Messier objects (exact name, e.g. M31)
        sta vp
        lda #>messier
        sta vp+1
        lda #NMESS
        sta t3
-       ldy #7
        lda (vp),y
        sta strp
        iny
        lda (vp),y
        sta strp+1
        jsr prefix
        bcs +
        ldy flen
        lda (strp),y
        bne +
        clc
        rts
+       lda vp
        clc
        adc #9
        sta vp
        bcc +
        inc vp+1
+       dec t3
        bne -
        lda #<conlab            ; constellations
        sta vp
        lda #>conlab
        sta vp+1
        lda #NCONS
        sta t3
-       ldy #6
        lda (vp),y
        sta strp
        iny
        lda (vp),y
        sta strp+1
        jsr prefix
        bcs +
        clc
        rts
+       lda vp
        clc
        adc #8
        sta vp
        bcc +
        inc vp+1
+       dec t3
        bne -
        sec
        rts

; turn the view towards tgtv
aimat   lda #<tgtv
        sta vp
        lda #>tgtv
        sta vp+1
        lda #<matA
        sta rp
        lda #>matA
        sta rp+1
        jsr dot3
        +copyw fres, hn
        lda #<(matA+6)
        sta rp
        lda #>(matA+6)
        sta rp+1
        jsr dot3
        +copyw fres, he
        lda #<(matA+12)
        sta rp
        lda #>(matA+12)
        sta rp+1
        jsr dot3
        +copyw fres, hu
        ; altitude: binary search sin(a) = hu over [-90, 90] deg
        lda #<(-16384)
        sta blo
        lda #>(-16384)
        sta blo+1
        lda #<16384
        sta bhi
        lda #>16384
        sta bhi+1
        lda #15
        sta t3
-       lda blo
        clc
        adc bhi
        sta tmpw
        lda blo+1
        adc bhi+1
        cmp #$80
        ror
        sta tmpw+1
        ror tmpw
        +copyw tmpw, tmpw2
        jsr getsin
        lda sres                ; sin(mid) < hu ?
        cmp hu
        lda sres+1
        sbc hu+1
        bvc +
        eor #$80
+       bmi +
        +copyw tmpw2, bhi
        jmp ++
+       +copyw tmpw2, blo
++      dec t3
        bne -
        +copyw blo, alt
        lda alt                 ; clamp to >= -20 deg
        cmp #<(-3641)
        lda alt+1
        sbc #>(-3641)
        bvc +
        eor #$80
+       bpl +
        lda #<(-3641)
        sta alt
        lda #>(-3641)
        sta alt+1
+       ; azimuth: maximise hn*cos(a) + he*sin(a); coarse then fine
        lda #0
        sta cang
        sta cang+1
        sta cend
        lda #$00
        sta cend+1              ; full circle (wraps to 0)
        lda #<1024
        sta cstep
        lda #>1024
        sta cstep+1
        jsr azscan
        lda bang                ; fine: bang-1024 .. bang+1024 step 64
        sec
        sbc #<1024
        sta cang
        lda bang+1
        sbc #>1024
        sta cang+1
        lda bang
        clc
        adc #<1088
        sta cend
        lda bang+1
        adc #>1088
        sta cend+1
        lda #64
        sta cstep
        lda #0
        sta cstep+1
        jsr azscan
        +copyw bang, az
        rts

azscan  lda #0
        sta bscore
        lda #$80
        sta bscore+1            ; -32768
.l      +copyw cang, tmpw
        jsr getcos
        +copyw hn, ma
        +copyw sres, mb
        jsr fixmul
        +copyw fres, tmpw2
        +copyw cang, tmpw
        jsr getsin
        +copyw he, ma
        +copyw sres, mb
        jsr fixmul
        lda fres
        clc
        adc tmpw2
        sta tmpw2
        lda fres+1
        adc tmpw2+1
        sta tmpw2+1
        lda bscore              ; score > best ?
        cmp tmpw2
        lda bscore+1
        sbc tmpw2+1
        bvc +
        eor #$80
+       bpl +
        +copyw tmpw2, bscore
        +copyw cang, bang
+       lda cang
        clc
        adc cstep
        sta cang
        lda cang+1
        adc cstep+1
        sta cang+1
        lda cang
        cmp cend
        beq *+5
        jmp .l
        lda cang+1
        cmp cend+1
        beq *+5
        jmp .l
        rts

; Messier objects: symbol by type, green label "M31"
!zone
draw_messier
        lda showm
        beq .done
        lda zoom
        beq .done               ; not in the 120 deg view
        lda #<messier
        sta sp0
        lda #>messier
        sta sp0+1
        lda #NMESS
        sta t3
.loop   lda sp0
        sta vp
        lda sp0+1
        sta vp+1
        jsr skyproj
        bit pflag
        bvc .nxt
        ldy #6
        lda (sp0),y
        tax
        lda mpatlo,x
        sta pat
        lda mpathi,x
        sta pat+1
        jsr drawpat
        lda shown
        beq .nxt
        ldy #7
        lda (sp0),y
        sta strp
        iny
        lda (sp0),y
        sta strp+1
        lda #$d0                ; light green
        sta ccol
        lda sx                  ; label right of the symbol
        clc
        adc #2
        sta sx
        bcc +
        inc sx+1
+       jsr labelright
.nxt    lda sp0
        clc
        adc #9
        sta sp0
        bcc +
        inc sp0+1
+       dec t3
        bne .loop
.done   rts
mpatlo  !byte <patgal,<patoc,<patgc,<patneb
mpathi  !byte >patgal,>patoc,>patgc,>patneb

; =====================================================================
; title screen "SkyMap64"
!zone
title   jsr gfx_on
        lda #6
        sta $d020               ; blue border like the mock-up
        sei
        lda #$35
        sta $01
        jsr clear_bitmap
        ldx #0                  ; colours: light blue on black inside
        lda #$e0
-       sta SCREEN,x
        sta SCREEN+256,x
        sta SCREEN+512,x
        sta SCREEN+744,x
        inx
        bne -
        lda #$e6                ; blue margin: rows 0, 24, columns 0, 39
        ldx #39
-       sta SCREEN,x
        sta SCREEN+960,x
        dex
        bpl -
        ldx #23
-       lda scrlo,x
        sta bp
        lda scrhi,x
        sta bp+1
        lda #$e6
        ldy #0
        sta (bp),y
        ldy #39
        sta (bp),y
        dex
        bne -
        lda #0
        sta dotted
        sta occchk
        ; frame
        ldx #0
-       stx t3
        lda tframe,x
        sta lx0
        lda tframe+1,x
        sta lx0+1
        lda tframe+2,x
        sta ly0
        lda tframe+3,x
        sta lx1
        lda tframe+4,x
        sta lx1+1
        lda tframe+5,x
        sta ly1
        lda #0
        sta ly0+1
        sta ly1+1
        jsr clipline
        lda t3
        clc
        adc #6
        tax
        cpx #24
        bne -
        ; constellation-like lines
        lda #<tlines
        sta sp0
        lda #>tlines
        sta sp0+1
        lda #NTLINES
        sta t3
.ln     ldy #0
        lda (sp0),y
        sta lx0
        iny
        lda (sp0),y
        sta lx0+1
        iny
        lda (sp0),y
        sta ly0
        iny
        lda (sp0),y
        sta lx1
        iny
        lda (sp0),y
        sta lx1+1
        iny
        lda (sp0),y
        sta ly1
        lda #0
        sta ly0+1
        sta ly1+1
        jsr clipline
        lda sp0
        clc
        adc #6
        sta sp0
        bcc +
        inc sp0+1
+       dec t3
        bne .ln
        ; stars
        lda #<tstars
        sta sp0
        lda #>tstars
        sta sp0+1
        lda #NTSTARS
        sta t3
.st     ldy #0
        lda (sp0),y
        sta sx
        iny
        lda (sp0),y
        sta sx+1
        iny
        lda (sp0),y
        sta sy
        lda #0
        sta sy+1
        iny
        lda (sp0),y
        tax
        lda tspat,x
        sta pat
        lda tspath,x
        sta pat+1
        jsr drawpat
        lda sp0
        clc
        adc #4
        sta sp0
        bcc +
        inc sp0+1
+       dec t3
        bne .st
        ; small texts
        lda #<ttexts
        sta ip
        lda #>ttexts
        sta ip+1
.tx     ldy #0
        lda (ip),y
        cmp #$ff
        beq .big
        sta cx
        iny
        lda (ip),y
        sta cy
        iny
        lda (ip),y
        sta strp
        iny
        lda (ip),y
        sta strp+1
        lda #$e0
        sta ccol
        jsr drawtext
        lda ip
        clc
        adc #4
        sta ip
        bcc .tx
        inc ip+1
        jmp .tx
        ; big "SkyMap64", 4x scaled, 24 px per letter
.big    lda #0
        sta t3                  ; letter
.bl     lda #0
        sta t2                  ; glyph row
.br     lda t3
        asl
        asl
        asl
        ora t2
        tax
        lda bigfont,x
        sta t6                  ; row bits
        lda #0
        sta t7                  ; column 0..4
.bc     lda t6
        ldx t7
        and colbit,x
        beq .nb
        ; block origin x = 64 + letter*24 + col*4, y = 60 + row*4
        lda t3
        asl
        asl
        asl
        sta t0
        asl
        clc
        adc t0                  ; letter*24
        adc #64
        sta tmpw
        lda #0
        adc #0
        sta tmpw+1
        lda t7
        asl
        asl
        clc
        adc tmpw
        sta tmpw
        bcc +
        inc tmpw+1
+       lda t2
        asl
        asl
        clc
        adc #60
        sta tmpw2               ; y
        ldy #3
.by     ldx #3
.bx     stx t0
        sty t1
        txa
        clc
        adc tmpw
        sta px
        lda tmpw+1
        adc #0
        sta px+1
        tya
        clc
        adc tmpw2
        sta py
        jsr plotfast
        ldx t0
        ldy t1
        dex
        bpl .bx
        dey
        bpl .by
.nb     inc t7
        lda t7
        cmp #5
        bne .bc
        inc t2
        lda t2
        cmp #8
        bne .br
        inc t3
        lda t3
        cmp #8
        beq +
        jmp .bl
+       lda #$37
        sta $01
        cli
        lda #0
        sta $c6
.wait   jsr GETIN
        cmp #$0d
        bne .wait
        jsr gfx_off
        lda #0
        sta $d020
        rts
colbit  !byte $40,$20,$10,$08,$04
tspat   !byte <pat4,<pat2
tspath  !byte >pat4,>pat2
tframe  !word 8
        !byte 8
        !word 311
        !byte 8
        !word 311
        !byte 8
        !word 311
        !byte 191
        !word 311
        !byte 191
        !word 8
        !byte 191
        !word 8
        !byte 191
        !word 8
        !byte 8

; ring around the searched object
draw_target
        lda tgtf
        beq +
        lda #<tgtv
        sta vp
        lda #>tgtv
        sta vp+1
        lda #<matM
        sta mp
        lda #>matM
        sta mp+1
        jsr project
        bit pflag
        bvc +
        lda #<patsel
        sta pat
        lda #>patsel
        sta pat+1
        jmp drawpat
+       rts

; number output helpers (value in tmpw, position x in sbuf)
num3    ldy #0                  ; hundreds
-       lda tmpw
        cmp #100
        lda tmpw+1
        sbc #0
        bcc +
        lda tmpw
        sbc #100
        sta tmpw
        lda tmpw+1
        sbc #0
        sta tmpw+1
        iny
        jmp -
+       tya
        beq +
        ora #'0'
        sta sbuf,x
        inx
        jmp num2z
+       lda #' '
        sta sbuf,x
        inx
num2    lda tmpw                ; 2 digits, leading space
        jsr div10
        pha
        tya
        bne +
        lda #' '
        bne n2st
+       ora #'0'
        jmp n2st
num2z   lda tmpw                ; 2 digits, leading zero
        jsr div10
        pha
        tya
        ora #'0'
n2st    sta sbuf,x
        inx
        pla
        ora #'0'
        sta sbuf,x
        rts
div10   ldy #0
-       cmp #10
        bcc +
        sbc #10
        iny
        bne -
+       rts

scrlo   !for r, 0, 24 { !byte <(SCREEN + r*40) }
scrhi   !for r, 0, 24 { !byte >(SCREEN + r*40) }



!source "data.asm"
end_of_ml
