# This is free script released into the public domain.
# GNU make file v20231220 created by Truong Hy.
#
# Builds bare-metal source for the Intel Cyclone V SoC.
# Depending on the options it will output the following application files:
#   - elf (.elf)
#   - binary (.bin)
#   - U-Boot image (.uimg)
#   - SD card image (.img)
#
# For usage, type make help
#
# Linux requirements (tested only under Ubuntu):
#   - Bash command-line utilities
#
# Windows limitations:
#   - Natively supports building the C/C++ sources into elf, bin or uimg
#   - Natively does not support building the SD card image and U-Boot, for these use WSL2, Cygwin or MSYS2
#
# Common requirements:
#   - GCC ARM cross compiler toolchain.  The bin directory added to the search path
#   - GNU make (for Windows use xPack's build tools).  The bin directory added to the search path
#
# U-Boot preparation and SD card image requirements, please see the makefiles:
#   - Makefile-prep-ub.mk
#   - Makefile-sd-alt.mk
#   - Makefile-sd-tru.mk
#
# U-Boot's own build dependencies on a fresh Ubuntu 22.04.3 LTS distro:
#   - GNU make
#   - GCC ARM cross compiler toolchain (for building target U-Boot)
#   - gcc (for building host tools)
#   - bison
#   - flex
#   - libssl-dev
#   - bc
#
# This makefile is already complicated, but to keep things a bit more simple:
#   - We assume the required global variables are already set
#   - We assume the required files and paths are relative to the location of this Makefile

# Optional commandline parameters
semi ?= 0
bin ?= 0
uimg ?= 0
sd ?= 0
ub ?= 0
alt ?= 0

ifeq ($(OS),Windows_NT)
ifeq ($(sd),1)
$(error sd=1 parameter is not supported natively in Windows)
endif
ifeq ($(ub),1)
$(error ub=1 parameter is not supported natively in Windows)
endif
endif

# These variables are assumed to be set already
ifndef PROGRAM_NAME
$(error PROGRAM_NAME environment variable is not set)
endif
ifndef BM_HOME_PATH
$(error BM_HOME_PATH environment variable is not set)
endif
ifndef BM_OUT_PATH
$(error BM_OUT_PATH environment variable is not set)
endif
ifndef BM_SRC_PATH
$(error BM_SRC_PATH environment variable is not set)
endif
ifeq ($(ub),1)
ifndef UBOOT_DEFCONFIG
$(error UBOOT_DEFCONFIG env. variable not set, e.g. export UBOOT_DEFCONFIG=socfpga_de10_nano_defconfig)
endif
ifndef UBOOT_OUT_PATH
$(error UBOOT_OUT_PATH env. variable not set)
endif
endif
ifeq ($(sd),1)
ifndef SD_OUT_PATH
$(error SD_OUT_PATH environment variable is not set)
endif
endif

# Convert back-slashes
ifeq ($(OS),Windows_NT)
BM_HOME_PATH := $(subst \,/,$(BM_HOME_PATH))
BM_OUT_PATH := $(subst \,/,$(BM_OUT_PATH))
BM_SRC_PATH := $(subst \,/,$(BM_SRC_PATH))
UBOOT_OUT_PATH := $(subst \,/,$(UBOOT_OUT_PATH))
SD_OUT_PATH := $(subst \,/,$(SD_OUT_PATH))
endif

ifeq ($(sd),1)
# Force only one of these options for SD card image
ifeq ($(uimg),1)
bin := 0
else
bin := 1
endif
endif

# Export some SD card image environment variables
ifeq ($(sd),1)
include scripts-linux/sdcard/Makefile-sd-env.mk
endif

# ===============
# Common settings
# ===============

UBOOT_IN_PATH := scripts-linux/uboot
SD_IN_PATH := scripts-linux/sdcard

# ============
# Source files
# ============

# List of source folders and files to exclude from the build
EXCLUDE_SRC := \
	$(BM_SRC_PATH)/hwlib/src/hwmgr/soc_a10 \
	$(BM_SRC_PATH)/hwlib/src/hwmgr/alt_eth_phy_ksz9031.c \
	$(BM_SRC_PATH)/hwlib/src/hwmgr/alt_ethernet.c \
	$(BM_SRC_PATH)/hwlib/src/utils/alt_base.S \
	$(BM_SRC_PATH)/hwlib/src/utils/alt_base.c \
	$(BM_SRC_PATH)/hwlib/src/utils/alt_p2uart.c \
	$(BM_SRC_PATH)/hwlib/src/utils/alt_printf.c

# Get and build a list of source file names from the file system with these locations and pattern
C_SRC := \
	$(wildcard $(BM_SRC_PATH)/*.c) \
	$(wildcard $(BM_SRC_PATH)/hwlib/src/hwmgr/*.c) \
	$(wildcard $(BM_SRC_PATH)/hwlib/src/hwmgr/soc_cv_av/*.c) \
	$(wildcard $(BM_SRC_PATH)/hwlib/src/utils/*.c) \
	$(wildcard $(BM_SRC_PATH)/hwlib/src/utils/*.S) \
	$(wildcard $(BM_SRC_PATH)/util/source/*.c)
	
# Remove exclude files
C_SRC := $(filter-out $(EXCLUDE_SRC),$(C_SRC))

# List of header include search paths
INCFLAGS := \
	-I$(BM_SRC_PATH) \
	-I$(BM_SRC_PATH)/bsp_generated \
	-I$(BM_SRC_PATH)/hwlib/include \
	-I$(BM_SRC_PATH)/hwlib/include/soc_cv_av \
	-I$(BM_SRC_PATH)/util/include

# The linker script to use
LINKER_SCRIPT := $(BM_SRC_PATH)/ldscript/tru_c5_ddr.ld

# Load address defined in the linker script
LOAD_ADDR := 0x1040

# =========================================
# Common linker and compiler build settings
# =========================================

CFLAGS := -mcpu=cortex-a9 -mfloat-abi=hard -mfpu=neon -mno-unaligned-access -fmessage-length=0 -fsigned-char -ffunction-sections -fdata-sections -std=gnu11 -mgeneral-regs-only
LDFLAGS := -Xlinker --gc-sections --specs=nosys.specs

# ====================
# Debug build settings
# ====================

DBG_PATH := $(BM_OUT_PATH)/Debug
DBG_ELF := $(DBG_PATH)/$(PROGRAM_NAME).elf
DBG_ELF_ENTRY_FILE := $(DBG_PATH)/$(PROGRAM_NAME).entry.txt
DBG_BIN := $(DBG_PATH)/$(PROGRAM_NAME).bin
DBG_UIMG := $(DBG_PATH)/$(PROGRAM_NAME).uimg
DBG_OBJS := $(patsubst %.c,$(DBG_PATH)/%.o,$(C_SRC))

ifeq ($(semi),1)
DBG_CFLAGS := -g3 -O0 $(CFLAGS) -DDEBUG -Dsoc_cv_av -DCYCLONEV -DSEMIHOSTING $(INCFLAGS)
DBG_LDFLAGS := -g3 -O0 $(CFLAGS) -T$(LINKER_SCRIPT) $(LDFLAGS) --specs=rdimon.specs -lrdimon
else
DBG_CFLAGS := -g3 -O0 $(CFLAGS) -DDEBUG -Dsoc_cv_av -DCYCLONEV -DTRU_PRINTF_UART $(INCFLAGS)
DBG_LDFLAGS := -g3 -O0 $(CFLAGS) -T$(LINKER_SCRIPT) $(LDFLAGS)
endif

# =====================
# Debug U-Boot settings
# =====================

DBG_UBOOT_IN_PATH := $(UBOOT_IN_PATH)/Debug
DBG_UBOOT_OUT_PATH := $(UBOOT_OUT_PATH)/Debug
DBG_UBOOT_SRC_PATH := $(DBG_UBOOT_OUT_PATH)/u-boot
DBG_UBOOT_SUB_PATH := $(DBG_UBOOT_OUT_PATH)/ub-out

DBG_UBOOT_SCRTXT_HDR := $(DBG_UBOOT_IN_PATH)/u-boot.scr.hdr.txt
DBG_UBOOT_SCRTXT_FTR := $(DBG_UBOOT_IN_PATH)/u-boot.scr.ftr.txt
DBG_UBOOT_SFP := $(DBG_UBOOT_IN_PATH)/u-boot-with-spl.sfp
DBG_UBOOT_SCRTXT := $(DBG_UBOOT_SUB_PATH)/u-boot.scr.txt
DBG_UBOOT_SCR := $(DBG_UBOOT_SUB_PATH)/u-boot.scr

ifneq (,$(filter 1,$(sd) $(ub)))
DBG_UBOOT_SCRTXT_FPGA_L1_STR := if test -e mmc $(SDFATDEVPART) c5_fpga.rbf; then
DBG_UBOOT_SCRTXT_FPGA_L2_STR := fatload mmc $(SDFATDEVPART) \$${loadaddr} c5_fpga.rbf
DBG_UBOOT_SCRTXT_FPGA_L3_STR := fpga load 0 \$${loadaddr} \$${filesize}
DBG_UBOOT_SCRTXT_FPGA_L4_STR := fi
DBG_UBOOT_SCRTXT_FPGA_L5_STR := bridge enable
ifeq ($(uimg),1)
# Append U-boot script with these lines
DBG_UBOOT_SCRTXT_LOAD_STR = fatload mmc 0:1 $(LOAD_ADDR) $(PROGRAM_NAME).uimg
DBG_UBOOT_SCRTXT_RUN_STR = setenv autostart y; bootm $(LOAD_ADDR) $(DBG_ELF_ENTRY_TEXT)
else
ifeq ($(bin),1)
# Append U-boot script with these lines
DBG_UBOOT_SCRTXT_LOAD_STR = fatload mmc 0:1 $(LOAD_ADDR) $(PROGRAM_NAME).bin
DBG_UBOOT_SCRTXT_RUN_STR = go $(DBG_ELF_ENTRY_TEXT)
endif
endif
endif

# ===================================
# Debug SD card image partition files
# ===================================

ifeq ($(sd),1)
DBG_SD_OUT_PATH := $(SD_OUT_PATH)/Debug
DBG_SD_OUT_SUB_PATH := $(DBG_SD_OUT_PATH)/sd-out
DBG_SD_CP_PATH := $(DBG_PATH)/sd-out
# SD image file
DBG_SD_IMG := $(DBG_SD_OUT_SUB_PATH)/$(PROGRAM_NAME).sd.img
# SD image file
DBG_SDCP_IMG := $(DBG_SD_CP_PATH)/$(PROGRAM_NAME).sd.img
# Intermediate files to copy into the SD image
DBG_SD_SCR := $(addprefix $(DBG_SD_OUT_SUB_PATH)/$(SDFATFOLDER)/,$(notdir $(DBG_UBOOT_SCR)))
DBG_SD_UIMG := $(addprefix $(DBG_SD_OUT_SUB_PATH)/$(SDFATFOLDER)/,$(notdir $(DBG_UIMG)))
DBG_SD_BIN :=  $(addprefix $(DBG_SD_OUT_SUB_PATH)/$(SDFATFOLDER)/,$(notdir $(DBG_BIN)))
DBG_SD_SFP := $(addprefix $(DBG_SD_OUT_SUB_PATH)/$(SDA2FOLDER)/,$(notdir $(DBG_UBOOT_SFP)))
DBG_SD_APP_FMT := $(DBG_SD_OUT_SUB_PATH)/sd_app_fmt.txt
DBG_SD_FPGA_SRC := $(SD_IN_PATH)/Debug/c5_fpga.rbf
DBG_SD_FPGA := $(addprefix $(DBG_SD_OUT_SUB_PATH)/$(SDFATFOLDER)/,$(notdir $(DBG_SD_FPGA_SRC)))

# Partition 1 user files to copy into the SD image
ifeq ($(SDP1EXISTS),y)
DBG_SD_P1UF_SRC := $(wildcard $(SD_IN_PATH)/Debug/p1/*)
DBG_SD_P1UF := $(addprefix $(DBG_SD_OUT_SUB_PATH)/p1/,$(notdir $(DBG_SD_P1UF_SRC)))
endif
# Partition 2 user files to copy into the SD image
ifeq ($(SDP2EXISTS),y)
DBG_SD_P2UF_SRC := $(wildcard $(SD_IN_PATH)/Debug/p2/*)
DBG_SD_P2UF := $(addprefix $(DBG_SD_OUT_SUB_PATH)/p2/,$(notdir $(DBG_SD_P2UF_SRC)))
endif
# Partition 3 user files to copy into the SD image
ifeq ($(SDP3EXISTS),y)
DBG_SD_P3UF_SRC := $(wildcard $(SD_IN_PATH)/Debug/p3/*)
DBG_SD_P3UF := $(addprefix $(DBG_SD_OUT_SUB_PATH)/p3/,$(notdir $(DBG_SD_P3UF_SRC)))
endif
# Partition 4 user files to copy into the SD image
ifeq ($(SDP4EXISTS),y)
DBG_SD_P4UF_SRC := $(wildcard $(SD_IN_PATH)/Debug/p4/*)
DBG_SD_P4UF := $(addprefix $(DBG_SD_OUT_SUB_PATH)/p4/,$(notdir $(DBG_SD_P4UF_SRC)))
endif
endif

# ======================
# Release build settings
# ======================

REL_PATH := $(BM_OUT_PATH)/Release
REL_ELF := $(REL_PATH)/$(PROGRAM_NAME).elf
REL_ELF_ENTRY_FILE := $(REL_PATH)/$(PROGRAM_NAME).entry.txt
REL_BIN := $(REL_PATH)/$(PROGRAM_NAME).bin
REL_UIMG := $(REL_PATH)/$(PROGRAM_NAME).uimg
REL_OBJS := $(patsubst %.c,$(REL_PATH)/%.o,$(C_SRC))
REL_CFLAGS := -Os $(CFLAGS) -Dsoc_cv_av -DCYCLONEV -DTRU_PRINTF_UART $(INCFLAGS)
REL_LDFLAGS := -Os $(CFLAGS) -T$(LINKER_SCRIPT) $(LDFLAGS)

# =======================
# Release U-Boot settings
# =======================

REL_UBOOT_IN_PATH := $(UBOOT_IN_PATH)/Release
REL_UBOOT_OUT_PATH := $(UBOOT_OUT_PATH)/Release
REL_UBOOT_SRC_PATH := $(REL_UBOOT_OUT_PATH)/u-boot
REL_UBOOT_SUB_PATH := $(REL_UBOOT_OUT_PATH)/ub-out

REL_UBOOT_SCRTXT_HDR := $(REL_UBOOT_IN_PATH)/u-boot.scr.hdr.txt
REL_UBOOT_SCRTXT_FTR := $(REL_UBOOT_IN_PATH)/u-boot.scr.ftr.txt
REL_UBOOT_SFP := $(REL_UBOOT_IN_PATH)/u-boot-with-spl.sfp
REL_UBOOT_SCRTXT := $(REL_UBOOT_SUB_PATH)/u-boot.scr.txt
REL_UBOOT_SCR := $(REL_UBOOT_SUB_PATH)/u-boot.scr

ifneq (,$(filter 1,$(sd) $(ub)))
REL_UBOOT_SCRTXT_FPGA_L1_STR := if test -e mmc $(SDFATDEVPART) c5_fpga.rbf; then
REL_UBOOT_SCRTXT_FPGA_L2_STR := fatload mmc $(SDFATDEVPART) \$${loadaddr} c5_fpga.rbf
REL_UBOOT_SCRTXT_FPGA_L3_STR := fpga load 0 \$${loadaddr} \$${filesize}
REL_UBOOT_SCRTXT_FPGA_L4_STR := fi
REL_UBOOT_SCRTXT_FPGA_L5_STR := bridge enable
ifeq ($(uimg),1)
# Append U-boot script with these lines
REL_UBOOT_SCRTXT_LOAD_STR = fatload mmc $(SDFATDEVPART) $(LOAD_ADDR) $(PROGRAM_NAME).uimg
REL_UBOOT_SCRTXT_RUN_STR = setenv autostart y; bootm $(LOAD_ADDR) $(REL_ELF_ENTRY_TEXT)
else
ifeq ($(bin),1)
# Append U-boot script with these lines
REL_UBOOT_SCRTXT_LOAD_STR = fatload mmc $(SDFATDEVPART) $(LOAD_ADDR) $(PROGRAM_NAME).bin
REL_UBOOT_SCRTXT_RUN_STR = go $(REL_ELF_ENTRY_TEXT)
endif
endif
endif

# =====================================
# Release SD card image partition files
# =====================================

ifeq ($(sd),1)
REL_SD_OUT_PATH := $(SD_OUT_PATH)/Release
REL_SD_OUT_SUB_PATH := $(REL_SD_OUT_PATH)/sd-out
REL_SD_CP_PATH := $(REL_PATH)/sd-out
# SD image file
REL_SD_IMG := $(REL_SD_OUT_SUB_PATH)/$(PROGRAM_NAME).sd.img
# SD image file
REL_SDCP_IMG := $(REL_SD_CP_PATH)/$(PROGRAM_NAME).sd.img
# Intermediate files to copy into the SD image
REL_SD_SCR := $(addprefix $(REL_SD_OUT_SUB_PATH)/$(SDFATFOLDER)/,$(notdir $(REL_UBOOT_SCR)))
REL_SD_UIMG := $(addprefix $(REL_SD_OUT_SUB_PATH)/$(SDFATFOLDER)/,$(notdir $(REL_UIMG)))
REL_SD_BIN :=  $(addprefix $(REL_SD_OUT_SUB_PATH)/$(SDFATFOLDER)/,$(notdir $(REL_BIN)))
REL_SD_SFP := $(addprefix $(REL_SD_OUT_SUB_PATH)/$(SDA2FOLDER)/,$(notdir $(REL_UBOOT_SFP)))
REL_SD_APP_FMT := $(REL_SD_OUT_SUB_PATH)/sd_app_fmt.txt
REL_SD_FPGA_SRC := $(SD_IN_PATH)/Release/c5_fpga.rbf
REL_SD_FPGA := $(addprefix $(REL_SD_OUT_SUB_PATH)/$(SDFATFOLDER)/,$(notdir $(REL_SD_FPGA_SRC)))

# Partition 1 user files to copy into the SD image
ifeq ($(SDP1EXISTS),y)
REL_SD_P1UF_SRC := $(wildcard $(SD_IN_PATH)/Release/p1/*)
REL_SD_P1UF := $(addprefix $(REL_SD_OUT_SUB_PATH)/p1/,$(notdir $(REL_SD_P1UF_SRC)))
endif
# Partition 2 user files to copy into the SD image
ifeq ($(SDP2EXISTS),y)
REL_SD_P2UF_SRC := $(wildcard $(SD_IN_PATH)/Release/p2/*)
REL_SD_P2UF := $(addprefix $(REL_SD_OUT_SUB_PATH)/p2/,$(notdir $(REL_SD_P2UF_SRC)))
endif
# Partition 3 user files to copy into the SD image
ifeq ($(SDP3EXISTS),y)
REL_SD_P3UF_SRC := $(wildcard $(SD_IN_PATH)/Release/p3/*)
REL_SD_P3UF := $(addprefix $(REL_SD_OUT_SUB_PATH)/p3/,$(notdir $(REL_SD_P3UF_SRC)))
endif
# Partition 4 user files to copy into the SD image
ifeq ($(SDP4EXISTS),y)
REL_SD_P4UF_SRC := $(wildcard $(SD_IN_PATH)/Release/p4/*)
REL_SD_P4UF := $(addprefix $(REL_SD_OUT_SUB_PATH)/p4/,$(notdir $(REL_SD_P4UF_SRC)))
endif
endif

# ===============================================
# Check if SD card image needs force prerequisite
# ===============================================

DBG_SD_FORCE_PRE := y
ifeq ($(sd),1)
# File exists?
ifneq (,$(wildcard $(DBG_SD_APP_FMT)))
DBG_SD_APP_FMT_TEXT := $(file <$(DBG_SD_APP_FMT))
# uimg=1 exists?
ifeq ($(uimg),1)
ifeq ($(DBG_SD_APP_FMT_TEXT),UIMG)
DBG_SD_FORCE_PRE := n
endif
else
# bin=1 exists?
ifeq ($(bin),1)
ifeq ($(DBG_SD_APP_FMT_TEXT),BIN)
DBG_SD_FORCE_PRE := n
endif
endif
endif
endif
endif

REL_SD_FORCE_PRE := y
ifeq ($(sd),1)
# File exists?
ifneq (,$(wildcard $(REL_SD_APP_FMT)))
REL_SD_APP_FMT_TEXT := $(file <$(REL_SD_APP_FMT))
# uimg=1 exists?
ifeq ($(uimg),1)
ifeq ($(REL_SD_APP_FMT_TEXT),UIMG)
REL_SD_FORCE_PRE := n
endif
else
ifeq ($(bin),1)
ifeq ($(REL_SD_APP_FMT_TEXT),BIN)
REL_SD_FORCE_PRE := n
endif
endif
endif
endif
endif

# ========================
# Read elf entry from file
# ========================

# File exists?
ifneq (,$(wildcard $(DBG_ELF_ENTRY_FILE)))
DBG_ELF_ENTRY_TEXT := $(file <$(DBG_ELF_ENTRY_FILE))
endif
# File exists?
ifneq (,$(wildcard $(REL_ELF_ENTRY_FILE)))
REL_ELF_ENTRY_TEXT := $(file <$(REL_ELF_ENTRY_FILE))
endif

# ===========================
# Miscellaneous support tools
# ===========================

CROSS_COMPILE := arm-none-eabi-
CC := $(CROSS_COMPILE)gcc
LD := $(CROSS_COMPILE)g++
NM := $(CROSS_COMPILE)nm
OC := $(CROSS_COMPILE)objcopy
OD := $(CROSS_COMPILE)objdump
RE := $(CROSS_COMPILE)readelf
SZ := $(CROSS_COMPILE)size
MK := mkimage

# Represents an empty white space - we need it for extracting the elf entry address from readelf output
SPACE := $() $()

# ===========
# Build rules
# ===========

# Options
.PHONY: all help release debug clean cleantemp

# Default build
all: release

# Dummy force always rule
FORCE:
	

help:
	@echo "Builds the bare-metal C program"
	@echo "Usage:"
	@echo "  make [targets] [options]"
	@echo ""
	@echo "targets:"
	@echo "  release       build elf Release (default)"
	@echo "  debug         build elf Debug"
	@echo "  clean         delete all built files"
	@echo "  cleantemp     clean except target files"
	@echo "options to use with target:"
	@echo "  semi=1        elf Debug with Semihosting"
	@echo "  bin=1         outputs binary from the elf"
	@echo "  uimg=1        outputs U-Boot image from the binary"
	@echo "  sd=1          outputs SD card image using binary as default,"
	@echo "                if uimg is specified then is used instead"
	@echo "  ub=1          force build U-Boot sources"
	@echo "  alt=1         use Altera's SD card image script"

# ===========
# Clean rules
# ===========

# Clean U-Boot folder
clean_ub:
ifneq ($(OS),Windows_NT)
	@if [ -d "$(UBOOT_OUT_PATH)" ]; then \
		if [ -d "$(DBG_UBOOT_SUB_PATH)" ]; then echo rm -rf $(DBG_UBOOT_SUB_PATH); rm -rf $(DBG_UBOOT_SUB_PATH); fi; \
		if [ -d "$(REL_UBOOT_SUB_PATH)" ]; then echo rm -rf $(REL_UBOOT_SUB_PATH); rm -rf $(REL_UBOOT_SUB_PATH); fi; \
		if [ -d "$(DBG_UBOOT_SRC_PATH)/Makefile)" ]; then make -C $(DBG_UBOOT_SRC_PATH) --no-print-directory clean; fi; \
		make -C $(UBOOT_IN_PATH) --no-print-directory -f Makefile-prep-ub.mk clean; \
	fi
endif

# Clean SD folder
clean_sd:
ifneq ($(OS),Windows_NT)
ifeq ($(alt),1)
	@if [ -d "$(SD_OUT_PATH)" ]; then make -C $(SD_IN_PATH) --no-print-directory -f Makefile-sd-alt.mk clean; fi
else
	@if [ -d "$(SD_OUT_PATH)" ]; then make -C $(SD_IN_PATH) --no-print-directory -f Makefile-sd-tru.mk clean; fi
endif
endif

# Clean sublevel 1 folder
clean_1:
	@if [ -d "$(DBG_PATH)" ]; then echo rm -rf $(DBG_PATH); rm -rf $(DBG_PATH); fi
	@if [ -d "$(REL_PATH)" ]; then echo rm -rf $(REL_PATH); rm -rf $(REL_PATH); fi

# Clean root folder
clean: clean_ub clean_sd clean_1
	@if [ -d "$(BM_OUT_PATH)" ] && [ -z "$$(ls -A $(BM_OUT_PATH))" ]; then echo rm -df $(BM_OUT_PATH); rm -df $(BM_OUT_PATH); fi

# ===============================================================
# Clean temporary files rules (does not remove user target files)
# ===============================================================

# Clean U-Boot folder
cleantemp_ub:
ifneq ($(OS),Windows_NT)
	@if [ -d "$(UBOOT_OUT_PATH)" ]; then \
		echo rm -f $(DBG_UBOOT_SCRTXT); rm -f $(DBG_UBOOT_SCRTXT); \
		echo rm -f $(DBG_UBOOT_SCR); rm -f $(DBG_UBOOT_SCR); \
		echo rm -f $(REL_UBOOT_SCRTXT); rm -f $(REL_UBOOT_SCRTXT); \
		echo rm -f $(REL_UBOOT_SCR); rm -f $(REL_UBOOT_SCR); \
		if [ -d "$(DBG_UBOOT_SRC_PATH)/Makefile)" ]; then make -C $(DBG_UBOOT_SRC_PATH) --no-print-directory clean; fi; \
		make -C $(UBOOT_IN_PATH) --no-print-directory -f Makefile-prep-ub.mk clean; \
	fi
endif

# Clean SD folder
cleantemp_sd:
ifneq ($(OS),Windows_NT)
	@if [ -d "$(DBG_SD_OUT_SUB_PATH)" ]; then \
		if [ -d "$(DBG_SD_OUT_SUB_PATH)/p1" ]; then echo rm -rf $(DBG_SD_OUT_SUB_PATH)/p1; rm -rf $(DBG_SD_OUT_SUB_PATH)/p1; fi; \
		if [ -d "$(DBG_SD_OUT_SUB_PATH)/p2" ]; then echo rm -rf $(DBG_SD_OUT_SUB_PATH)/p2; rm -rf $(DBG_SD_OUT_SUB_PATH)/p2; fi; \
		if [ -d "$(DBG_SD_OUT_SUB_PATH)/p3" ]; then echo rm -rf $(DBG_SD_OUT_SUB_PATH)/p3; rm -rf $(DBG_SD_OUT_SUB_PATH)/p3; fi; \
		if [ -d "$(DBG_SD_OUT_SUB_PATH)/p4" ]; then echo rm -rf $(DBG_SD_OUT_SUB_PATH)/p4; rm -rf $(DBG_SD_OUT_SUB_PATH)/p4; fi; \
		if [ -d "$(DBG_SD_OUT_SUB_PATH)/p1m" ]; then echo rm -rf $(DBG_SD_OUT_SUB_PATH)/p1m; rm -rf $(DBG_SD_OUT_SUB_PATH)/p1m; fi; \
		if [ -d "$(DBG_SD_OUT_SUB_PATH)/p2m" ]; then echo rm -rf $(DBG_SD_OUT_SUB_PATH)/p2m; rm -rf $(DBG_SD_OUT_SUB_PATH)/p2m; fi; \
		if [ -d "$(DBG_SD_OUT_SUB_PATH)/p3m" ]; then echo rm -rf $(DBG_SD_OUT_SUB_PATH)/p3m; rm -rf $(DBG_SD_OUT_SUB_PATH)/p3m; fi; \
		if [ -d "$(DBG_SD_OUT_SUB_PATH)/p4m" ]; then echo rm -rf $(DBG_SD_OUT_SUB_PATH)/p4m; rm -rf $(DBG_SD_OUT_SUB_PATH)/p4m; fi; \
		if [ -f "$(DBG_SD_APP_FMT)" ]; then echo rm -f $(DBG_SD_APP_FMT); rm -f $(DBG_SD_APP_FMT); fi; \
	fi
	@if [ -d "$(REL_SD_OUT_SUB_PATH)" ]; then \
		if [ -d "$(REL_SD_OUT_SUB_PATH)/p1" ]; then echo rm -rf $(REL_SD_OUT_SUB_PATH)/p1; rm -rf $(REL_SD_OUT_SUB_PATH)/p1; fi; \
		if [ -d "$(REL_SD_OUT_SUB_PATH)/p2" ]; then echo rm -rf $(REL_SD_OUT_SUB_PATH)/p2; rm -rf $(REL_SD_OUT_SUB_PATH)/p2; fi; \
		if [ -d "$(REL_SD_OUT_SUB_PATH)/p3" ]; then echo rm -rf $(REL_SD_OUT_SUB_PATH)/p3; rm -rf $(REL_SD_OUT_SUB_PATH)/p3; fi; \
		if [ -d "$(REL_SD_OUT_SUB_PATH)/p4" ]; then echo rm -rf $(REL_SD_OUT_SUB_PATH)/p4; rm -rf $(REL_SD_OUT_SUB_PATH)/p4; fi; \
		if [ -d "$(REL_SD_OUT_SUB_PATH)/p1m" ]; then echo rm -rf $(REL_SD_OUT_SUB_PATH)/p1m; rm -rf $(REL_SD_OUT_SUB_PATH)/p1m; fi; \
		if [ -d "$(REL_SD_OUT_SUB_PATH)/p2m" ]; then echo rm -rf $(REL_SD_OUT_SUB_PATH)/p2m; rm -rf $(REL_SD_OUT_SUB_PATH)/p2m; fi; \
		if [ -d "$(REL_SD_OUT_SUB_PATH)/p3m" ]; then echo rm -rf $(REL_SD_OUT_SUB_PATH)/p3m; rm -rf $(REL_SD_OUT_SUB_PATH)/p3m; fi; \
		if [ -d "$(REL_SD_OUT_SUB_PATH)/p4m" ]; then echo rm -rf $(REL_SD_OUT_SUB_PATH)/p4m; rm -rf $(REL_SD_OUT_SUB_PATH)/p4m; fi; \
		if [ -f "$(REL_SD_APP_FMT)" ]; then echo rm -f $(REL_SD_APP_FMT); rm -f $(REL_SD_APP_FMT); fi; \
	fi
ifeq ($(alt),1)
	@if [ -d "$(SD_OUT_PATH)" ]; then make -C $(SD_IN_PATH) --no-print-directory -f Makefile-sd-alt.mk clean; fi
else
	@if [ -d "$(SD_OUT_PATH)" ]; then make -C $(SD_IN_PATH) --no-print-directory -f Makefile-sd-tru.mk clean; fi
endif
endif

# Clean sublevel 1 folder
cleantemp_1:
	@if [ -d "$(DBG_PATH)" ]; then \
		echo rm -rf $(DBG_PATH)/*.map; rm -rf $(DBG_PATH)/*.map; \
		echo rm -rf $(DBG_PATH)/*.objdump; rm -rf $(DBG_PATH)/*.objdump; \
	fi
	@if [ -d "$(REL_PATH)" ]; then \
		echo rm -rf $(REL_PATH)/*.map; rm -rf $(REL_PATH)/*.map; \
		echo rm -rf $(REL_PATH)/*.objdump; rm -rf $(REL_PATH)/*.objdump; \
	fi

# Clean root folder
cleantemp: cleantemp_ub cleantemp_sd cleantemp_1
	@if [ -d "$(BM_OUT_PATH)" ]; then \
		echo rm -f $(DBG_OBJS) $(DBG_ELF_ENTRY_FILE) $(DBG_UBOOT_SCRTXT) $(DBG_UBOOT_SCR); rm -f $(DBG_OBJS) $(DBG_ELF_ENTRY_FILE) $(DBG_UBOOT_SCRTXT) $(DBG_UBOOT_SCR); \
		echo rm -f $(REL_OBJS) $(REL_ELF_ENTRY_FILE) $(REL_UBOOT_SCRTXT) $(REL_UBOOT_SCR); rm -f $(REL_OBJS) $(REL_ELF_ENTRY_FILE) $(REL_UBOOT_SCRTXT) $(REL_UBOOT_SCR); \
	fi

# ======================
# Compile and link rules
# ======================

# =====
# Debug
# =====

debug: $(DBG_ELF) $(DBG_ELF_ENTRY_FILE)

# Compile source files
$(DBG_PATH)/%.o: %.c
	@mkdir -p $(@D)
	$(CC) -c $(DBG_CFLAGS) -o $@ $<
	
# Link object files
$(DBG_ELF): $(DBG_OBJS)
	$(LD) $(DBG_LDFLAGS) $(DBG_OBJS) -o $@
	$(NM) $@ > $@.map
	$(OD) -d $@ > $@.objdump

# =======
# Release
# =======

release: $(REL_ELF) $(REL_ELF_ENTRY_FILE)

# Compile source files
$(REL_PATH)/%.o: %.c
	@mkdir -p $(@D)
	$(CC) -c $(REL_CFLAGS) -o $@ $<

# Link object files
$(REL_ELF): $(REL_OBJS)
	$(LD) $(REL_LDFLAGS) $(REL_OBJS) -o $@
	$(NM) $@ > $@.map
	$(OD) -d $@ > $@.objdump

# =============================
# Extract elf information rules
# =============================

# Extract elf entry address and write to file
$(DBG_ELF_ENTRY_FILE): $(DBG_ELF)
	@$(SZ) --format=berkeley $(DBG_ELF)
	$(eval DBG_HDR := $(shell $(RE) -h $(DBG_ELF)))
	$(eval DBG_ELF_ENTRY_TEXT := $(filter Entry 0x%,$(DBG_HDR)))
	$(eval DBG_ELF_ENTRY_TEXT := $(subst Entry$(SPACE),Entry_,$(DBG_ELF_ENTRY_TEXT)))
	$(eval DBG_ELF_ENTRY_TEXT := $(filter Entry_%,$(DBG_ELF_ENTRY_TEXT)))
	$(eval DBG_ELF_ENTRY_TEXT := $(subst Entry_,,$(DBG_ELF_ENTRY_TEXT)))
	$(info Elf-entry-point: $(DBG_ELF_ENTRY_TEXT))
	@echo $(DBG_ELF_ENTRY_TEXT) > $(DBG_ELF_ENTRY_FILE)

# Extract elf entry address and write to file
$(REL_ELF_ENTRY_FILE): $(REL_ELF)
	@$(SZ) --format=berkeley $(REL_ELF)
	$(eval REL_HDR := $(shell $(RE) -h $(REL_ELF)))
	$(eval REL_ELF_ENTRY_TEXT := $(filter Entry 0x%,$(REL_HDR)))
	$(eval REL_ELF_ENTRY_TEXT := $(subst Entry$(SPACE),Entry_,$(REL_ELF_ENTRY_TEXT)))
	$(eval REL_ELF_ENTRY_TEXT := $(filter Entry_%,$(REL_ELF_ENTRY_TEXT)))
	$(eval REL_ELF_ENTRY_TEXT := $(subst Entry_,,$(REL_ELF_ENTRY_TEXT)))
	$(info Elf-entry-point: $(REL_ELF_ENTRY_TEXT))
	@echo $(REL_ELF_ENTRY_TEXT) > $(REL_ELF_ENTRY_FILE)

# =====================
# Select optional rules
# =====================

ifeq ($(bin),1)
# Add additional target rule
debug: $(DBG_BIN)
release: $(REL_BIN)
endif

ifeq ($(uimg),1)
# Add additional target rule
debug: $(DBG_UIMG)
release: $(REL_UIMG)
endif

ifeq ($(ub),1)
debug: dbg_update_uboot
release: rel_update_uboot
endif

ifeq ($(sd),1)
# Add additional target rule
debug: $(DBG_SD_IMG)
release: $(REL_SD_IMG)
endif

# ========================
# ELF to binary file rules
# ========================
	
# Convert elf to binary
$(DBG_BIN): $(DBG_ELF)
	$(OC) -O binary $(DBG_ELF) $@

# Convert elf to binary
$(REL_BIN): $(REL_ELF)
	$(OC) -O binary $(REL_ELF) $@

# =====================================
# ELF binary to U-Boot image file rules
# =====================================

# Convert binary to U-Boot bootable image
$(DBG_UIMG): $(DBG_BIN) $(DBG_ELF_ENTRY_FILE)
	$(MK) -A arm -O u-boot -T standalone -C none -a $(LOAD_ADDR) -e $(DBG_ELF_ENTRY_TEXT) -n "baremetal" -d $(DBG_BIN) $@

# Convert binary to U-Boot bootable image
$(REL_UIMG): $(REL_BIN) $(REL_ELF_ENTRY_FILE)
	$(MK) -A arm -O u-boot -T standalone -C none -a $(LOAD_ADDR) -e $(REL_ELF_ENTRY_TEXT) -n "baremetal" -d $(REL_BIN) $@

# ======================================================================
# Build a list of prerequisites for fundamental changes on SD card image
# ======================================================================

# Add prerequisite to list
DBG_SD_FUND_PRE := $(DBG_SD_FUND_PRE) $(DBG_SD_P1UF_SRC) $(DBG_SD_P2UF_SRC) $(DBG_SD_P3UF_SRC) $(DBG_SD_P4UF_SRC) $(SDENVFILE)
REL_SD_FUND_PRE := $(REL_SD_FUND_PRE) $(REL_SD_P1UF_SRC) $(REL_SD_P2UF_SRC) $(REL_SD_P3UF_SRC) $(REL_SD_P4UF_SRC) $(SDENVFILE)

# =====================================================
# Build a list of prerequisites for U-Boot script rules
# =====================================================

# Add prerequisite to list
DBG_SCR_PRE := $(DBG_SCR_PRE) $(DBG_ELF_ENTRY_FILE)
REL_SCR_PRE := $(REL_SCR_PRE) $(REL_ELF_ENTRY_FILE)

# Add prerequisite to list
ifneq (,$(wildcard $(DBG_UBOOT_SCRTXT_HDR)))
DBG_SCR_PRE := $(DBG_SCR_PRE) $(DBG_UBOOT_SCRTXT_HDR)
endif
ifneq (,$(wildcard $(REL_UBOOT_SCRTXT_HDR)))
DBG_SCR_PRE := $(DBG_SCR_PRE) $(REL_UBOOT_SCRTXT_HDR)
endif

# Add prerequisite to list
ifneq (,$(wildcard $(DBG_UBOOT_SCRTXT_FTR)))
DBG_SCR_PRE := $(DBG_SCR_PRE) $(DBG_UBOOT_SCRTXT_FTR)
endif
ifneq (,$(wildcard $(REL_UBOOT_SCRTXT_FTR)))
REL_SCR_PRE := $(REL_SCR_PRE) $(REL_UBOOT_SCRTXT_FTR)
endif

# Add prerequisite to list
ifeq ($(uimg),1)
DBG_SCR_PRE := $(DBG_SCR_PRE) $(DBG_UIMG)
REL_SCR_PRE := $(REL_SCR_PRE) $(REL_UIMG)
endif
ifeq ($(bin),1)
DBG_SCR_PRE := $(DBG_SCR_PRE) $(DBG_BIN)
REL_SCR_PRE := $(REL_SCR_PRE) $(REL_BIN)
endif

# Add prerequisite to list
ifeq ($(DBG_SD_FORCE_PRE),y)
DBG_SCR_PRE := $(DBG_SCR_PRE) FORCE
endif
ifeq ($(REL_SD_FORCE_PRE),y)
REL_SCR_PRE := $(REL_SCR_PRE) FORCE
endif

# Add prerequisite to list
# Fundamental changes to SD card image should also rebuild U-Boot script
DBG_SCR_PRE := $(DBG_SCR_PRE) $(DBG_SD_FUND_PRE)
REL_SCR_PRE := $(REL_SCR_PRE) $(REL_SD_FUND_PRE)

# ===================
# U-boot script rules
# ===================

# Create U-Boot text script
$(DBG_UBOOT_SCRTXT): $(DBG_SCR_PRE)
	@mkdir -p $(DBG_UBOOT_SUB_PATH)
	@if [ -f "$(DBG_UBOOT_SCRTXT_HDR)" ]; then cp -f $(DBG_UBOOT_SCRTXT_HDR) $@; else rm -f $@; fi
	@echo "$(DBG_UBOOT_SCRTXT_FPGA_L1_STR)" >> $@
	@echo "$(DBG_UBOOT_SCRTXT_FPGA_L2_STR)" >> $@
	@echo "$(DBG_UBOOT_SCRTXT_FPGA_L3_STR)" >> $@
	@echo "$(DBG_UBOOT_SCRTXT_FPGA_L4_STR)" >> $@
	@echo "$(DBG_UBOOT_SCRTXT_FPGA_L5_STR)" >> $@
	@echo "$(DBG_UBOOT_SCRTXT_LOAD_STR)" >> $@
	@echo "$(DBG_UBOOT_SCRTXT_RUN_STR)" >> $@
	@if [ -f "$(DBG_UBOOT_SCRTXT_FTR)" ]; then cat $(DBG_UBOOT_SCRTXT_FTR) >> $@; fi

# Convert U-Boot text script to mkimage format
$(DBG_UBOOT_SCR): $(DBG_UBOOT_SCRTXT)
	$(MK) -C none -A arm -T script -d $(DBG_UBOOT_SCRTXT) $@

# Create U-Boot text script
$(REL_UBOOT_SCRTXT): $(REL_SCR_PRE)
	@mkdir -p $(REL_UBOOT_SUB_PATH)
	@if [ -f "$(REL_UBOOT_SCRTXT_HDR)" ]; then cp -f $(REL_UBOOT_SCRTXT_HDR) $@; else rm -f $@; fi
	@echo "$(REL_UBOOT_SCRTXT_FPGA_L1_STR)" >> $@
	@echo "$(REL_UBOOT_SCRTXT_FPGA_L2_STR)" >> $@
	@echo "$(REL_UBOOT_SCRTXT_FPGA_L3_STR)" >> $@
	@echo "$(REL_UBOOT_SCRTXT_FPGA_L4_STR)" >> $@
	@echo "$(REL_UBOOT_SCRTXT_FPGA_L5_STR)" >> $@
	@echo "$(REL_UBOOT_SCRTXT_LOAD_STR)" >> $@
	@echo "$(REL_UBOOT_SCRTXT_RUN_STR)" >> $@
	@if [ -f "$(REL_UBOOT_SCRTXT_FTR)" ]; then cat $(REL_UBOOT_SCRTXT_FTR) >> $@; fi

# Convert U-Boot text script to mkimage format
$(REL_UBOOT_SCR): $(REL_UBOOT_SCRTXT)
	$(MK) -C none -A arm -T script -d $(REL_UBOOT_SCRTXT) $@

# ===================
# Update U-Boot rules
# ===================

dbg_update_uboot:
	@echo "Running make to prepare U-Boot"
	@make -C $(UBOOT_IN_PATH) --no-print-directory -f Makefile-prep-ub.mk debug
	@echo ""
	@echo "Running make from U-Boot source"
	@make -C $(DBG_UBOOT_SRC_PATH) --no-print-directory $(UBOOT_DEFCONFIG)
	@make -C $(DBG_UBOOT_SRC_PATH) --no-print-directory -j 8
	@cp -f -u $(DBG_UBOOT_SRC_PATH)/u-boot-with-spl.sfp $(DBG_UBOOT_IN_PATH)

rel_update_uboot:
	@echo "Running make to prepare U-Boot"
	@make -C $(UBOOT_IN_PATH) --no-print-directory -f Makefile-prep-ub.mk release
	@echo ""
	@echo "Running make from U-Boot source"
	@make -C $(REL_UBOOT_SRC_PATH) --no-print-directory $(UBOOT_DEFCONFIG)
	@make -C $(REL_UBOOT_SRC_PATH) --no-print-directory -j 8
	@cp -f -u $(REL_UBOOT_SRC_PATH)/u-boot-with-spl.sfp $(REL_UBOOT_IN_PATH)

# =====================================================
# Build a list of prerequisites for SD card image rules
# =====================================================

# Add to prerequisite list
DBG_SD_APP_FMT_PRE := $(DBG_SD_APP_FMT_PRE) $(DBG_SD_FUND_PRE)
REL_SD_APP_FMT_PRE := $(REL_SD_APP_FMT_PRE) $(REL_SD_FUND_PRE)

# Add to prerequisite list
ifeq ($(DBG_SD_FORCE_PRE),y)
DBG_SD_APP_FMT_PRE := $(DBG_SD_APP_FMT_PRE) FORCE
#DBG_SD_IMG_PRE := $(DBG_SD_IMG_PRE) FORCE
endif
ifeq ($(REL_SD_FORCE_PRE),y)
REL_SD_APP_FMT_PRE := $(REL_SD_APP_FMT_PRE) FORCE
#REL_SD_IMG_PRE := $(REL_SD_IMG_PRE) FORCE
endif

# Add to prerequisite list
# Note, there is no timestamp so they behave like FORCE
ifeq ($(ub),1)
DBG_SD_IMG_PRE := $(DBG_SD_IMG_PRE) dbg_update_uboot
REL_SD_IMG_PRE := $(REL_SD_IMG_PRE) rel_update_uboot
endif

# Add to prerequisite list
DBG_SD_IMG_PRE := $(DBG_SD_IMG_PRE) $(DBG_SD_APP_FMT) $(DBG_SD_FUND_PRE) $(DBG_SD_SFP) $(DBG_SD_SCR) $(DBG_SD_P1UF) $(DBG_SD_P2UF) $(DBG_SD_P3UF) $(DBG_SD_P4UF)
REL_SD_IMG_PRE := $(REL_SD_IMG_PRE) $(REL_SD_APP_FMT) $(REL_SD_FUND_PRE) $(REL_SD_SFP) $(REL_SD_SCR) $(REL_SD_P1UF) $(REL_SD_P2UF) $(REL_SD_P3UF) $(REL_SD_P4UF)

# Add to prerequisite list
ifneq (,$(wildcard $(DBG_SD_FPGA_SRC)))
	DBG_SD_IMG_PRE := $(DBG_SD_IMG_PRE) $(DBG_SD_FPGA)
endif
ifneq (,$(wildcard $(REL_SD_FPGA_SRC)))
	REL_SD_IMG_PRE := $(REL_SD_IMG_PRE) $(REL_SD_FPGA)
endif

# Add to prerequisite list
ifeq ($(uimg),1)
DBG_SD_IMG_PRE := $(DBG_SD_IMG_PRE) $(DBG_SD_UIMG)
REL_SD_IMG_PRE := $(REL_SD_IMG_PRE) $(REL_SD_UIMG)
endif
ifeq ($(bin),1)
DBG_SD_IMG_PRE := $(DBG_SD_IMG_PRE) $(DBG_SD_BIN)
REL_SD_IMG_PRE := $(REL_SD_IMG_PRE) $(REL_SD_BIN)
endif

# ==============================
# Debug SD card image file rules
# ==============================

$(DBG_SD_APP_FMT): $(DBG_SD_APP_FMT_PRE)
	@if [ -d "$(DBG_SD_OUT_SUB_PATH)" ]; then \
		if [ -d "$(DBG_SD_OUT_SUB_PATH)/p1" ]; then echo rm -rf $(DBG_SD_OUT_SUB_PATH)/p1; rm -rf $(DBG_SD_OUT_SUB_PATH)/p1; fi; \
		if [ -d "$(DBG_SD_OUT_SUB_PATH)/p2" ]; then echo rm -rf $(DBG_SD_OUT_SUB_PATH)/p2; rm -rf $(DBG_SD_OUT_SUB_PATH)/p2; fi; \
		if [ -d "$(DBG_SD_OUT_SUB_PATH)/p3" ]; then echo rm -rf $(DBG_SD_OUT_SUB_PATH)/p3; rm -rf $(DBG_SD_OUT_SUB_PATH)/p3; fi; \
		if [ -d "$(DBG_SD_OUT_SUB_PATH)/p4" ]; then echo rm -rf $(DBG_SD_OUT_SUB_PATH)/p4; rm -rf $(DBG_SD_OUT_SUB_PATH)/p4; fi; \
		if [ -d "$(DBG_SD_OUT_SUB_PATH)/p1m" ]; then echo rm -rf $(DBG_SD_OUT_SUB_PATH)/p1m; rm -rf $(DBG_SD_OUT_SUB_PATH)/p1m; fi; \
		if [ -d "$(DBG_SD_OUT_SUB_PATH)/p2m" ]; then echo rm -rf $(DBG_SD_OUT_SUB_PATH)/p2m; rm -rf $(DBG_SD_OUT_SUB_PATH)/p2m; fi; \
		if [ -d "$(DBG_SD_OUT_SUB_PATH)/p3m" ]; then echo rm -rf $(DBG_SD_OUT_SUB_PATH)/p3m; rm -rf $(DBG_SD_OUT_SUB_PATH)/p3m; fi; \
		if [ -d "$(DBG_SD_OUT_SUB_PATH)/p4m" ]; then echo rm -rf $(DBG_SD_OUT_SUB_PATH)/p4m; rm -rf $(DBG_SD_OUT_SUB_PATH)/p4m; fi; \
		if [ -f "$(DBG_SD_IMG)" ]; then echo rm -f $(DBG_SD_IMG); rm -f $(DBG_SD_IMG); fi; \
		if [ -f "$(DBG_SDCP_IMG)" ]; then echo rm -f $(DBG_SDCP_IMG); rm -f $(DBG_SDCP_IMG); fi; \
	fi
	@mkdir -p $(@D)
ifeq ($(uimg),1)
	@echo "UIMG" > $(DBG_SD_APP_FMT)
else
	@echo "BIN" > $(DBG_SD_APP_FMT)
endif

$(DBG_SD_SFP): $(DBG_UBOOT_SFP)
	@mkdir -p $(@D)
	@cp -f $(DBG_UBOOT_SFP) $@

$(DBG_SD_SCR): $(DBG_UBOOT_SCR)
	@mkdir -p $(@D)
	@cp -f $(DBG_UBOOT_SCR) $@

$(DBG_SD_FPGA): $(DBG_SD_FPGA_SRC)
	@mkdir -p $(@D)
	@cp -f $(DBG_SD_FPGA_SRC) $@

$(DBG_SD_UIMG): $(DBG_UIMG)
	@mkdir -p $(@D)
	@cp -f $(DBG_UIMG) $@

$(DBG_SD_BIN): $(DBG_BIN)
	@mkdir -p $(@D)
	@cp -f $(DBG_BIN) $@

# Copy user partition files
$(DBG_SD_P1UF): $(DBG_SD_P1UF_SRC)
	@mkdir -p $(@D)
	@cp -f $(DBG_SD_P1UF_SRC) $@

# Copy user partition files
$(DBG_SD_P2UF): $(DBG_SD_P2UF_SRC)
	@mkdir -p $(@D)
	@cp -f $(DBG_SD_P2UF_SRC) $@

# Copy user partition files
$(DBG_SD_P3UF): $(DBG_SD_P3UF_SRC)
	@mkdir -p $(@D)
	@cp -f $(DBG_SD_P3UF_SRC) $@

# Copy user partition files
$(DBG_SD_P4UF): $(DBG_SD_P4UF_SRC)
	@mkdir -p $(@D)
	@cp -f $(DBG_SD_P4UF_SRC) $@

# Create SD card image
$(DBG_SD_IMG): $(DBG_SD_IMG_PRE)
ifeq ($(alt),1)
	@make -C $(SD_IN_PATH) --no-print-directory -f Makefile-sd-alt.mk debug
else
	@make -C $(SD_IN_PATH) --no-print-directory -f Makefile-sd-tru.mk debug
endif
ifneq ($(SD_OUT_PATH),$(BM_OUT_PATH))
	@if [ -f "$(DBG_SD_IMG)" ]; then \
		mkdir -p $(DBG_SD_CP_PATH); \
		cp -f $@ $(DBG_SD_CP_PATH); \
		echo Copied to: $(DBG_SDCP_IMG); \
	fi
endif

# ================================
# Release SD card image file rules
# ================================

$(REL_SD_APP_FMT): $(REL_SD_APP_FMT_PRE)
	@if [ -d "$(REL_SD_OUT_SUB_PATH)" ]; then \
		if [ -d "$(REL_SD_OUT_SUB_PATH)/p1" ]; then echo rm -rf $(REL_SD_OUT_SUB_PATH)/p1; rm -rf $(REL_SD_OUT_SUB_PATH)/p1; fi; \
		if [ -d "$(REL_SD_OUT_SUB_PATH)/p2" ]; then echo rm -rf $(REL_SD_OUT_SUB_PATH)/p2; rm -rf $(REL_SD_OUT_SUB_PATH)/p2; fi; \
		if [ -d "$(REL_SD_OUT_SUB_PATH)/p3" ]; then echo rm -rf $(REL_SD_OUT_SUB_PATH)/p3; rm -rf $(REL_SD_OUT_SUB_PATH)/p3; fi; \
		if [ -d "$(REL_SD_OUT_SUB_PATH)/p4" ]; then echo rm -rf $(REL_SD_OUT_SUB_PATH)/p4; rm -rf $(REL_SD_OUT_SUB_PATH)/p4; fi; \
		if [ -d "$(REL_SD_OUT_SUB_PATH)/p1m" ]; then echo rm -rf $(REL_SD_OUT_SUB_PATH)/p1m; rm -rf $(REL_SD_OUT_SUB_PATH)/p1m; fi; \
		if [ -d "$(REL_SD_OUT_SUB_PATH)/p2m" ]; then echo rm -rf $(REL_SD_OUT_SUB_PATH)/p2m; rm -rf $(REL_SD_OUT_SUB_PATH)/p2m; fi; \
		if [ -d "$(REL_SD_OUT_SUB_PATH)/p3m" ]; then echo rm -rf $(REL_SD_OUT_SUB_PATH)/p3m; rm -rf $(REL_SD_OUT_SUB_PATH)/p3m; fi; \
		if [ -d "$(REL_SD_OUT_SUB_PATH)/p4m" ]; then echo rm -rf $(REL_SD_OUT_SUB_PATH)/p4m; rm -rf $(REL_SD_OUT_SUB_PATH)/p4m; fi; \
		if [ -f "$(REL_SD_IMG)" ]; then echo rm -f $(REL_SD_IMG); rm -f $(REL_SD_IMG); fi; \
		if [ -f "$(REL_SDCP_IMG)" ]; then echo rm -f $(REL_SDCP_IMG); rm -f $(REL_SDCP_IMG); fi; \
	fi
	@mkdir -p $(@D)
ifeq ($(uimg),1)
	@echo "UIMG" > $(REL_SD_APP_FMT)
else
	@echo "BIN" > $(REL_SD_APP_FMT)
endif

$(REL_SD_SFP): $(REL_UBOOT_SFP)
	@mkdir -p $(@D)
	@cp -f $(REL_UBOOT_SFP) $@

$(REL_SD_SCR): $(REL_UBOOT_SCR)
	@mkdir -p $(@D)
	@cp -f $(REL_UBOOT_SCR) $@

$(REL_SD_FPGA): $(REL_SD_FPGA_SRC)
	@mkdir -p $(@D)
	cp -f $(REL_SD_FPGA_SRC) $@

$(REL_SD_UIMG): $(REL_UIMG)
	@mkdir -p $(@D)
	@cp -f $(REL_UIMG) $@

$(REL_SD_BIN): $(REL_BIN)
	@mkdir -p $(@D)
	@cp -f $(REL_BIN) $@

# Copy user partition files
$(REL_SD_P1UF): $(REL_SD_P1UF_SRC)
	@mkdir -p $(@D)
	@cp -f $(REL_SD_P1UF_SRC) $@

# Copy user partition files
$(REL_SD_P2UF): $(REL_SD_P2UF_SRC)
	@mkdir -p $(@D)
	@cp -f $(REL_SD_P2UF_SRC) $@

# Copy user partition files
$(REL_SD_P3UF): $(REL_SD_P3UF_SRC)
	@mkdir -p $(@D)
	@cp -f $(REL_SD_P3UF_SRC) $@

# Copy user partition files
$(REL_SD_P4UF): $(REL_SD_P4UF_SRC)
	@mkdir -p $(@D)
	@cp -f $(REL_SD_P4UF_SRC) $@

# Create SD card image
$(REL_SD_IMG): $(REL_SD_IMG_PRE)
ifeq ($(alt),1)
	@make -C $(SD_IN_PATH) --no-print-directory -f Makefile-sd-alt.mk release
else
	@make -C $(SD_IN_PATH) --no-print-directory -f Makefile-sd-tru.mk release
endif
ifneq ($(SD_OUT_PATH),$(BM_OUT_PATH))
	@if [ -f "$(REL_SD_IMG)" ]; then \
		mkdir -p $(REL_SD_CP_PATH); \
		cp -f $@ $(REL_SD_CP_PATH); \
		echo Copied to: $(REL_SDCP_IMG); \
	fi
endif
