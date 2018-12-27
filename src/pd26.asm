; ------------------------------------------------------------------------
;
; Title:
;
;   PD26 -- PIC 10 MHz to 1PPS divider, with sync and micro-step
;
; Function:
;
;   This PIC program implements a digital frequency divider: the external
;   10 MHz input clock is divided by ten million to produce a 1PPS output.
;
;   - The 1PPS pulse width is 10 ms (1% duty cycle).
;
;   - The Step/Direction inputs allow 1PPS phase shift in 400 ns steps.
;     Hold Step pin low and each subsequent second the 1PPS output will
;     advance (if Direction is high) or retard (if Direction is low).
;
;   - Two inputs support optional manual 1PPS synchronization. Pull Arm
;     pin low for a second to stop divider. The output will synchronize
;     to next rising edge of Sync pin (within one instruction cycle).
;
; Diagram:
;                                ---__---
;                5V (Vdd)  +++++|1      8|=====  Ground (Vss)
;         10 MHz clock in  ---->|2  pD  7|<+---  Step
;                1PPS out  <----|3  26  6|<+---  Direction
;                     Arm  o--->|4      5|<+---  Sync
;                                --------
; Notes:
;
;   o External pull-up required on Arm input (pin4/GP3).
;   + Step, Direction, and Sync inputs have internal WPU.
;   Output frequency accuracy is the same as clock input accuracy.
;   Output drive current is 25 mA maximum per pin.
;   Coded for Microchip 12F675 but any '609 '615 '629 '635 '675 '683 works.
;
; Version:
;
;   26-Dec-2012  Tom Van Baak (tvb)  www.LeapSecond.com/pic
;
; ------------------------------------------------------------------------

; Microchip MPLAB IDE assembler code (mpasm).

        list        p=pic12f675
        include     p12f675.inc
        __config    _EC_OSC & _MCLRE_OFF & _WDT_OFF

; Register definitions.

        cblock  0x20            ; define register base
        endc

; Define entry points.

        org     0               ; power-on entry
        goto    init            ;
        org     4               ; interrupt entry
        goto    sync            ;

; One-time PIC 12F675 initialization.

init:   bcf     STATUS,RP0      ; bank 0
        movlw   0x07            ; turn off comparator
        movwf   CMCON           ;
        movlw   0xFF            ; set output latches high
        movwf   GPIO            ;

        bsf     STATUS,RP0      ; bank 1
        errorlevel -302
        clrf    ANSEL           ; enable digital IO (no analog pins)
        movlw   0<<NOT_GPPU | 1<<INTEDG
        movwf   OPTION_REG      ; WPU, GP2/INT rising edge
        movlw   ~(1<<GP4)
        movwf   TRISIO          ; activate output pin(s)
        movlw   1<<GP2 | 1<<GP1 | 1<<GP0
        movwf   WPU             ; activate weak pullup input pin(s)
        errorlevel +302
        bcf     STATUS,RP0      ; bank 0

; With an external 10 MHz PIC clock the (4:1) execution rate is 2.5 MIPS.
; A loop of 2,500,000 instruction cycles (Tcy = 400 ns) takes exactly 1
; second. To make 1PPS: set output high for a short time once per loop.

        ; Set output high for 10 ms = 25,000 Tcy at 10 MHz.

rise:   movlw   0xFF            ; high output
        movwf   GPIO            ; W -> output pin(s)
        call    Delay5          ; (sync alignment)
sync:   call    armed           ; check for Arm request
        movlw   d'249'          ;
        call    DelayW100       ; delay W*100
        movlw   d'84'           ;
        call    DelayW1         ; delay (15 <= W <= 255)
        goto    fall

        ; Set output low for 990 ms = 2,475,000 Tcy at 10 MHz.

fall:   movlw   0x00            ; low output
        movwf   GPIO            ; W -> output pin(s)
        movlw   d'247'          ;
        call    DelayW10k       ; delay W*10000
        movlw   d'49'           ;
        call    DelayW100       ; delay W*100
        movlw   d'85'           ;
        call    DelayW1         ; delay (15 <= W <= 255)
        call    step            ; alter loop period as necessary
        goto    rise

; Implement phase adjustment protocol using pos/neg leap cycles.
;
; - Step low, Direction high (advance)  call step = 7 Tcy
; - Step high (normal, no step)         call step = 8 Tcy
; - Step low, Direction low (retard)    call step = 9 Tcy

step:                           ; (      2)   call overhead
        btfsc   GPIO,GP0        ; (      1)   check step request?
          goto  $+3             ; (      1 2)   Step high, no step
        btfsc   GPIO,GP1        ; (      1)   test step direction?
          return                ; (      1 2)   Dir high, advance
        nop                     ; (      1)   Dir low, retard
        return                  ; (      2)

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
