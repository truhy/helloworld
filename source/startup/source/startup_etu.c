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

	Version: 20231230

	Bare-metal C startup initialisations for the Intel Cyclone V SoC (HPS), ARM Cortex-A9.
	Mostly using HWLib.

	References:
		- Cyclone V SoC: Cyclone V Hard Processor System Technical Reference Manual
		- MMU          : ARM Architecture Reference Manual ARMv7-A and ARMv7-R edition. Notable refs: B3.5.1 Short-descriptor translation table format descriptors
*/

#ifdef EXIT_TO_UBOOT

#include "startup.h"
#include "alt_cache.h"
#include "alt_mmu.h"
#include "alt_interrupt.h"

extern long unsigned int __bss_start__;  // Reference external symbol name from the linker file
extern long unsigned int __bss_end__;    // Reference external symbol name from the linker file
extern int main(int argc, char *const argv[]);

void zero_bss(void){
	// Zero fill .bss section.  The OS or std library normally does, else we have to do it
	long unsigned int *dst = &__bss_start__;
	while(dst < &__bss_end__) *dst++ = 0;  // Zero fill
}

// Initialise with non-zero value so that it is treated as initialised global variable and put into data section
// Note, must use a non-zero value, other the compiler may optimise to uninitialised global variable
int uboot_argc = 1;
char **uboot_argv = (char **)1;

#if(MMU_ENABLE)
static void mmu_init(void);
#endif

// =============
// Reset handler
// =============

// Notes:
// - Newlib will initialise the .bss section for us so no need to do it here
// - In Altera's HWLib their vector table is named __intc_interrupt_vector, see alt_interrupt.c
// - In Altera's HWLib, their vector table branches to _socfpga_main() as the reset handler, see alt_interrupt.c
int reset_handler(int argc, char *const argv[]){
	// Store the U-Boot passed in arguments because they will be clobbered (destroyed) by the initialisation code below
	uboot_argc = argc;
	uboot_argv = (char **)argv;

	__asm__ volatile(
		"CPSID if                                      \n"  // Mask interrupts
	);

#if(L2_CACHE_ENABLE != 2)
    // Disable L2 cache
	alt_cache_l2_disable();
	alt_cache_l2_parity_disable();
	alt_cache_l2_prefetch_disable();
	alt_cache_l2_uninit();
#endif

#if(L1_CACHE_ENABLE != 2)
	alt_cache_l1_disable_all();                             // Disable L1 cache
#endif

	__asm__ volatile(
		// Enable permissions
		"MRC p15, 0, r0, c1, c1, 2                     \n"  // Read NSACR (Non-secure Access Control Register)
		"ORR r0, r0, #(0x3 << 20)                      \n"  // Setup bits to enable access permissions.  Undocumented Altera/Intel Cyclone V SoC vendor specific
		"MCR p15, 0, r0, c1, c1, 2                     \n"  // Write NSACR

#if(NEON_ENABLE)
		// Enable permission and turn on NEON/VFP (FPU)
		"MRC p15, 0, r0, c1, c0, 2                     \n"  // Read CPACR (Coprocessor Access Control Register)
		"ORR r0, r0, #(0xf << 20)                      \n"  // Setup bits to enable access to NEON/VFP (Coprocessors 10 and 11)
		"MCR p15, 0, r0, c1, c0, 2                     \n"  // Write CPACR (Coprocessor Access Control Register)
		"ISB                                           \n"  // Ensures CPACR write have completed before continuing
		"MOV r0, #0x40000000                           \n"  // Setup bits to turn on the NEON/VFP (Advanced SIMD and floating-point extensions)
		"VMSR fpexc, r0                                \n"  // Write FPEXC (Floating-Point Exception Control register)
#endif
	);

#if(MMU_ENABLE)
	mmu_init();                                             // Setup MMU table and enable MMU
#endif

#if(SMP_COHERENCY_ENABLE)
	__asm__ volatile(
		// Enable SMP cache coherence support, i.e. enables MMU TLB cache broadcast for multi-processors
		"MRC p15, 0, r0, c1, c0, 1                     \n"  // Read ACTLR
		"ORR r0, r0, #(0x1 << 6)                       \n"  // Set bit 6 to participate in SMP coherency
		"ORR r0, r0, #(0x1 << 0)                       \n"  // Set bit 0 to enable maintenance broadcast
		"MCR p15, 0, r0, c1, c0, 1                     \n"  // Write ACTLR
	);
#endif

#if(L1_CACHE_ENABLE == 1)
	alt_cache_l1_enable_all();                              // Enable and invalidate L1 cache
#endif

#if(L2_CACHE_ENABLE == 1)
	alt_cache_l2_init();
	alt_cache_l2_prefetch_enable();
	alt_cache_l2_parity_enable();
	alt_cache_l2_enable();                                  // Enable and invalidate L2 cache
#endif

	__asm__ volatile(
		// =======================================
		// Initialise the SCU (Snoop Control Unit)
		// =======================================

#if(SCU_ENABLE)
		// Invalidate SCU
		"LDR r0, =0xfffec000UL                         \n"  // Load SCU base register
		"LDR r1, =0xffff                               \n"  // Value to write
		"STR r1, [r0, #0xc]                            \n"  // Write to SCU Invalidate All register (0xfffec00c)

		// Enable SCU
		"LDR r0, =0xfffec000UL                         \n"  // Load SCU base register
		"LDR r1, [r0, #0x0]                            \n"  // Read SCU register
		"ORR r1, r1, #0x1                              \n"  // Set bit 0 (The Enable bit)
		"STR r1, [r0, #0x0]                            \n"  // Write back modified value
#endif

		"CPSIE if                                      \n"  // Unmask interrupts
	);
	zero_bss();                           // Since we are not calling newlib _startup() we will init the bss
	return main(uboot_argc, uboot_argv);  // Branch to main().  When main() returns we will return to U-Boot
}

// =======================
// Set HWLib reset handler
// =======================
// For exit to U-Boot we won't be using HWLib's vector, just setting this up to make it happy
#if(ALT_INT_PROVISION_VECTOR_SUPPORT != 0)
void hwlib_reset_handler(void){
	reset_handler(0, 0);
}
void _socfpga_main(void) __attribute__((unused, alias("hwlib_reset_handler")));  // Alias Altera's HWLib reset handler to our function
#endif

// ===================
// MMU initialisations
// ===================

// *Note: Altera's MMU alt_mmu_va_space_create() function will create a huge local array!!  Ensure your stack space is greater than 4K = 4096 bytes!
#if(MMU_ENABLE)
#define TTB_ATTRIB_ARRAY_SIZE(array) (sizeof(array) / sizeof(array[0]))
static long unsigned int __attribute__((__section__("MMU_TTB"))) mmu_ttb[4096];  // This array is the MMU table.  It is placed at the specified linker section, aligned to 16KB, defined in the linker file

// Define a dummy memory alloc for Altera's MMU function
static void *mmu_ttb_alloc(const size_t size, void *context){
	return mmu_ttb;
}

static void mmu_init(void){
	long unsigned int *ttb1 = NULL;

	// Create MMU attributes (properties)
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
	alt_mmu_va_space_storage_required(regions, TTB_ATTRIB_ARRAY_SIZE(regions));
	alt_mmu_va_space_create(&ttb1, regions, TTB_ATTRIB_ARRAY_SIZE(regions), mmu_ttb_alloc, NULL);
	alt_mmu_va_space_enable(ttb1);
}
#endif

#endif
