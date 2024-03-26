################################################################################
# Automatically-generated file. Do not edit!
################################################################################

# Add inputs and outputs from these tool invocations to the build variables 
C_SRCS += \
../startup/source/etu.c \
../startup/source/startup.c \
../startup/source/startup_etu.c 

OBJS += \
./startup/source/etu.o \
./startup/source/startup.o \
./startup/source/startup_etu.o 

C_DEPS += \
./startup/source/etu.d \
./startup/source/startup.d \
./startup/source/startup_etu.d 


# Each subdirectory must supply rules for building sources it contributes
startup/source/%.o: ../startup/source/%.c startup/source/subdir.mk
	@echo 'Building file: $<'
	@echo 'Invoking: GNU Arm Cross C Compiler'
	arm-none-eabi-gcc -mcpu=cortex-a9 -marm -mfloat-abi=hard -mfpu=neon -mno-unaligned-access -Os -fmessage-length=0 -fsigned-char -ffunction-sections -fdata-sections -g -Dsoc_cv_av -DCYCLONEV -I"D:\Documents\Programming\FPGA\de10nano-c\helloworld\source\startup\include" -I"D:\Documents\Programming\FPGA\de10nano-c\helloworld\source\bsp" -I"D:\Documents\Programming\FPGA\de10nano-c\helloworld\source\hwlib\include" -I"D:\Documents\Programming\FPGA\de10nano-c\helloworld\source\hwlib\include\soc_cv_av" -I"D:\Documents\Programming\FPGA\de10nano-c\helloworld\source\trulib\include" -std=gnu11 -MMD -MP -MF"$(@:%.o=%.d)" -MT"$@" -c -o "$@" "$<"
	@echo 'Finished building: $<'
	@echo ' '


