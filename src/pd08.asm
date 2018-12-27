; ------------------------------------------------------------------------
;
; Title:
;
;   PD08 -- PIC "4-pin" 5x10^6 frequency divider (5 MHz to 1 Hz)
;
; Function:
;
;   This PIC program implements a digital frequency divider: the external
;   input clock is divided by a factor of 5 million (5e6). For example,
;   if the input clock is 5 MHz then the output clock will be 1 Hz.
;
; Diagram:
;                                ---__---
;                5V (Vdd)  +++++|1      8|=====  Ground (Vss)
;             input clock  ---->|2  pD  7|---->  output clock
;                              *|3  08  6|*
;                              o|4      5|o
;                                --------
; Notes:
;
;   Only 4 pins are required: power (2.0-5.5V), ground, input and output.
;   * For added drive power, pin3/GP4 and pin6/GP1 are also outputs.
;   o Tie input pin4/GP3 and pin5/GP2 to Vdd or Vss.
;   Output frequency accuracy is the same as clock input accuracy.
;   Output drive current is 25 mA maximum per pin.
;   Coded for Microchip 12F675 but any '609 '615 '629 '635 '675 '683 works.
;
; Version:
;
;   30-Jul-2008  Tom Van Baak (tvb)  www.LeapSecond.com/pic
;
; ------------------------------------------------------------------------

; Microchip MPLAB IDE assembler code (mpasm).

        list        p=pic12f675
        include     p12f675.inc
        __config    _EC_OSC & _MCLRE_OFF & _WDT_OFF

; Register definitions.

        cblock  0x20            ; define register base
            gpcopy              ; shadow of output pins
        endc

; One-time PIC 12F675 initialization.

        org     0               ; power-on entry here
        bcf     STATUS,RP0      ; bank 0
        clrf    GPIO            ; set all pins low
        movlw   07h             ; set mode to turn
        movwf   CMCON           ;   comparator off
        bsf     STATUS,RP0      ; bank 1
        clrf    ANSEL-0x80      ; set digital IO (no analog A/D)
        movlw   b'101100'       ; set GP0,GP1,GP4 as output(0) and
        movwf   TRISIO-0x80     ;   other pins are input(1)
        bcf     STATUS,RP0      ; bank 0
        clrf    gpcopy          ; initialize shadow output

; With an external 5 MHz PIC clock the (4:1) execution rate is 1.25 MIPS.
; A 625,000 instruction (800 ns each) loop takes exactly 0.5 seconds.
; Output pins are toggled once per loop creating a 1 Hz square wave.

loop:   movlw   0xFF            ; -1
        xorwf   gpcopy,F        ; toggle bits
        movf    gpcopy,W        ; gpcopy -> W
        movwf   GPIO            ; W -> output pin(s)

        movlw   d'62'           ; 620000
        call    DelayW10k       ; delay W*10000
        movlw   d'49'           ; 4900
        call    DelayW100       ; delay W*100
        movlw   d'91'           ;
        call    DelayW1         ; delay (15 <= W <= 255)
        goto    loop            ;

        include delayw.asm      ; precise delay functions
        end
