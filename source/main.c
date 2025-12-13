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

	Version: 20251206
	Target : ARM Cortex-A9 on the DE10-Nano Kit development board (Altera
	         Cyclone V SoC FPGA)
	Type   : Stand-alone C application

	A basic "Hello, World!" bare-metal C program for the DE10-Nano Kit
	development board.  It is for the SoC (aka HPS) part of the FPGA.

	=========
	Libraries
	=========

	Open source libraries used (already included in this example):
		- CMSIS
		- Trulib and GNU linker script (my own library and script)
		- Newlib (included with the GNU Toolchain for Arm)
*/

#include "tru_config.h"
#include "tru_logger.h"
#include "tru_util_ll.h"
#include "c5soc/tru_c5soc_hps_clkmgr_ll.h"
#include <stdio.h>

// Set 1 to enable, 0 to disable
#define DISP_LINKER_SECTIONS 0U

#ifdef SEMIHOSTING
	extern void initialise_monitor_handles(void);  // Reference function header from the external Semihosting library
#endif

#if (DISP_LINKER_SECTIONS == 1U)
	extern long unsigned int __mmu_ttb_l1_entries_start;  // Reference external symbol name from the linker file
	extern long unsigned int __data_start;                // Reference external symbol name from the linker file
	extern long unsigned int __data_end;                  // Reference external symbol name from the linker file
	extern long unsigned int __bss_start__;               // Reference external symbol name from the linker file
	extern long unsigned int __bss_end__;                 // Reference external symbol name from the linker file
	extern long unsigned int __heap_start;                // Reference external symbol name from the linker file
	extern long unsigned int __heap_end;                  // Reference external symbol name from the linker file
	extern long unsigned int __SYS_STACK_BASE;            // Reference external symbol name from the linker file
	extern long unsigned int __SYS_STACK_LIMIT;           // Reference external symbol name from the linker file

	void disp_linker_sections(void){
		LOG("Linker sections:\n");
		LOG("__mmu_ttb_l1_entries_start: 0x%.8x\n", &__mmu_ttb_l1_entries_start);
		LOG("__data_start              : 0x%.8x\n", &__data_start);
		LOG("__data_end                : 0x%.8x\n", &__data_end);
		LOG("__bss_start__             : 0x%.8x\n", &__bss_start__);
		LOG("__bss_end__               : 0x%.8x\n", &__bss_end__);
		LOG("__heap_start              : 0x%.8x\n", &__heap_start);
		LOG("__heap_end                : 0x%.8x\n", &__heap_end);
		LOG("__SYS_STACK_BASE          : 0x%.8x\n", &__SYS_STACK_BASE);
		LOG("__SYS_STACK_LIMIT         : 0x%.8x\n\n", &__SYS_STACK_LIMIT);
	}
#endif

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

int main(int argc, char *const argv[]){
	#ifdef SEMIHOSTING
		initialise_monitor_handles();  // Initialise Semihosting
	#endif

	printf("Hello, World!\n");

	#if (DISP_LINKER_SECTIONS == 1U)
		disp_linker_sections();
	#endif

	#if(TRU_EXIT_TO_UBOOT == 1U)
		//tx_cli_args(argc, argv);
		tx_cli_args(uboot_argc, uboot_argv);

		printf("Exiting application..\n");
		tru_hps_uart_ll_wait_empty((void *)TRU_HPS_UART0_BASE);  // Before returning to U-Boot, we will wait for the UART to empty out
	#endif

	return 0xa9;  // Returns to the newlib _exit() stub
}
