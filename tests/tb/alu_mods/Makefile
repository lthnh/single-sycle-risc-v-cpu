PROJECT_NAME := single-cycle-risc-v-cpu
PROJECT_DIR = $(shell find -L $$HOME/Personal -name $(PROJECT_NAME) -type d 2>/dev/null)

vpath %.v $(PROJECT_DIR)/src $(PROJECT_DIR)/src/alu_mods $(PROJECT_DIR)/src/alu_mods/add_mods/cla_mod $(PROJECT_DIR)/src/alu_mods/add_mods/rca_mod $(PROJECT_DIR)/src/alu_mods/mul_mods/shiftnadd_mod

TARGET_PATH := $(PROJECT_DIR)/tests/bin

COMPILE_FLAGS := -I$(PROJECT_DIR)/inc
SIMULATE_FLAGS = -dumpfile=$(PROJECT_DIR)/tests/wf/$@.vcd

WAVEFORM_VIEWER := surfer

all: add_rca_impl_tb add_cla_impl_tb sub_tb

add_rca_impl_tb: add_rca_impl_tb.v add.v full_adder.v half_adder.v
	iverilog $(COMPILE_FLAGS) -o $(TARGET_PATH)/$@ $^
	vvp $(TARGET_PATH)/$@

add_cla_impl_tb: add_cla_impl_tb.v add.v four_bit_cla.v four_bit_lookahead.v modified_full_adder.v
	iverilog $(COMPILE_FLAGS) -o $(TARGET_PATH)/$@ $^
	vvp $(TARGET_PATH)/$@

sub_tb: sub_tb.v sub.v add.v full_adder.v half_adder.v four_bit_cla.v four_bit_lookahead.v modified_full_adder.v
	iverilog $(COMPILE_FLAGS) -o $(TARGET_PATH)/$@ $^
	vvp $(TARGET_PATH)/$@

mul_tb: mul_tb.v mul.v shift_reg.v shift_unit.v mux21.v d_flip_flop.v
	iverilog $(COMPILE_FLAGS) -o $(TARGET_PATH)/$@ $^
	vvp $(TARGET_PATH)/$@ $(SIMULATE_FLAGS)

.PHONY: view.%

view.%:
	$(WAVEFORM_VIEWER) $(PROJECT_DIR)/tests/wf/$*.vcd

.SILENT: all add_rca_impl_tb add_cla_impl_tb sub_tb

