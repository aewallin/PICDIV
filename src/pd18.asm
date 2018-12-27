; ------------------------------------------------------------------------
;
; Title:
;
;   PD18 -- PIC 1/2.5/5/10 MHz to 1PPS frequency divider (10 ms), with sync
;
; Function:
;
;   This PIC program implements a digital frequency divider: cpu hardware
;   and isochronous software divide the input clock by 1 to 10 million.
;
;   - This version allows two Config input pins to set the divide ratio
;     (1, 2.5, 5, or 10 MHz input clock). The output is 1PPS (one pulse
;     per second) with 1% duty cycle (10 ms width).
;
;   - Two inputs support optional manual 1PPS synchronization. Pull Arm
;     pin low for a second to stop divider. All outputs will synchronize
;     to next rising edge of Sync pin (within one instruction cycle).
;
; Diagram:
;                                ---__---
;                5V (Vdd)  +++++|1      8|=====  Ground (Vss)
;          N MHz clock in  ---->|2  pD  7|<+---  ConfigA
;                1PPS out  <----|3  18  6|<+---  ConfigB
;                     Arm  o--->|4      5|<+---  Sync
;                                --------
; Notes:
;
;   o External pull-up required on Arm input (pin4/GP3).
;   + Sync input (pin5/GP2) has internal WPU.
;   + Config inputs (pin7/GP0, pin6/GP1) have internal WPU.
;   Output frequency accuracy is the same as clock input accuracy.
;   Output drive current is 25 mA maximum per pin.
;   Coded for Microchip 12F675 but any '609 '615 '629 '635 '675 '683 works.
;
; Version:
;
;   06-Feb-2013  Tom Van Baak (tvb)  www.LeapSecond.com/pic
;
; ------------------------------------------------------------------------

; Microchip MPLAB IDE assembler code (mpasm).

        list        p=pic12f675
        include     p12f675.inc
        __config    _EC_OSC & _MCLRE_OFF & _WDT_OFF

; Define 1PPS output duty cycle (percent).

DUTYPCT equ     d'1'

; Register definitions.

        cblock  0x20            ; define register base
            gpcopy              ; shadow of output pins
            cent                ; 100 Hz loop index
        endc

; Define entry points.

        org     0               ; power-on entry
        goto    init            ;
        org     4               ; interrupt entry
        goto    sync            ;

; One-time PIC 12F675 initialization.

init:   bcf     STATUS,RP0      ; bank 0
#ifdef CMCON    ; if this chip has comparator...
        movlw   0x07            ; turn comparator off
        movwf   CMCON           ;
#endif
        clrf    GPIO            ; set output latches low

        bsf     STATUS,RP0      ; bank 1
        errorlevel -302
#ifdef ANSEL    ; if this chip has ADC...
        clrf    ANSEL           ; all digital (no analog) pins
#endif
        movlw   ~(1<<GP4)
        movwf   TRISIO          ; set pin directions (0=output)
        movlw   1<<GP2 | 1<<GP1 | 1<<GP0
        movwf   WPU             ; enable weak pullup (1=enable)
        movlw   1<<INTEDG       ; WPU, GP2/INT rising edge trigger
        movwf   OPTION_REG      ;
        errorlevel +302
        bcf     STATUS,RP0      ; bank 0
        call    clear           ; initialize counter and pins

; The main loop runs continuously at exactly 100 Hz (10 ms period)
; counting modulo 100 in order to implement the chosen duty cycle.
; The output frequency is 1 Hz (1PPS).

loop:   movf    gpcopy,W        ; gpcopy -> W
        movwf   GPIO            ; W -> GPIO
        call    Delay5          ; (sync alignment)
sync:   call    armed           ; check for Arm request

        ; Update loop counter, check duty cycle, set output state.

        incf    cent,F          ; increment loop counter
        movlw   d'100'          ;
        subwf   cent,W          ; compare limit
        skpnz                   ;
          clrf  cent            ; reset to zero

        clrf    gpcopy          ; assume output low
        movlw   DUTYPCT         ;
        subwf   cent,W          ; compare duty cycle
        skpc                    ;
          bsf  gpcopy,GP4       ; set output high

        ; First, pad loop to 100 instructions (use MPLAB SIM).

        movlw   d'62'           ;
        call    DelayW1         ; delay (15 <= W <= 255)

        ; Then, pad loop to 10 milliseconds, based on clock configuration.

        call    Delay10ms       ; 10 ms configurable delay
        goto    loop

; This function delays 10 ms (minus 100 instructions already executed).
; - The heart of this divider is the ability to generate 1PPS output with
;   any of four different input clock frequencies. This is accomplished
;   by adjusting loop delays according to the configured input clock.
; - The user specifies the input clock rate with pin7/GP0 and pin6/GP1.

Delay10ms:
        movf    GPIO,W          ; get config bits
        andlw   3               ; 2-bits
        addwf   PCL,F           ; jump PCL+W (computed goto)
          goto  mhz1            ; 00 =  1.0 MHz
          goto  mhz25           ; 01 =  2.5 MHz
          goto  mhz5            ; 10 =  5.0 MHz
          goto  mhz10           ; 11 = 10.0 MHz (default)

        ; Given 1 MHz clock (Tcy 4.0 us), 10 ms is 2,500 instructions.

mhz1    movlw   d'25'-2         ;
        call    DelayW100       ; delay W*100
        movlw   d'100'          ;
        goto    DelayW1         ; delay (15 <= W <= 255)

        ; Given 2.5 MHz clock (Tcy 1.6 us), 10 ms is 6,250 instructions.

mhz25   movlw   d'62'-2         ;
        call    DelayW100       ; delay W*100
        movlw   d'150'          ;
        goto    DelayW1         ; delay (15 <= W <= 255)

        ; Given 5 MHz clock (Tcy 0.8 us), 10 ms is 12,500 instructions.

mhz5    movlw   d'125'-2        ;
        call    DelayW100       ; delay W*100
        movlw   d'100'          ;
        goto    DelayW1         ; delay (15 <= W <= 255)

        ; Given 10 MHz clock (Tcy 0.4 us), 10 ms is 25,000 instructions.

mhz10   movlw   d'250'-2        ;
        call    DelayW100       ; delay W*100
        movlw   d'100'          ;
        goto    DelayW1         ; delay (15 <= W <= 255)

; Initialize index (zero) and output pins (high).

clear:  clrf    cent
        movlw   1<<GP4
        movwf   gpcopy
        return

; Implement two-pin 1PPS Arm-Sync synchronization protocol.
; - Accept Arm (low) request when output(s) are high.
; - Use GP2/INT interrupt to keep accuracy within 1 Tcy.
; - Divider resets and resumes on rising edge of Sync pin.
; - Re-enter main loop late to compensate for interrupt/code latency.

armed:  movf    GPIO,W          ; GPIO -> W
        andlw   (1<<GP4 | 1<<GP3)
        xorlw   (1<<GP4)
        skpz                    ; Arm low, output(s) high?
          return                ;   no, continue running

        call    clear           ; initialize counter and pins
        movlw   1<<GIE|1<<INTE  ; enable GP2 edge-trigger interrupt
        movwf   INTCON          ;   (and clear interrupt flags)
        goto    $               ; no deposit, no return, no retfie

        include delayw.asm      ; precise delay functions
        end
