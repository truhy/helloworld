################################################################################
# Automatically-generated file. Do not edit!
################################################################################

# Add inputs and outputs from these tool invocations to the build variables 
C_SRCS += \
../trulib/source/tru_newlib_ext.c \
../trulib/source/tru_uart_ll.c 

OBJS += \
./trulib/source/tru_newlib_ext.o \
./trulib/source/tru_uart_ll.o 

C_DEPS += \
./trulib/source/tru_newlib_ext.d \
./trulib/source/tru_uart_ll.d 


# Each subdirectory must supply rules for building sources it contributes
trulib/source/%.o: ../trulib/source/%.c trulib/source/subdir.mk
	@echo 'Building file: $<'
	@echo 'Invoking: GNU Arm Cross C Compiler'
	arm-none-eabi-gcc -mcpu=cortex-a9 -marm -mfloat-abi=hard -mfpu=neon -mno-unaligned-access -Os -fmessage-length=0 -fsigned-char -ffunction-sections -fdata-sections -g -Dsoc_cv_av -DCYCLONEV -I"D:\Documents\Programming\FPGA\de10nano-c\helloworld\source\startup\include" -I"D:\Documents\Programming\FPGA\de10nano-c\helloworld\source\bsp" -I"D:\Documents\Programming\FPGA\de10nano-c\helloworld\source\hwlib\include" -I"D:\Documents\Programming\FPGA\de10nano-c\helloworld\source\hwlib\include\soc_cv_av" -I"D:\Documents\Programming\FPGA\de10nano-c\helloworld\source\trulib\include" -std=gnu11 -MMD -MP -MF"$(@:%.o=%.d)" -MT"$@" -c -o "$@" "$<"
	@echo 'Finished building: $<'
	@echo ' '


