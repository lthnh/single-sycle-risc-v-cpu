PROJECT_NAME := single-cycle-risc-v-cpu
PROJECT_DIR = $(shell find -L $$HOME/Personal -name $(PROJECT_NAME) -type d 2>/dev/null)

vpath %.v $(shell find $(PROJECT_DIR)/src -type d)

TARGET_PATH := $(PROJECT_DIR)/tests/bin

COMPILE_FLAGS := -I$(PROJECT_DIR)/inc
SIMULATE_FLAGS = -dumpfile=$(PROJECT_DIR)/tests/wf/$@.vcd

WAVEFORM_VIEWER := surfer

all: program_counter_tb instruction_memory_tb data_memory_tb

program_counter_tb: program_counter_tb.v program_counter.v
	iverilog $(COMPILE_FLAGS) -o $(TARGET_PATH)/$@ $^
	vvp $(TARGET_PATH)/$@ $(SIMULATE_FLAGS)

instruction_memory_tb: instruction_memory_tb.v instruction_memory.v
	iverilog $(COMPILE_FLAGS) -o $(TARGET_PATH)/$@ $^
	vvp $(TARGET_PATH)/$@ $(SIMULATE_FLAGS)

data_memory_tb: data_memory_tb.v data_memory.v
	iverilog $(COMPILE_FLAGS) -o $(TARGET_PATH)/$@ $^
	vvp $(TARGET_PATH)/$@ $(SIMULATE_FLAGS)

.PHONY: view.%

view.%:
	$(WAVEFORM_VIEWER) $(PROJECT_DIR)/tests/wf/$*.vcd

.SILENT: all program_counter_tb instruction_memory_tb data_memory_tb
