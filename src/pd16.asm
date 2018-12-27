; ------------------------------------------------------------------------
;
; Title:
;
;   PD16 -- PIC 5/10 MHz to four frequencies divider (1-10-100-1000 Hz)
;
; Function:
;
;   This PIC program implements a digital frequency divider: cpu hardware
;   and isochronous software divide the input clock by 7 powers of ten.
;   This allows generation of decade outputs from 10 kHz to 1 Hz (1PPS).
;
;   - In this version a 5 or 10 MHz input clock is divided to create four
;     simultaneous square wave outputs: 1 Hz, 10 Hz, 100 Hz, 1000 Hz.
;
;   - The Select input pin sets the divide ratio (5 or 10 MHz).
;
; Diagram:
;                                ---__---
;                5V (Vdd)  +++++|1      8|=====  Ground (Vss)
;       5/10 MHz clock in  ---->|2  pD  7|---->  1000 Hz out
;                1 Hz out  <----|3  16  6|---->  100 Hz out
;                  Select  o--->|4      5|---->  10 Hz out
;                                --------
; Notes:
;
;   o External pull-up/down required on Select input (pin4/GP3).
;   Output frequency accuracy is the same as clock input accuracy.
;   Output drive current is 25 mA maximum per pin.
;   Coded for Microchip 12F675 but any '609 '615 '629 '635 '675 '683 works.
;
; Version:
;
;   27-Jan-2013  Tom Van Baak (tvb)  www.LeapSecond.com/pic
;
; ------------------------------------------------------------------------

; Microchip MPLAB IDE assembler code (mpasm).

        list        p=pic12f675
        include     p12f675.inc
        __config    _EC_OSC & _MCLRE_OFF & _WDT_OFF

; Register definitions.

        cblock  0x20            ; define register base
            gpcopy              ; shadow of output pins
            dig4, dig3, dig2, dig1, dig0
        endc

; One-time PIC 12F675 initialization.

        org     0               ; power-on entry
init:   bcf     STATUS,RP0      ; bank 0
        movlw   0x07            ; turn comparator off
        movwf   CMCON           ;
        clrf    GPIO            ; set output latches low

        bsf     STATUS,RP0      ; bank 1
        errorlevel -302
        clrf    ANSEL           ; all digital (no analog) pins
        movlw   ~(1<<GP4 | 1<<GP2 | 1<<GP1 | 1<<GP0)
        movwf   TRISIO          ; set pin directions (0=output)
        errorlevel +302
        bcf     STATUS,RP0      ; bank 0
        call    clear           ; initialize counter and pins

; To create multiple frequency outputs the PIC increments a virtual
; '7490-style decade counter chain in a continuous isochronous loop.
; Clocking the counter at twice the output rate allows each LSB to
; generate a square wave at the desired decade frequency.
;
; A 500 us (2 kHz) toggle loop can generate a 1 kHz square wave.
; With a 5 MHz clock (800 ns Tcy) 625 instructions is 500 us.
; With a 10 MHz clock (400 ns Tcy) 1250 instructions is 500 us.

loop:   movf    gpcopy,W        ; gpcopy -> W
        movwf   GPIO            ; W -> GPIO

        ; Update counter and map each output pin to decade LSB.

        call    count           ; increment counter
        clrf    gpcopy          ;
        btfss   dig0,0          ; 1000 Hz decade LSB
          bsf   gpcopy,GP0      ;
        btfss   dig1,0          ; 100 Hz decade LSB
          bsf   gpcopy,GP1      ;
        btfss   dig2,0          ; 10 Hz decade LSB
          bsf   gpcopy,GP2      ;
        btfss   dig3,0          ; 1 Hz decade LSB
          bsf   gpcopy,GP4      ;

        ; Pad loop for exactly 625 instructions (use MPLAB SIM).

        movlw   d'4'            ;
        call    DelayW100       ; delay W*100
        movlw   d'176'          ;
        call    DelayW1         ; delay (15 <= W <= 255)
        btfss   GPIO,GP3        ; check for 2x clock selection
          goto  loop            ; done with short loop

        ; Pad loop for exactly 1250 instructions (use MPLAB SIM).

        movlw   d'5'            ;
        call    DelayW100       ; delay W*100
        movlw   d'122'          ;
        call    DelayW1         ; delay (15 <= W <= 255)
        goto    loop            ; done with long loop

; Initialize counter (zero) and output pins (high).

clear:  clrf    dig0
        clrf    dig1
        clrf    dig2
        clrf    dig3
        clrf    dig4
        movlw   1<<GP4 | 1<<GP2 | 1<<GP1 | 1<<GP0
        movwf   gpcopy
        return

; Increment 5-digit decimal counter (isochronous code).

count:  incf    dig0,F          ; always increment LSDigit
        movlw   d'10'           ;
        subwf   dig0,W          ; check overflow
        skpnz                   ;
          clrf  dig0            ; reset to zero

        skpnz                   ;
          incf  dig1,F          ; apply previous carry
        movlw   d'10'           ;
        subwf   dig1,W          ; check overflow
        skpnz                   ;
          clrf  dig1            ; reset to zero

        skpnz                   ;
          incf  dig2,F          ; apply previous carry
        movlw   d'10'           ;
        subwf   dig2,W          ; check overflow
        skpnz                   ;
          clrf  dig2            ; reset to zero

        skpnz                   ;
          incf  dig3,F          ; apply previous carry
        movlw   d'10'           ;
        subwf   dig3,W          ; check overflow
        skpnz                   ;
          clrf  dig3            ; reset to zero

        skpnz                   ;
          incf  dig4,F          ; apply previous carry
        movlw   d'10'           ;
        subwf   dig4,W          ; check overflow
        skpnz                   ;
          clrf  dig4            ; reset to zero

        return

        include delayw.asm      ; precise delay functions
        end
