; ------------------------------------------------------------------------
;
; Title:
;
;   PD11 -- PIC 10 MHz to 1PPS frequency divider (3 pulse widths), with sync
;
; Function:
;
;   This PIC program implements a digital frequency divider: cpu hardware
;   and isochronous software divide the input clock by 10 million. When
;   the external input clock is 10 MHz the output is 1 Hz (1PPS).
;
;   - This version has three 1PPS outputs, each with different pulse
;     width: 100 us, 10 ms, 0.5 s (square wave).
;
;   - Two inputs support optional manual 1PPS synchronization. Pull Arm
;     pin low for a second to stop divider. All outputs will synchronize
;     to next rising edge of Sync pin (within one instruction cycle).
;
; Diagram:
;                                ---__---
;                5V (Vdd)  +++++|1      8|=====  Ground (Vss)
;         10 MHz clock in  ---->|2  pD  7|---->  1PPS out (100 us)
;        1PPS (10 ms) out  <----|3  11  6|---->  1 Hz out (50%)
;                     Arm  o--->|4      5|<+---  Sync
;                                --------
; Notes:
;
;   o External pull-up required on Arm input (pin4/GP3).
;   + Sync input (pin5/GP2) has internal WPU.
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
        endc

PPa     equ     (1<<GP0)        ; bit mask for pin7/GP0 (100 us output)
PPb     equ     (1<<GP4)        ; bit mask for pin3/GP4 (10 ms output)
PPc     equ     (1<<GP1)        ; bit mask for pin6/GP1 (0.5 s output)

; Define entry points.

        org     0               ; power-on entry
        goto    init            ;
        org     4               ; interrupt entry
        goto    sync            ;

; One-time PIC 12F675 initialization.

init:   bcf     STATUS,RP0      ; bank 0
        movlw   0x07            ; turn comparator off
        movwf   CMCON           ;
        clrf    GPIO            ; set output latches low

        bsf     STATUS,RP0      ; bank 1
        errorlevel -302
        clrf    ANSEL           ; all digital (no analog) pins
        movlw   ~(PPa|PPb|PPc)
        movwf   TRISIO          ; set pin directions (0=output)
        movlw   1<<GP2
        movwf   WPU             ; enable weak pullup (1=enable)
        movlw   1<<INTEDG       ; WPU, GP2/INT rising edge trigger
        movwf   OPTION_REG      ;
        errorlevel +302
        bcf     STATUS,RP0      ; bank 0

; With an external 10 MHz PIC clock the (4:1) execution rate is 2.5 MIPS.
; A 2,500,000 instruction cycle (Tcy=400 ns) loop takes exactly 1 second.
; Generate 1PPS on 3 pins, each having successively wider pulse widths.

loop:   movlw   PPa|PPb|PPc     ; (      1)
        movwf   GPIO            ; (      1) rise: PPa PPb PPc
        call    Delay4          ; (      4) sync alignment
sync:   call    armed           ; (      5) check for Arm request
        movlw   d'238'          ; (      1)
        call    DelayW1         ; (    238)
                                ; ---------> 250 Tcy = 100 us @ 10 MHz

        movlw   PPb|PPc         ; (      1)
        movwf   GPIO            ; (      1) fall: PPa
        movlw   d'247'          ; (      1)
        call    DelayW100       ; (  24700)
        movlw   d'46'           ; (      1)
        call    DelayW1         ; (     46)
                                ; ---------> 25000 Tcy = 10 ms @ 10 MHz

        movlw   PPc             ; (      1)
        movwf   GPIO            ; (      1) fall: PPb
        movlw   d'122'          ; (      1)
        call    DelayW10k       ; (1220000)
        movlw   d'49'           ; (      1)
        call    DelayW100       ; (   4900)
        movlw   d'95'           ; (      1)
        call    DelayW1         ; (     95)
                                ; ---------> 1250000 Tcy = 500 ms @ 10 MHz

        movlw   0               ; (      1)
        movwf   GPIO            ; (      1) fall: PPc
        movlw   d'124'          ; (      1)
        call    DelayW10k       ; (1240000)
        movlw   d'99'           ; (      1)
        call    DelayW100       ; (   9900)
        movlw   d'93'           ; (      1)
        call    DelayW1         ; (     93)
        goto    loop            ; (      2)
                                ; ---------> 2500000 Tcy = 1 s @ 10 MHz

; Implement two-pin 1PPS Arm-Sync synchronization protocol.
; - Accept Arm (low) request when output(s) are high.
; - Use GP2/INT interrupt to keep accuracy within 1 Tcy.
; - Divider resets and resumes on rising edge of Sync pin.
; - Re-enter main loop late to compensate for interrupt/code latency.

armed:  btfsc   GPIO,GP3        ; Arm pin low?
          return                ;   no, continue running

        movlw   1<<GIE|1<<INTE  ; enable GP2 edge-trigger interrupt
        movwf   INTCON          ;   (and clear interrupt flags)
        goto    $               ; no deposit, no return, no retfie

        include delayw.asm      ; precise delay functions
        end
