# Single-Cycle RISC-V CPU Refactor Roadmap

## Status

This roadmap describes the repository at commit `c68e105`. The RTL, testbenches, and build files
have not changed since the detailed review of `4eb5844`; the two later commits changed planning and
agent documentation only. No milestone below is complete.

The project has useful leaf modules and 16 testbenches, but the integrated CPU is not currently a
functional or synthesizable implementation:

- `src/single_cycle_cpu.v` includes a nonexistent header and does not elaborate.
- The PC reset is disconnected, and PC+4 and branch targets use instruction bits instead of the PC.
- Byte addresses are passed directly to word-indexed instruction and data memories.
- The ALU and decoders infer latches and silently map unsupported operations to valid ones.
- Tests mostly cover leaf modules; no test executes a program on `single_cycle_cpu`.
- Test assertions can terminate with a successful process status after a failure.
- The Make/Icarus flow is obsolete. Vivado Tcl is the sole build, simulation, and synthesis flow.

This document supersedes the previous phase plan and its 45-item execution sequence. The old
diagnosis remains useful historical evidence, but this roadmap is the implementation interface.

## Target

Produce a synthesizable, deterministic, tested learning CPU written in IEEE 1364-2005 Verilog.
Vivado tools invoked through version-controlled Tcl scripts must compile, simulate, and synthesize
the project on every supported host platform. Do not add or maintain an Icarus Verilog/Make flow.

The target is a documented RV32I subset, not full RV32I:

- Loads/stores: `lw`, `sw`.
- Control flow: `jal` and all six conditional branches.
- OP/OP-IMM integer operations: add, subtract where legal, shifts, signed/unsigned comparisons,
  XOR, OR, and AND.
- Arithmetic overflow is integrated into the ALU as a tested status output. RV32I does not trap on
  integer overflow, so the CPU does not consume it architecturally.

Explicitly out of scope:

- `jalr`, `lui`, and `auipc`.
- Byte and halfword loads/stores.
- Multiplication in the CPU datapath.
- CSRs, traps, interrupts, privilege modes, and other extensions.
- UVM infrastructure unless a separate requirement introduces UVM testbenches.

Unsupported and reserved encodings must have no architectural effect: no register write, memory
write, or control transfer.

## Dependency Map

```text
Contract
  -> Vivado Tcl + trustworthy tests
  -> programming/reset/PC
  -> base datapath
  -> ALU + overflow
  -> OP/OP-IMM/branches
  -> CI/docs/portability

Vivado Tcl + trustworthy tests -> standalone multiplier
ALU architecture -> CLA structural repair
```

Milestones on the main chain are ordered dependencies. The multiplier may proceed after the test
harness is trustworthy. The CLA structural repair may proceed after adder selection is explicit.

## Milestone 0: Freeze The Contract

### Scope

- Add a supported-instruction table that records opcode, legal `funct3`/`funct7` combinations,
  immediate form, ALU operation, writeback source, and control-flow behavior.
- Define unsupported/reserved encoding behavior.
- Define the PC and data addresses as byte addresses and both memories as word arrays.
- Restrict memory depths to powers of two or define guarded out-of-range behavior.
- Define the program-loading interface:
  - top-level program address and instruction data;
  - write edge and read visibility;
  - PC hold while programming;
  - register-file and data-memory writes disabled while programming.
- Select and document the Vivado version and concrete default FPGA part. Permit the part to be
  overridden by Tcl argument or environment variable.
- Keep synthesizable RTL and ordinary testbenches within IEEE 1364-2005.

### Exit Gate

Every later test maps to a documented behavior. Vivado commands use a real default part rather
than a placeholder.

## Milestone 1: Vivado Tcl And Trustworthy Tests

### Critical Files

- New `tools/tcl/` entry points and shared Tcl helpers.
- New deterministic design and test source manifests.
- `inc/assert.vh`, `inc/common.vh`, and every existing testbench.
- Legacy root and nested `Makefile`s.
- `.gitignore`.

### Work

1. Remove the bad opcode include from `src/single_cycle_cpu.v`.
2. Create one Vivado Tcl flow with explicit commands for:
   - compile/elaborate the complete design;
   - compile and run one named testbench;
   - run every testbench;
   - synthesize `single_cycle_cpu` and emit utilization/timing/latch reports;
   - clean generated project, simulation, and report artifacts.
3. Resolve the repository root from `[info script]`; never scan `$HOME` and never require the
   caller's working directory.
4. Put source ordering and include directories in one deterministic manifest shared by compile,
   simulation, synthesis, CI, and editor tooling.
5. Configure Verilog 2005 explicitly in Vivado and treat unexpected warnings as review findings.
6. Remove the shared RTL `` `timescale `` leakage from `inc/common.vh`; set simulation timescale in
   the Tcl flow or individual testbenches.
7. Rewrite assertion macros with parenthesized operands, an error counter, and one terminal
   `RESULT: PASS` or `RESULT: FAIL` sentinel.
8. Migrate every discovered testbench. Do not encode a fixed testbench count in scripts or docs.
9. Make the Tcl runner fail when simulation fails, times out, omits the terminal result, emits more
   than one terminal result, or reports `RESULT: FAIL`.
10. Add a permanent negative harness test proving a failed assertion makes Vivado batch mode exit
    nonzero.
11. Include the multiplier test in aggregate simulation.
12. Remove the obsolete Make/Icarus build flow after equivalent Vivado Tcl commands exist. Do not
    preserve legacy targets solely for compatibility; there are no identified external consumers.
13. Ignore Vivado-generated files while retaining intentional reports when required as evidence.

### Exit Gate

- A fresh clone can compile the top-level, run one test, run all tests, and synthesize through
  `vivado -mode batch -source tools/tcl/<entry>.tcl` without manual directory creation.
- The permanent negative harness test exits nonzero.
- No build script invokes Make, Icarus Verilog, or recursively searches a home directory.
- Top-level elaboration runs even while later functional milestones remain red.

## Milestone 2: Deterministic Programming, Reset, And PC

### Critical Files

- `src/single_cycle_cpu.v`.
- `src/program_counter.v`.
- `src/instruction_memory.v`.
- `src/instruction_increment.v`.
- Direct testbenches and the Vivado test manifest.

### Work

1. Add top-level active-low reset and program-address inputs.
2. Add explicit PC enable/hold behavior; do not overload architectural reset as an enable.
3. Separate instruction fetch and programming addresses in instruction memory.
4. Disable PC advancement, register writes, and data-memory writes while programming.
5. Feed `addr_instr_int`, not `curr_instr_int`, to PC+4 and branch-target logic.
6. Convert the byte PC to a word index using a width derived from instruction-memory depth.
7. Use nonblocking assignment for the clocked instruction-memory write.
8. Remove independently overridable parameters that are derived from memory depth.
9. Use the canonical asynchronous active-low reset template.
10. Rename mixed PC/instruction signals so their meaning is unambiguous.
11. Update every instantiation and direct test in the same change as each interface modification.

### Exit Gate

- A test can load arbitrary instruction-memory words at deterministic addresses.
- Programming cannot mutate PC, register-file, or data-memory architectural state.
- Reset, hold, address conversion, write timing, and fetch visibility are directly tested.
- Vivado compile and synthesis complete without dangling top-level inputs.

## Milestone 3: Base Datapath Correctness

### Critical Files

- `src/single_cycle_cpu.v`.
- `src/{instruction_memory,data_memory,register_file}.v`.
- `src/{instruction_increment,branch_target}.v`.
- `src/control_unit.v` and `src/ctrl_unit_mods/*.v`.
- `src/arithmetic_logic_unit.v`.
- New direct and CPU testbenches.

### Work

1. Convert the byte data address to a word index derived from data-memory depth.
2. Define and test memory boundary behavior.
3. Give every combinational decoder and ALU output a safe default before its `case` statement.
4. Normalize `funct3` ports to `[2:0]` and fix malformed-width literals.
5. Test safe main-decoder and ALU-decoder defaults exhaustively over relevant control inputs.
6. Add directed tests for register-file x0 semantics, memories, instruction increment, branch
   target, and CPU mux/control behavior.
7. Add a top-level CPU test that loads and executes a minimal hand-assembled program using only:
   `addi`, `add`, `sub`, `and`, `or`, `sw`, `lw`, `beq` taken/not taken, and `jal`.
8. Make the program write one final signature to a designated data-memory address. Centralize any
   unavoidable hierarchical access in one testbench task and enforce a cycle watchdog.

Do not include `slt` in this milestone; it is repaired in Milestone 4.

### Exit Gate

- The minimal CPU program writes the expected signature.
- Unsupported opcodes cannot mutate architectural state.
- Vivado synthesis reports zero inferred latches and no multiply-driven nets.
- Existing non-multiplier leaf tests remain green. The known-broken multiplier remains a tracked
  red test until Milestone 6.

## Milestone 4: ALU Architecture And Overflow

### Critical Files

- `inc/alu.vh`.
- `src/arithmetic_logic_unit.v`.
- `src/alu_mods/{add,sub,overflow}.v`.
- RCA, CLA, subtraction, ALU, and overflow testbenches.

### Work

1. Define ALU operation encodings once in a guarded header.
2. Replace compilation-unit macro selection of RCA versus CLA with a Verilog-2005 module parameter
   and named generate branches. Parameterize `sub` consistently.
3. Add required `generate/endgenerate` regions and remove hard-coded subcomponent-width arithmetic.
4. Instantiate `add` and `sub` in the ALU rather than duplicating behavioral arithmetic.
5. Repair signed `slt` and zero-extend its Boolean result to `32'd1`.
6. Derive `zero_out` combinationally from the selected ALU result.
7. Rename subtraction's raw carry output accurately and update its callers/tests.
8. Recut `overflow.v` around decoded add/sub intent and operand/result signs.
9. Integrate `overflow_out` into the ALU. It is a tested status output, not an architectural trap.
10. Add directed boundary vectors for signed minimum/maximum values, carry, subtraction carry,
    overflow, zero/nonzero results, and RCA/CLA functional equivalence.

### Exit Gate

- Either adder implementation can be selected independently of source order and global macros.
- Every ALU and overflow output is assigned on every combinational path.
- ALU and overflow boundary tests pass.
- The CPU signature test extends through `slt` and remains green.

## Milestone 5: OP, OP-IMM, And Conditional Branches

### Critical Files

- `inc/alu.vh`.
- ALU, control unit, both decoders, and top-level CPU.
- Decoder, ALU, control-unit, and CPU testbenches.

### Work

1. Widen ALU control to represent add, subtract, SLL, SLT, SLTU, XOR, SRL, SRA, OR, and AND.
2. Decode OP and OP-IMM legal combinations explicitly, including SUB versus ADD and SRA versus SRL.
3. Route the complete relevant `funct7` field through the CPU and control hierarchy, then reject
   reserved `funct7` combinations safely instead of silently mapping them to an operation.
4. Implement BEQ, BNE, BLT, BGE, BLTU, and BGEU predicates.
5. Reject reserved branch `funct3` values without control transfer.
6. Add exhaustive decoder tables and directed ALU boundary vectors.
7. Extend the CPU signature program with every supported R-type and immediate counterpart, all six
   branch forms taken and not taken, signed/unsigned comparison extremes, and shifts by 0, 1, 31.

### Exit Gate

- The instruction contract and exhaustive decoder tests agree.
- Reserved encodings have no architectural effect.
- The complete CPU signature test passes within its watchdog limit.

## Milestone 6: Standalone Multiplier

### Critical Files

- `src/alu_mods/mul.v`.
- `src/alu_mods/mul_mods/shiftnadd_mod/*.v`.
- Multiplier and shift/register testbenches.

### Work

1. Define an explicit start/busy/result protocol.
2. Give each state register one sequential owner and reset every state element.
3. Capture both operands on start.
4. Correct partial-product alignment, cycle count, completion timing, and back-to-back operation.
5. Use nonblocking assignments in clocked logic and canonical active-low asynchronous reset.
6. Test zero, one, maximum values, powers of two, varied bit patterns, and repeated jobs without
   reset. Add timeouts for stuck `busy` behavior.

Keep multiplication outside the CPU datapath.

### Exit Gate

Vivado simulation and synthesis show deterministic, single-driver multiplier behavior across
back-to-back operations.

## Milestone 7: CLA Structural Repair

### Critical Files

- `src/alu_mods/add_mods/cla_mod/modified_full_adder.v`.
- `src/alu_mods/add_mods/cla_mod/{four_bit_lookahead,four_bit_cla}.v`.
- Direct CLA testbenches and synthesis reports.

### Work

1. Correct propagate generation so it is independent of carry-in.
2. Update the direct modified-full-adder reference model.
3. Preserve exhaustive numerical tests and explicitly test generate/propagate semantics.
4. Remove hard-coded width assumptions or document and enforce a fixed four-bit component.
5. Record Vivado structural or timing evidence of the intended carry architecture. Treat reports as
   evidence, not a brittle timing threshold.

### Exit Gate

Arithmetic results remain correct, generate/propagate outputs match their definitions, and the
synthesized structure no longer depends on ripple propagation disguised as lookahead.

## Milestone 8: CI, Documentation, And Portability

### Critical Files

- `.github/workflows/*`.
- `tools/tcl/*` and the shared source/test manifests.
- `tools/slang/*`.
- `README.md`, `AGENTS.md`, project style documentation, and `opencode.jsonc`.
- `.gitignore`.

### Work

1. Add CI that runs Vivado Tcl compile, all simulations, the negative harness test, and synthesis.
2. Make the same Tcl entry points work on Linux and Windows. Platform-specific wrappers may differ,
   but source inventory and behavior must not.
3. Complete Slang configuration from the same deterministic source manifest where practical.
4. Replace normative SystemVerilog guidance with concise project-specific Verilog-2005 rules.
   Retain the lowRISC guide only as clearly non-normative reference material.
5. Document prerequisites, supported instructions, programming protocol, Vivado Tcl commands,
   project structure, generated artifacts, wave viewing, synthesis reports, and license.
6. Correct stale agent guidance and generated-file ignores.
7. Run fresh-clone acceptance on Linux and Windows with no Make/Icarus dependency.

### Exit Gate

- CI compile, simulation, negative-test, and synthesis gates are green.
- Linux and Windows execute the same Vivado Tcl flow and test inventory.
- Every documented command exists and works from outside the repository root.
- A fresh clone needs no manual directory setup.

## Global Acceptance Gates

The roadmap is complete only when all gates pass:

1. **Fresh clone**: Vivado Tcl commands create their own output directories and do not rely on the
   caller's current directory.
2. **Compile**: complete design elaboration succeeds as Verilog 2005 with reviewed warnings.
3. **Negative harness**: the permanent failing test produces a nonzero Vivado batch exit.
4. **Simulation**: every discovered testbench reports exactly one `RESULT: PASS`.
5. **CPU program**: the complete supported-subset program writes the expected signature before its
   watchdog expires.
6. **Synthesis**: no inferred latches, multiply-driven nets, dangling required ports, or fatal
   warnings; utilization and timing reports are retained.
7. **Portability**: Linux and Windows use the same source/test manifests and produce the same test
   result set.
8. **CI**: compile, tests, negative harness, and synthesis run automatically.
9. **Documentation**: README and AGENTS commands match the committed Tcl entry points.

## Risk Register

- **Vivado licensing and installation**: CI and fresh-clone documentation must identify the required
  Vivado version, license, executable discovery, and supported runner environment.
- **Interface migration**: reset, program address, PC enable, ALU status, and widened controls must
  update modules, all instantiations, and direct tests atomically.
- **Compilation-unit macro state**: generic unguarded defines and source-order-dependent behavior
  must be removed, not hidden by a favorable manifest order.
- **Source inventory drift**: compile, simulation, synthesis, CI, and editor tooling must derive
  from one deterministic inventory.
- **Simulation success signaling**: process exit alone is insufficient; the Tcl runner must validate
  exactly one terminal result sentinel and enforce a timeout.
- **Synthesis-only defects**: simulation cannot prove absence of latches, multiple drivers, or the
  intended CLA structure. Vivado synthesis reports are required gates.
- **Hierarchical verification seams**: keep CPU-state inspection behind one testbench helper and
  prefer a memory signature to internal register-by-register coupling.
- **Random tests**: use directed boundaries first; deterministic pseudorandom vectors second; record
  the seed on failure.

## Historical Note

The review against `4eb5844` identified approximately 45 findings. Important examples remain valid:
the bad include, disconnected reset, PC/instruction wiring errors, memory indexing errors, four
inferred latches, incomplete ISA decoding, multiplier multi-driver behavior, incorrect CLA
propagate semantics, assertion false-success behavior, missing top-level tests, and contradictory
SystemVerilog style guidance. This rewrite groups those findings into behavior-complete milestones
instead of carrying a line-number-sensitive defect ledger as the execution plan.
