# "Hello, World!" for the DE10-Nano development board

## Overview

This contains a basic "Hello, World!" bare-metal C program for the DE10-Nano
development board.

## Build requirements

Minimum:
- GNU C/C++ cross toolchain for Arm processors supporting Cortex A9
- newlib library.  This is usually included with the above toolchain

This sample includes the project file for Eclipse IDE for Embedded C/C++
Developers but you will need to setup other things as described in my guide.

You can find the guide on my website:
[https://truhy.co.uk](https://truhy.co.uk)

## Notes

It seems the Arria V SoC-FPGA series use the same peripheral controllers so I
think this sample should also work for those.  I don't have an Arria V
development board to test with so cannot confirm.

If you are using other development board you may have to rebuild U-Boot-SPL and
the Quartus Prime project handoff files to support your development board.  As
an example, on the DE10-Nano board USB-UART is wired to HPS UART0, but for
another board it may be to HPS UART1.

This sample uses the Intel/Altera HWLIB to send a "Hello, World!" message
using the HPS UART0 controller. The message is sent out to the USB-UART, i.e.
the micro USB connector on the development board.  To view the serial messages,
start a standard serial com terminal software (e.g. Putty) and set it to use the
relevant com port with the following settings:
115200 baud, 8 data bits, no parity and 1 stop bit.

HWLIB already contains a bare-metal "Hello, World!" sample but it requires
the licensed ARM DS-5 IDE to work, while mine only need the standard Eclipse IDE
for Embedded C/C++ Developers.

Some of the things demonstrated:
- Setup UART0 using HWLIB
- Minimal newlib extension for some required stubs
- Semihosting debug printing
- UART0 debug printing