; ------------------------------------------------------------------------
;
; Title:
;
;   PD10 -- PIC "4-pin" 10 MHz to 1PPS frequency divider (10 ms pulse)
;
; Function:
;
;   This PIC program implements a digital frequency divider: the external
;   input clock is divided by ten million. For example, if the input clock
;   frequency is 10 MHz then the output frequency will be 1 Hz (1PPS).
;
;   The output is a narrow 10 millisecond pulse (not a 50% square wave).
;
; Diagram:
;                                ---__---
;                5V (Vdd)  +++++|1      8|=====  Ground (Vss)
;         10 MHz clock in  ---->|2  pD  7|---->  1PPS out (10 ms)
;                              *|3  10  6|*
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
;   28-Oct-2011  Tom Van Baak (tvb)  www.LeapSecond.com/pic
;
; ------------------------------------------------------------------------

; Microchip MPLAB IDE assembler code (mpasm).

        list        p=pic12f675
        include     p12f675.inc
        __config    _EC_OSC & _MCLRE_OFF & _WDT_OFF

; Register definitions.

        cblock  0x20            ; define register base
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

; With an external 10 MHz PIC clock the (4:1) execution rate is 2.5 MIPS.
; A 2,500,000 instruction (400 ns each) loop takes exactly 1 second.
; The pins are pulsed once per loop to create a 1PPS output.

        ; Set output high for 10 ms = 25,000 Tcy at 10 MHz.

rise:   movlw   0xFF            ; (      1) high output
        movwf   GPIO            ; (      1) W -> output pin(s)
        movlw   d'249'          ; (      1)
        call    DelayW100       ; (  24900) delay W*100
        movlw   d'94'           ; (      1)
        call    DelayW1         ; (     94) delay (15 <= W <= 255)
        goto    fall            ; (      2)

        ; Set output low for 990 ms = 2,475,000 Tcy at 10 MHz.

fall:   movlw   0x00            ; (      1) low output
        movwf   GPIO            ; (      1) W -> output pin(s)
        movlw   d'247'          ; (      1)
        call    DelayW10k       ; (2470000) delay W*10000
        movlw   d'49'           ; (      1)
        call    DelayW100       ; (   4900) delay W*100
        movlw   d'93'           ; (      1)
        call    DelayW1         ; (     93) delay (15 <= W <= 255)
        goto    rise            ; (      2)

        include delayw.asm      ; precise delay functions
        end
