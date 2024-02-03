/*
	MIT License

	Copyright (c) 2023 Truong Hy

	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included in all
	copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
	SOFTWARE.

	Version: 20240203
	Target : ARM Cortex-A9 on the DE10-Nano development board (Intel Cyclone V SoC FPGA)
	Type   : Bare-metal C

	A basic "Hello, World!" bare-metal C program for the DE10-Nano
	development board.  It is for the SoC (aka HPS) part of the FPGA so it
	should work on other Cyclone V SoC-FPGA dev boards, e.g.: DE1-SoC, DE-10
	Standard, Arrow SoCKit, etc.
*/

#include "tru_config.h"
#include "tru_c5_uart.h"
#include "tru_logger.h"
#include <string.h>

#ifdef SEMIHOSTING
	extern void initialise_monitor_handles(void);  // Reference function header from the external Semihosting library
#endif

// =============================
// "Hello, World!" demonstration
// =============================

char message[] = "Hello, World!\r\n";

// Transmit hello message
void tx_hello(void){
	tru_c5_uart_write_str(TRU_C5_UART0_BASE_ADDR, message, strlen(message));
}

// ====================================
// U-Boot input arguments demonstration
// ====================================

enum message_id{
	MSG_INPUTS,
	MSG_ARGC,
	MSG_ARGV,
	MSG_NEWLINE,
	MSG_NONE,
	MSG_EXIT
};

// Messages
const char *messages[] = {
	"Arguments from U-Boot:\r\n",
	"argc: 0x",
	"argv: ",
	"\r\n",
	"none\r\n",
	"Exiting application..\r\n"
};

// Transmit CLI arguments
void tx_cli_args(int argc, char *const argv[]){
	tru_c5_uart_write_str(TRU_C5_UART0_BASE_ADDR, messages[MSG_INPUTS], strlen(messages[MSG_INPUTS]));

	// Transmit input arguments count from U-Boot
	tru_c5_uart_write_str(TRU_C5_UART0_BASE_ADDR, messages[MSG_ARGC], strlen(messages[MSG_ARGC]));
	tru_c5_uart_write_inthex(TRU_C5_UART0_BASE_ADDR, argc, 32);
	tru_c5_uart_write_str(TRU_C5_UART0_BASE_ADDR, messages[MSG_NEWLINE], strlen(messages[MSG_NEWLINE]));

	if(argc){
		// Transmit input argument value from U-Boot
		for(int i = 0; i < argc; i++){
			tru_c5_uart_write_str(TRU_C5_UART0_BASE_ADDR, messages[MSG_ARGV], strlen(messages[MSG_ARGV]));
			tru_c5_uart_write_str(TRU_C5_UART0_BASE_ADDR, argv[i], strlen(argv[i]));
			tru_c5_uart_write_str(TRU_C5_UART0_BASE_ADDR, messages[MSG_NEWLINE], strlen(messages[MSG_NEWLINE]));
		}
	}else{
		tru_c5_uart_write_str(TRU_C5_UART0_BASE_ADDR, messages[MSG_NONE], strlen(messages[MSG_NONE]));
	}
}

int main(int argc, char *const argv[]){
	#ifdef SEMIHOSTING
		initialise_monitor_handles();  // Initialise Semihosting
	#endif

#if(TRU_EXIT_TO_UBOOT)
	//tx_cli_args(argc, argv);
	tx_cli_args(uboot_argc, uboot_argv);
	tx_hello();
	tru_c5_uart_write_str(TRU_C5_UART0_BASE_ADDR, messages[MSG_EXIT], strlen(messages[MSG_EXIT]));
	tru_c5_uart_wait_empty(TRU_C5_UART0_BASE_ADDR);  // Before returning to U-Boot, we will wait for the UART to empty out
#else
	tx_hello();
#endif

	return 0xa9;
}
