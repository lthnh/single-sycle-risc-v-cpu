# Single-Cycle RISC-V CPU - AGENTS.md

## Programming Guidelines
- This project strictly uses Verilog IEEE 1364-2005 standard.
- For all source files except testbenchs (files whose names end with _tb) use synthesizable code. Unsynthesizable code in those files is NOT allowed.
- When making technical decisions, do not give much weight to development cost. Instead, prefer quality, simplicity, robustness, scalability, and long term maintainability.

## Build & Simulation
- `make -C tests/tb program_counter_tb` - compile + run a testbench with iverilog + vpv
- `make -C tests/tb all` - run all 3 base testbenches (pc, im, dm)
- `make -C tests/tb/alu_mods all` - run all ALU mod tests (rca, cla, sub, mul)
- Output VCDs go to `tests/wf/`, view with `surfer <file>.vcd`

## Key Defines (inc/alu.vh)
- `CARRY_LOOKAHEAD_ADDER_IMPL` - active by default; use `RIPPLE_CARRY_ADDER_IMPL` for ripple-carries
- `MUL_SHIFT_AND_ADD_IMPL` - active by default in mul.v

## Testbench Patterns
- All testbenches `include "common.vh"` and `include "assert.vh"`
- Assertions use `signal !== value`; `assert_eq_fmt(signal, value, format)` for formatted output
- Tests sample ~100 random inputs then `$finish`
- Mul test: assert after `@(posedge busy)`; testbench has clock/rstn

## ALU Sub-modules
- `src/alu_mods/add.v` - implements add with `RIPPLE_CARRY_ADDER_IMPL` or `CARRY_LOOKAHEAD_ADDER_IMPL`
- `src/alu_mods/sub.v` - uses add with complemented operand + borrow_in=1'b1; borrow_out is negated carry
- `src/alu_mods/mul.v` - shift-and-add multiplier with `busy` output signal and `rstn` active-low reset

## Project Structure
- `src/` - Verilog modules (cpu, alu, control, memory, etc.)
- `inc/` - Header defines: `common.vh` (`WIDTH 32`), `alu.vh`, `assert.vh`
- `tests/tb/` - Self-contained testbenches with their own Makefiles
- `tests/wf/` - Generated waveform directory
- `Makefile` (root) - top-level make; delegates to `tests/tb/Makefile`
