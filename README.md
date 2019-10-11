# PICDIV
PICDIV - Microchip PIC microcontroller based 10MHz to 1PPS divider/counter, from http://www.leapsecond.com/pic/picdiv.htm

Use e.g. PIC12F675 https://ww1.microchip.com/downloads/en/devicedoc/41190c.pdf
An example board is e.g. https://github.com/aewallin/PICDIV_Board_v3

Takes frequency input, e.g. 10 MHz, as clock-source for the PIC, and produces a frequency divided output, e.g. 1PPS, that is accurately phase-coherenent with the input clock.

## Build

On Ubuntu, or Debian-like Linux, compiling the .ASM assembler-sources into a HEX-file that can be written to the PIC can be done with:

```
sudo apt install gputils
mkdir build
gpasm ./src/pd03.asm -I ./src -o ./build/pd03.hex
diff ./build/pd03.hex ./hex/pd03.hex
```
The last step checks for differences between the newly built hex-file and the hex-file available from leapsecond.com.
There should be no differences.

## Programming

This section should describe programming the PIC using the HEX file and an ICSP-tool.

## Variants

* pd03.asm / pd03.hex / PD03 -- "4-pin" 10^3 frequency divider (10 MHz to 10 kHz)
* pd04.asm / pd04.hex / PD04 -- "4-pin" 10^4 frequency divider (10 MHz to 1 kHz)
* pd05.asm / pd05.hex / PD05 -- "4-pin" 10^5 frequency divider (10 MHz to 100 Hz)
* pd06.asm / pd06.hex / PD06 -- "4-pin" 10^6 frequency divider (10 MHz to 10 Hz)
* pd07.asm / pd07.hex / PD07 -- "4-pin" 10^7 frequency divider (10 MHz to 1 Hz)
* pd08.asm / pd08.hex / PD08 -- "4-pin" 5x10^6 frequency divider (5 MHz to 1 Hz)
* pd09.asm / pd09.hex / PD09 -- "4-pin" 10 MHz to 1PPS frequency divider (20 us pulse)
* pd10.asm / pd10.hex / PD10 -- "4-pin" 10 MHz to 1PPS frequency divider (10 ms pulse)
* pd11.asm / pd11.hex / PD11 -- 10 MHz to 1PPS frequency divider (3 pulse widths), with sync
* pd12.asm / pd12.hex / PD12 -- 5 MHz to 1PPS frequency divider (3 pulse widths), with sync
* pd13.asm / pd13.hex / PD13 -- 10 MHz to three frequencies divider (1-10-100 Hz), with sync
* pd14.asm / pd14.hex / PD14 -- 5 MHz to three frequencies divider (1-10-100 Hz), with sync
* pd15.asm / pd15.hex / PD15 -- 10 MHz to three frequencies divider (1-1000-10000 Hz), with sync
* pd16.asm / pd16.hex / PD16 -- 5/10 MHz to four frequencies divider (1-10-100-1000 Hz)
* pd17.asm / pd17.hex / PD17 -- 1/2.5/5/10 MHz to 1PPS frequency divider (100 ms), with sync
* pd18.asm / pd18.hex / PD18 -- 1/2.5/5/10 MHz to 1PPS frequency divider (10 ms), with sync
* pd26.asm / pd26.hex / PD26 -- 10 MHz to 1PPS divider, with sync and micro-step
* pd27.asm / pd27.hex / PD27 -- 10 MHz to 1PPS divider, with sync and milli-step
* pd28.asm / pd28.hex / PD28 -- 10 MHz to sidereal 1PPS divider, with sync and milli-step
