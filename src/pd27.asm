; ------------------------------------------------------------------------
;
; Title:
;
;   PD27 -- PIC 10 MHz to 1PPS divider, with sync and milli-step
;
; Function:
;
;   This PIC program implements a digital frequency divider: the external
;   10 MHz input clock is divided by ten million to produce a 1PPS output.
;
;   - The 1PPS pulse width is 10 ms (1% duty cycle).
;
;   - Two Step inputs are checked once a second:
;     to advance 1PPS by   1 ms, hold StepA low
;     to retard  1PPS by  10 ms, hold StepB low
;     to advance 1PPS by 100 ms, hold both StepA and StepB low
;
;   - Two inputs support optional manual 1PPS synchronization. Pull Arm
;     pin low for a second to stop divider. The output will synchronize
;     to next rising edge of Sync pin (within one instruction cycle).
;
; Diagram:
;                                ---__---
;                5V (Vdd)  +++++|1      8|=====  Ground (Vss)
;         10 MHz clock in  ---->|2  pD  7|<+---  StepA
;                1PPS out  <----|3  27  6|<+---  StepB
;                     Arm  o--->|4      5|<+---  Sync
;                                --------
; Notes:
;
;   o External pull-up required on Arm input (pin4/GP3).
;   + Step and Sync inputs have internal WPU.
;   Output frequency accuracy is the same as clock input accuracy.
;   Output drive current is 25 mA maximum per pin.
;   Coded for Microchip 12F675 but any '609 '615 '629 '635 '675 '683 works.
;
; Version:
;
;   07-Feb-2013  Tom Van Baak (tvb)  www.LeapSecond.com/pic
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
        movlw   d'222'          ;
        call    DelayW10k       ; delay W*10000
        movlw   d'24'           ;
        call    DelayW100       ; delay W*100
        movlw   d'83'           ;
        call    DelayW1         ; delay (15 <= W <= 255)
        call    step            ; alter loop period as necessary
        goto    rise

; Use selected calls to delay functions to make 0-1-10-100 ms steps.

step:   movf    GPIO,W          ; get 2-bits of Step pins
        andlw   3               ;
        addwf   PCL,F           ; jump PCL+W (computed goto)
          goto  step0           ; b'00' = advance 1PPS by 100 ms
          goto  step1           ; b'01' =  retard 1PPS by  10 ms
          goto  step2           ; b'10' = advance 1PPS by   1 ms
          goto  step3           ; b'11' = no change in 1PPS phase

step1   call    delay10ms       ; 10 ms more delay than normal
step3   call    delay100ms      ; consider this normal delay
step0   call    delay1ms        ; 100 ms less delay than normal
        return
step2   call    delay100ms      ; 1 ms less delay than normal
        return

; The following three functions delay: 1 ms, 10 ms, 100 ms.
; - Valid only for 10 MHz clock (Tcy 0.4 us).
; - Times include call/return. Note goto=call trick.

delay1ms:                       ; 1 ms is 2,500 instructions
        movlw   d'24'           ;
        call    DelayW100       ; delay W*100
        movlw   d'96'           ;
        goto    DelayW1         ; delay (15 <= W <= 255)

delay10ms:                      ; 10 ms is 25,000 instructions
        movlw   d'249'          ;
        call    DelayW100       ; delay W*100
        movlw   d'96'           ;
        goto    DelayW1         ; delay (15 <= W <= 255)

delay100ms:                     ; 100 ms is 250,000 instructions
        movlw   d'24'           ;
        call    DelayW10k       ; delay W*10000
        movlw   d'99'           ;
        call    DelayW100       ; delay W*100
        movlw   d'95'           ;
        goto    DelayW1         ; delay (15 <= W <= 255)

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
