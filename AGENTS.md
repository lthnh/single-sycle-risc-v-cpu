# Single-Cycle RISC-V CPU - AGENTS.md

## Programming Guidelines
- This project strictly uses Verilog IEEE 1364-2005 standard. With the exception of UVM testbenches.
- For all source files except testbenchs (files whose names end with _tb) use synthesizable code. Unsynthesizable code in those files is NOT allowed.
- When making technical decisions, do not give much weight to development cost. Instead, prefer quality, simplicity, robustness, scalability, and long term maintainability.

## Documentation Guidelines
- If the code mentioned has a backtick \` in it, wrap that code in double backticks like this `` some code with `SOME_CONSTANT ``. Notice the space added between the code content and double backticks.
- Export handoffs to docs/handoffs/{session name}.md.

## Build & Simulation
- Vivado tools driven by version-controlled Tcl scripts are the sole compile, simulation, and
  synthesis flow for this project.
- Do not add or maintain an Icarus Verilog/Make build flow.
- Tcl entry points belong under `tools/tcl/` and must resolve project paths from the script location,
  not from the caller's working directory or `$HOME`.
- Compile, simulation, synthesis, CI, and editor tooling must use one deterministic source manifest.
- The roadmap will add batch commands for compiling the design, running one or all testbenches, and
  synthesizing `single_cycle_cpu`; keep this section synchronized with those committed scripts.
- Until those scripts are committed, the repository has no approved compile, simulation, or
  synthesis command.

## Key Defines (inc/alu.vh)
- `CARRY_LOOKAHEAD_ADDER_IMPL` - active by default; use `RIPPLE_CARRY_ADDER_IMPL` for ripple-carries
- `MUL_SHIFT_AND_ADD_IMPL` - active by default in mul.v

## Testbench Patterns
- All testbenches `include "common.vh"` and `include "assert.vh"`
- Assertions use `signal !== value`; the roadmap replaces the broken `assert_eq_fmt` macro and
  standardizes terminal pass/fail reporting.
- Tests may be exhaustive, directed, or deterministic-random according to the input space and must
  terminate explicitly.
- Multiplier tests sample the result after `busy` deasserts and must include a timeout.

## ALU Sub-modules
- `src/alu_mods/add.v` - implements add with `RIPPLE_CARRY_ADDER_IMPL` or `CARRY_LOOKAHEAD_ADDER_IMPL`
- `src/alu_mods/sub.v` - uses add with complemented operand + borrow_in=1'b1; its current
  `borrow_out` port exposes raw carry and is scheduled to be renamed
- `src/alu_mods/mul.v` - shift-and-add multiplier with `busy` output signal and `rstn` active-low reset

## Project Structure
- `src/` - Verilog modules (cpu, alu, control, memory, etc.)
- `inc/` - Header defines: `common.vh` (`WIDTH 32`), `alu.vh`, `assert.vh`
- `tests/tb/` - Verilog testbenches; the roadmap migrates them to Vivado Tcl execution
- `tests/wf/` - Generated waveform directory
- `tools/tcl/` - required location for the planned authoritative Vivado scripts

## Agent skills

### Issue tracker

Issues are tracked in GitHub Issues on this repo. See `docs/agents/issue-tracker.md`.

### Domain docs

Single-context layout (one `CONTEXT.md` + `docs/adr/` at the root). See `docs/agents/domain.md`.
