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

	Version: 20231201

	Bare-metal C startup initialisations for the Intel Cyclone V SoC (HPS), ARM Cortex-A9.
	Mostly using HWLib.

	References:
		- Cyclone V SoC: Cyclone V Hard Processor System Technical Reference Manual
		- MMU          : ARM Architecture Reference Manual ARMv7-A and ARMv7-R edition. Notable refs: B3.5.1 Short-descriptor translation table format descriptors
*/

#include "startup.h"
#include "alt_cache.h"
#include "alt_mmu.h"

// =============
// Reset handler
// =============

// Notes:
// - Newlib will initialise the .bss section for us so no need to do it here
// - In Altera's HWLib their vector table is named __intc_interrupt_vector, see alt_interrupt.c
// - In Altera's HWLib their vector table sets _socfpga_main as the reset handler, see alt_interrupt.c
void reset_handler(void){
	__asm__(
		"CPSID if                                      \n"  // Mask interrupts

		// Setup stack for each exception mode
		// Note: When you call HWLib's interrupt init function the stacks will be change to a global variable array, and this setup will be dropped
		"CPS #0x11                                     \n"
		"LDR sp, =_FIQ_STACK_LIMIT                     \n"
		"CPS #0x12                                     \n"
		"LDR sp, =_IRQ_STACK_LIMIT                     \n"
		"CPS #0x13                                     \n"
		"LDR sp, =_SVC_STACK_LIMIT                     \n"
		"CPS #0x17                                     \n"
		"LDR sp, =_ABT_STACK_LIMIT                     \n"
		"CPS #0x1B                                     \n"
		"LDR sp, =_UND_STACK_LIMIT                     \n"
		"CPS #0x1F                                     \n"
		"LDR sp, =_SYS_STACK_LIMIT                     \n"
	);

	alt_cache_system_disable();                             // Disable L1 and L2 cache

	__asm__(
		// Enable permissions
		"MRC p15, 0, r0, c1, c1, 2                     \n"  // Read NSACR (Non-secure Access Control Register)
		"ORR r0, r0, #(0x3 << 20)                      \n"  // Setup bits to enable access permissions.  Undocumented Altera/Intel Cyclone V SoC vendor specific
		"MCR p15, 0, r0, c1, c1, 2                     \n"  // Write NSACR

		// Enable permission and turn on NEON/VFP (FPU)
		"MRC p15, 0, r0, c1, c0, 2                     \n"  // Read CPACR (Coprocessor Access Control Register)
		"ORR r0, r0, #(0xf << 20)                      \n"  // Setup bits to enable access to NEON/VFP (Coprocessors 10 and 11)
		"MCR p15, 0, r0, c1, c0, 2                     \n"  // Write CPACR (Coprocessor Access Control Register)
		"ISB                                           \n"  // Ensures CPACR write have completed before continuing
		"MOV r0, #0x40000000                           \n"  // Setup bits to turn on the NEON/VFP (Advanced SIMD and floating-point extensions)
		"VMSR fpexc, r0                                \n"  // Write FPEXC (Floating-Point Exception Control register)

		// Set Vector Base Address Register (VBAR)
		"LDR r0, =__intc_interrupt_vector              \n"  // Register the specified vector table
		"MCR p15, 0, r0, c12, c0, 0                    \n"
	);

#if MMU_ENABLE
	mmu_init();                                             // Setup MMU table and enable MMU
#endif

#if CACHE_ENABLE
	alt_cache_system_enable();                              // Enable and invalidate L1 and L2 cache
#endif

	__asm__(
		// =======================================
		// Initialise the SCU (Snoop Control Unit)
		// =======================================

		// Invalidate SCU
		"LDR r0, =0xfffec000UL                         \n"  // Load SCU base register
		"LDR r1, =0xffff                               \n"  // Value to write
		"STR r1, [r0, #0xc]                            \n"  // Write to SCU Invalidate All register (0xfffec00c)

	"#if CACHE_ENABLE                                  \n"
		// Enable SCU
		"LDR r0, =0xfffec000UL                         \n"  // Load SCU base register
		"LDR r1, [r0, #0x0]                            \n"  // Read SCU register
		"ORR r1, r1, #0x1                              \n"  // Set bit 0 (The Enable bit)
		"STR r1, [r0, #0x0]                            \n"  // Write back modified value
	"#endif                                            \n"

		"CPSIE if                                      \n"  // Unmask interrupts

		"BL _mainCRTStartup                            \n"  // Call C Run-Time library startup from newlib or libc, which will later call our main().  Alternatively, for newlib call BL _start (alias of the same function)

	"_infinity_loop:                                   \n"  // Catch unexpected main() return
		"B _infinity_loop                              \n"
	);
}

void _socfpga_main(void) __attribute__ ((unused, alias("reset_handler")));  // Alias Altera's HWLib reset handler to ours so it will be called on reset

// ===================
// MMU initialisations
// ===================

#if MMU_ENABLE
#define ARRAY_SIZE(array) (sizeof(array) / sizeof(array[0]))
static uint32_t __attribute__ ((__section__("MMU_TTB"))) alt_pt_storage[4096];  // This is the actual MMU table, which is placed at specified section, aligned to 16KB, defined in the linker file

// Define a dummy alloc for Altera's function is overly complicated MMU function!
static void *alt_pt_alloc(const size_t size, void *context){
	return context;
}

// We do not want cache in DEBUG mode

static void mmu_init(void){
	uint32_t *ttb1 = NULL;

	// Create MMU attributes (properties) only.
	// This is passed to the MMU function telling it what entries to create, and fills them into the MMU table
	// We only need multiple section entries (1 MB regions) of these 2 types
	ALT_MMU_MEM_REGION_t regions[] = {
		// Memory area: 3GB DDR-3 SDRAM
		{
			.va         = (void *)0x00000000,
			.pa         = (void *)0x00000000,
			.size       = 0xc0000000,
			.access     = ALT_MMU_AP_PRIV_ACCESS,
			.attributes = ALT_MMU_ATTR_WBA,
			.shareable  = ALT_MMU_TTB_S_SHAREABLE,
			.execute    = ALT_MMU_TTB_XN_DISABLE,
			.security   = ALT_MMU_TTB_NS_SECURE
		},
		// Device area: 1GB of everything else
		{
			.va         = (void *)0xc0000000,
			.pa         = (void *)0xc0000000,
			.size       = 0x40000000,
			.access     = ALT_MMU_AP_PRIV_ACCESS,
			.attributes = ALT_MMU_ATTR_DEVICE,
			.shareable  = ALT_MMU_TTB_S_SHAREABLE,
			.execute    = ALT_MMU_TTB_XN_ENABLE,
			.security   = ALT_MMU_TTB_NS_SECURE
		}

	};

	alt_mmu_init();
	alt_mmu_va_space_storage_required(regions, ARRAY_SIZE(regions));
	alt_mmu_va_space_create(&ttb1, regions, ARRAY_SIZE(regions), alt_pt_alloc, alt_pt_storage);
	alt_mmu_va_space_enable(ttb1);
}
#endif