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

	Version: 20240505
	Target : ARM Cortex-A9 on the DE10-Nano development board (Intel Cyclone V SoC FPGA)
	Type   : Bare-metal C

	A basic "Hello, World!" bare-metal C program for the DE10-Nano
	development board.  It is for the SoC (aka HPS) part of the FPGA so it
	should work on other Cyclone V SoC-FPGA dev boards, e.g.: DE1-SoC, DE-10
	Standard, Arrow SoCKit, etc.
*/

#include "tru_config.h"
#include "tru_logger.h"
#include <stdio.h>

#ifdef SEMIHOSTING
	extern void initialise_monitor_handles(void);  // Reference function header from the external Semihosting library
#endif

#if(TRU_DEBUG_PRINT_L_SECTIONS == 1U && defined(TRU_DEBUG_PRINT_LEVEL) && TRU_DEBUG_PRINT_LEVEL >= 1U)
	extern long unsigned int __TTB_BASE;         // Reference external symbol name from the linker file
	extern long unsigned int __data_start;       // Reference external symbol name from the linker file
	extern long unsigned int __data_end;         // Reference external symbol name from the linker file
	extern long unsigned int __bss_start__;      // Reference external symbol name from the linker file
	extern long unsigned int __bss_end__;        // Reference external symbol name from the linker file
	extern long unsigned int __heap_start;       // Reference external symbol name from the linker file
	extern long unsigned int __heap_end;         // Reference external symbol name from the linker file
	extern long unsigned int __SYS_STACK_BASE;   // Reference external symbol name from the linker file
	extern long unsigned int __SYS_STACK_LIMIT;  // Reference external symbol name from the linker file

	void disp_linker_sections(void){
		DEBUG_PRINTF("Linker sections:\n");
		DEBUG_PRINTF("__TTB_BASE       : 0x%.8x\n", &__TTB_BASE);
		DEBUG_PRINTF("__data_start     : 0x%.8x\n", &__data_start);
		DEBUG_PRINTF("__data_end       : 0x%.8x\n", &__data_end);
		DEBUG_PRINTF("__bss_start__    : 0x%.8x\n", &__bss_start__);
		DEBUG_PRINTF("__bss_end__      : 0x%.8x\n", &__bss_end__);
		DEBUG_PRINTF("__heap_start     : 0x%.8x\n", &__heap_start);
		DEBUG_PRINTF("__heap_end       : 0x%.8x\n", &__heap_end);
		DEBUG_PRINTF("__SYS_STACK_BASE : 0x%.8x\n", &__SYS_STACK_BASE);
		DEBUG_PRINTF("__SYS_STACK_LIMIT: 0x%.8x\n\n", &__SYS_STACK_LIMIT);
	}
#endif

// =============================
// "Hello, World!" demonstration
// =============================

void tx_hello(void){
	printf("Hello, World!\n");
}

// ====================================
// U-Boot input arguments demonstration
// ====================================

// Display CLI arguments
void tx_cli_args(int argc, char *const argv[]){
	printf("Arguments from U-Boot:\n");

	// Display input arguments count from U-Boot
	printf("argc: %i\n", argc);

	if(argc){
		// Display input argument value from U-Boot
		for(int i = 0; i < argc; i++){
			printf("argv[%i]: %s\n", i, argv[i]);
		}
	}else{
		printf("none\n");
	}
}

void tx_exit(void){
	printf("Exiting application..\n");
}

int main(int argc, char *const argv[]){
	#ifdef SEMIHOSTING
		initialise_monitor_handles();  // Initialise Semihosting
	#endif

#if(TRU_DEBUG_PRINT_L_SECTIONS == 1U && defined(TRU_DEBUG_PRINT_LEVEL) && TRU_DEBUG_PRINT_LEVEL >= 1U)
	disp_linker_sections();
#endif

#if(TRU_EXIT_TO_UBOOT == 0U)
	tx_hello();
#else
	//tx_cli_args(argc, argv);
	tx_cli_args(uboot_argc, uboot_argv);
	tx_hello();
	tx_exit();
	tru_hps_uart_ll_wait_empty((TRU_TARGET_TYPE *)TRU_HPS_UART0_BASE);  // Before returning to U-Boot, we will wait for the UART to empty out
#endif

	return 0xa9;
}
