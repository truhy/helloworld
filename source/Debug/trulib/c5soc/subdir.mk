################################################################################
# Automatically-generated file. Do not edit!
################################################################################

# Add inputs and outputs from these tool invocations to the build variables 
C_SRCS += \
../trulib/c5soc/tru_adxl345.c \
../trulib/c5soc/tru_bsp_custom_c5soc.c \
../trulib/c5soc/tru_bsp_de10nano.c \
../trulib/c5soc/tru_clkmgr_c5soc.c \
../trulib/c5soc/tru_uart_c5soc.c 

OBJS += \
./trulib/c5soc/tru_adxl345.o \
./trulib/c5soc/tru_bsp_custom_c5soc.o \
./trulib/c5soc/tru_bsp_de10nano.o \
./trulib/c5soc/tru_clkmgr_c5soc.o \
./trulib/c5soc/tru_uart_c5soc.o 

C_DEPS += \
./trulib/c5soc/tru_adxl345.d \
./trulib/c5soc/tru_bsp_custom_c5soc.d \
./trulib/c5soc/tru_bsp_de10nano.d \
./trulib/c5soc/tru_clkmgr_c5soc.d \
./trulib/c5soc/tru_uart_c5soc.d 


# Each subdirectory must supply rules for building sources it contributes
trulib/c5soc/%.o: ../trulib/c5soc/%.c trulib/c5soc/subdir.mk
	@echo 'Building file: $<'
	@echo 'Invoking: GNU Arm Cross C Compiler'
	arm-none-eabi-gcc -mcpu=cortex-a9 -marm -mfloat-abi=hard -mfpu=neon -mno-unaligned-access -O0 -fmessage-length=0 -fsigned-char -ffunction-sections -fdata-sections -g3 -DDEBUG -D_RTE_ -I"D:\Documents\Programming\FPGA\de10nano-c\helloworld_20260707\source" -I"D:\Documents\Programming\FPGA\de10nano-c\helloworld_20260707\source\bsp" -I"D:\Documents\Programming\FPGA\de10nano-c\helloworld_20260707\source\trulib" -I"D:\Documents\Programming\FPGA\de10nano-c\helloworld_20260707\source\CMSIS\Core\Include" -I"D:\Documents\Programming\FPGA\de10nano-c\helloworld_20260707\source\CMSIS\Core\Include\a-profile" -I"D:\Documents\Programming\FPGA\de10nano-c\helloworld_20260707\source\CMSIS\Device\c5soc\include" -std=gnu11 -MMD -MP -MF"$(@:%.o=%.d)" -MT"$@" -c -o "$@" "$<"
	@echo 'Finished building: $<'
	@echo ' '


