PROJECT_NAME := single-cycle-risc-v-cpu
PROJECT_DIR = $(shell find -L $$HOME/Personal -name $(PROJECT_NAME) -type d 2>/dev/null)

vpath %.v $(PROJECT_DIR)/src $(PROJECT_DIR)/src/alu_mods $(PROJECT_DIR)/src/alu_mods/mul_mods/shiftnadd_mod

TARGET_PATH := $(PROJECT_DIR)/tests/bin

COMPILE_FLAGS := -I$(PROJECT_DIR)/inc
SIMULATE_FLAGS = -dumpfile=$(PROJECT_DIR)/tests/wf/$@.vcd

SECOND_TARGET := $(word 2, $(MAKECMDGOALS))

all: d_flip_flop_tb shift_unit_tb shift_reg_tb

d_flip_flop_tb: d_flip_flop_tb.v d_flip_flop.v
	iverilog $(COMPILE_FLAGS) -o $(TARGET_PATH)/$@ $^
	vvp $(TARGET_PATH)/$@ $(SIMULATE_FLAGS)

shift_unit_tb: shift_unit_tb.v shift_unit.v mux21.v d_flip_flop.v
	iverilog $(COMPILE_FLAGS) -o $(TARGET_PATH)/$@ $^
	vvp $(TARGET_PATH)/$@ $(SIMULATE_FLAGS)

shift_reg_tb: shift_reg_tb.v shift_reg.v shift_unit.v mux21.v d_flip_flop.v
	iverilog $(COMPILE_FLAGS) -o $(TARGET_PATH)/$@ $^
	vvp $(TARGET_PATH)/$@ $(SIMULATE_FLAGS)

view:
	gtkwave $(PROJECT_DIR)/tests/wf/$(SECOND_TARGET).vcd

.SILENT: d_flip_flop_tb shift_unit_tb shift_reg_tb view

