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

#ifndef STARTUP_H
#define STARTUP_H

// We do not want cache in DEBUG mode
#ifdef DEBUG
	#ifndef CACHE_ENABLE
		#define CACHE_ENABLE (0)
	#endif
	#ifndef MMU_ENABLE
		#define MMU_ENABLE (0)
	#endif
#else
	#ifndef CACHE_ENABLE
		#define CACHE_ENABLE (1)
	#endif
	#ifndef MMU_ENABLE
		#define MMU_ENABLE (1)
	#endif
#endif

// This should match with your compiler/linker flag
#ifndef NEON_ENABLE
	#define NEON_ENABLE (1)
#endif

#if MMU_ENABLE
static void mmu_init(void);
#endif

#endif
