# Refactor Handoff — Single-Cycle RISC-V CPU

## Context

This document is an implementation handoff. It records a full review of the repository
conducted on **2026-08-26** against commit **`4eb5844`** ("refactor(all): complete phase 1 +
phase 2"), and it **supersedes `.opencode/plans/refactor-plan-2026-08-25_13-51-59.md`**.

Every finding below was verified first-hand with `iverilog 14` — compiled, elaborated, and in
several cases measured — rather than inferred from reading. Where a claim rests on algebra or
on a tool's behavior, the evidence is stated inline.

**Headline state of the repository:**

1. **It is neither functional nor synthesizable.** The top module does not reach elaboration
   (a misspelled `` `include ``), the build system cannot run a single test, and after clearing
   those two blockers the datapath is still mis-wired in three places, has a dangling reset,
   and infers four latches. Individual leaf modules are mostly clean; the *integration* is what
   is broken.
2. There are ~45 distinct findings, catalogued in Part 1. The phased remediation plan is Part 2.

**On the superseded plan.** Its diagnosis was largely correct and it was a good plan. But commit
`4eb5844` **did not actually complete its phases 1 and 2** — several items were half-applied,
and the commit *introduced* a new blocker. That plan also missed six real defects and sequenced
the top-level testbench far too late. Part 1 §F reconciles the two documents item by item:
what is genuinely done, what is still open, and what was never covered.

## Start here

**The repository does not compile and no test can run.** Do not begin anywhere else.

- **Phase 0, item 1** — delete the bad `` `include `` in `src/single_cycle_cpu.v:2`.
- **Phase 0, item 2** — replace the `$HOME`-scanning `PROJECT_DIR` in all six Makefiles.

Until both are done, nothing in this repository can be built, run, or regression-tested, and
no other change can be verified. These two edits are small and unblock everything else.

## Settled constraints

The following are decided. They are not open questions, and the implementer should honor them
rather than relitigate them:

1. **Stay on IEEE 1364-2005, and enforce it.** Add `-g2005` to every `iverilog` invocation.
   The vendored lowRISC style guide is to be retired from `opencode.jsonc` — it is a
   *SystemVerilog* guide (119 mentions of `logic`, 19 `always_comb`, 16 `always_ff`,
   19 `typedef`) prescribing constructs that are illegal under the standard this project
   mandates. See E18 and Phase 7 item 32.
2. **Implement full RV32I branches and ALU ops.** The current silent mis-execution — all six
   branch forms decoding as `BEQ`, and `SLL`/`SLTU`/`XOR`/`SRL`/`SRA` silently becoming `ADD` —
   is to be fixed, not documented as an acceptable subset. See D1–D3 and Phase 6.
3. **Work the phases in order.** Each phase is independently verifiable, and the ordering
   encodes real dependencies — most importantly Phase 6 on Phases 2 and 5 (see Risks).
   Stopping after any phase leaves the repository in a better state than before it; skipping
   ahead does not.
4. **Split the build system by host platform.** On Linux, keep `iverilog` + `make` as the
   build/synth/test toolchain, with one exception: any **UVM testbench** is SystemVerilog and is
   compiled/run through the SystemVerilog toolchain (not `-g2005` iverilog), since UVM cannot be
   expressed in IEEE 1364-2005. On **Windows**, do not port the Makefiles — build, synthesize,
   and test the project via **Tcl scripts** instead (e.g. driven through Vivado's `-mode tcl`,
   matching the synthesis flow already used in Verification §5). The two flows are maintained in
   parallel, not one generated from the other. See Phase 0 item 6 and Phase 7 item 39.

---

## Part 1 — Findings

### A. Hard blockers (nothing runs today)

| # | Location | Defect |
|---|---|---|
| A1 | `src/single_cycle_cpu.v:2` | `` `include "riscv_opcode.vh" `` — the file is `inc/riscv_opcodes.vh` (plural). Hard preprocessor error; the top module has not compiled since `4eb5844`, which introduced it. The file references no opcode macro, so the include should be **deleted**, not corrected. |
| A2 | `Makefile:4`, `tests/tb/Makefile:2`, and all 4 nested suite Makefiles | `PROJECT_DIR = $(shell find -L $$HOME/Personal ...)`. `$HOME` on the review machine is `…/AppData/Roaming/SPB_Data`; `$HOME/Personal` does not exist. `PROJECT_DIR` resolves to **empty** → `vpath` searches `/src`, includes become `-I/inc`, outputs go to `/tests/bin`. **No test in this repo can currently be run.** `2>/dev/null` hides the failure. Root `Makefile:4` and `rca_mod/Makefile:2` scan *all* of `$HOME` with `-L`; the other four scan `$HOME/Personal`. All use recursive `=`, so the scan re-runs on every one of the 4–6 references. |

```
$ iverilog -g2005 -Iinc -s single_cycle_cpu -o cpu.vvp src/**/*.v
src/single_cycle_cpu.v:3: Include file riscv_opcode.vh not found
Preprocessor failed with 1 error(s).

$ make -C tests/tb -n program_counter_tb
find: '/src': No such file or directory
make: *** No rule to make target 'program_counter.v'.  Stop.
```

### B. Functional bugs in the datapath

| # | Location | Defect |
|---|---|---|
| B1 | `src/single_cycle_cpu.v:47` | `instruction_increment.curr_pc_in` is fed `curr_instr_int` — the **instruction word**, not the PC. Computes `instruction + 4`. Must be `addr_instr_int`. |
| B2 | `src/single_cycle_cpu.v:110` | `branch_target.curr_pc_in` fed `curr_instr_int` likewise. Branch/jump targets are `instruction + imm` instead of `PC + imm`. |
| B3 | `src/single_cycle_cpu.v:40-44` | `program_counter pc` leaves **`rstn_in` unconnected** (`program_counter.v:5` declares it). Simulation: floats to `z` → `addr_out` is X forever. Synthesis: unconnected input ties low → PC held in reset at 0 permanently. **The top module has no reset port at all.** |
| B4 | `src/arithmetic_logic_unit.v:29` | `` {`WIDTH{operand_a_in < operand_b_in}} `` — two bugs: (a) yields `32'hFFFFFFFF` on true, but RV32I `slt` must yield `32'd1`; (b) `<` on unsigned nets makes this `sltu`, not `slt`. Both must be fixed; (a) also breaks branch resolution once BLT/BGE land. |
| B5 | `src/single_cycle_cpu.v:52` | 32-bit **byte** PC drives `instr_mem.addr_in [7:0]` (`$clog2(256)`) into a **word-indexed** array — silently truncated. PCs 0,4,8 hit words 0,4,8; ¾ of IMEM unreachable. Needs `addr_instr_int[9:2]`. |
| B6 | `src/single_cycle_cpu.v:94` | Same on the data side: byte address → `dm.addr_in [8:0]` into a word-indexed array. Needs `alu_res_int[10:2]`. |
| B7 | `src/instruction_memory.v:17` | `instr_mem[addr_in] = instr_in;` — **blocking** assignment in `always @(posedge clk_in)`, racing the continuous read at `:20` and every other clocked block. `data_memory.v:19` correctly uses `<=`; the two memories disagree. |
| B8 | `src/alu_mods/add.v:10,29` | **`add.v` never includes `inc/alu.vh`**, where `RIPPLE_CARRY_ADDER_IMPL` / `CARRY_LOOKAHEAD_ADDER_IMPL` live. Compiled without some *other* file having pulled `alu.vh` in first, **both branches vanish and `add` elaborates as an empty module with floating outputs** — silently, no error. Measured: `add` alone → 1,705-byte `.vvp`; with `-DCARRY_LOOKAHEAD_ADDER_IMPL` → 95,660 bytes. Correctness currently depends on **command-line file order**. Conversely, if both macros are ever defined, the two `` `ifdef `` blocks (not `` `ifdef/`else ``) both elaborate → duplicate `carry_int`, duplicate `genvar i`, and multi-driver on `result_out`/`carry_out`. |
| B9 | `src/alu_mods/mul.v:28-33` vs `:42-48` | `accumulator` and `counter` are driven from **two separate `always` blocks**. Multiply-driven register — a hard synthesis error, non-deterministic in simulation. |
| B10 | `src/alu_mods/mul.v` | `accumulator` is cleared **only** on `negedge rstn`, never on `set` → back-to-back multiplies accumulate on top of the previous product. Compounding it, `shift_reg` holds `busy` for 33 cycles while `mul` finishes its 32 steps in 32, so a **second accumulation pass** starts over the un-cleared accumulator. The first partial product is also misaligned by one position (the shift register has already advanced when `mul` does its `counter=0` add). |
| B11 | `src/alu_mods/mul_mods/shiftnadd_mod/shift_reg.v:32-42` | **Blocking assignments inside `always @(posedge clk)`** for `busy` and `counter`, read by `mul.v:36` and `mul.v:43` → scheduler-order-dependent race. `rstn` is ignored entirely by this block, so `busy`/`counter` power up as X and are un-resettable in hardware. |
| B12 | `src/alu_mods/sub.v:6,19` | `borrow_out` is the raw adder **carry** (1 = *no* borrow) exported without inversion. `sub_tb.v:29` already works around it by asserting on `~borrow_out`. Misnamed port. |
| B13 | `src/alu_mods/add_mods/cla_mod/modified_full_adder.v:8` | `p_out = (a_in \| b_in) & c_in;` — the propagate term must be independent of `c_in` (`a^b` or `a\|b`). Contaminating it makes each lookahead term depend on the previous carry, so **`four_bit_cla` is a ripple-carry adder wearing a CLA costume** — and *slower* than `full_adder`'s chain, because of the extra logic depth. Verified algebraically that the sums and carries are still **numerically correct**, which is exactly why the exhaustive testbenches pass and the defect is invisible. `four_bit_lookahead.v:9-12` itself is textbook-correct. Secondary consequence: `g_out`/`p_out` are not valid group generate/propagate, so this block cannot be composed into a hierarchical carry-lookahead. |

### C. Latch inference (elaborates, synthesizes to wrong hardware)

| # | Location | Signal latched |
|---|---|---|
| C1 | `src/arithmetic_logic_unit.v:20-26` | `zero` assigned **only** in the `` `SUB `` arm → **the zero flag is a latch, not a combinational output**. `beq` works only because `alu_decoder.v:11` forces SUB on branches; `zero` is stale on every other cycle and X until the first SUB. |
| C2 | `src/arithmetic_logic_unit.v:30` | `default:;` — empty. `result_out` latches on any unmapped opcode. |
| C3 | `src/ctrl_unit_mods/main_decoder.v:46-54` | The `` `BEQ `` arm omits `res_src_sel_out`; all five other arms and the default assign it. 2-bit latch. |
| C4 | `src/ctrl_unit_mods/alu_decoder.v:26` | `default:;` — empty. `opctrl_out` latches when `alu_op_in == 2'b11`. |

The superseded plan's phase 2 claimed C3 and C4 fixed. They are not.

### D. ISA correctness — silent mis-execution

| # | Location | Issue |
|---|---|---|
| D1 | `src/ctrl_unit_mods/main_decoder.v:46` | Opcode `1100011` is decoded **without checking `funct3`**, so `BNE`, `BLT`, `BGE`, `BLTU`, `BGEU` all silently execute as `BEQ`. The macro name `` `BEQ `` obscures that it is the whole BRANCH class. |
| D2 | `src/ctrl_unit_mods/alu_decoder.v:13-24` | Only `funct3` ∈ {000, 010, 110, 111} are decoded. `001` (SLL/SLLI), `011` (SLTU/SLTIU), `100` (XOR/XORI), `101` (SRL/SRA/SRLI/SRAI) fall through the inner `default` and **silently become ADD**. |
| D3 | `src/arithmetic_logic_unit.v` | No `XOR`, `SLL`, `SRL`, `SRA`, `SLTU`. Opcode field is 3 bits — too narrow for the 10 RV32I ALU ops. |
| — | — | `JALR`, `LUI`, `AUIPC` are not decoded and correctly fall to the safe `default`. `imm_src_sel` is only 2 bits, leaving no room for U-type, so these stay out of scope (see *Deliberately out of scope*). |

### E. Hygiene, portability, and tooling

| # | Location | Issue |
|---|---|---|
| E1 | `inc/common.vh:4` | `` `timescale 1ps/1ps `` inside an `` `ifndef `` guard. `` `timescale `` is a **directive, not a macro** — the guard makes it apply once, to whichever file includes `common.vh` first, then leak forward to every module compiled after. `iverilog -Wall` emits *"timescale inherited from another file"* for **every module in the design**. `control_unit.v`, `main_decoder.v` and `alu_decoder.v` don't include `common.vh` at all. Belongs in testbenches or on the command line. |
| E2 | all Makefiles | iverilog is invoked with **no `-g2005`** and no `-Wall`. iverilog 14 defaults to `-g2012`. `README.md:2` and `AGENTS.md:4` claim strict IEEE 1364-2005; nothing enforces it. `tools/slang/slang.f` *does* set `--std 1364-2005`, so the two configs disagree — and slang is not installed. |
| E3 | `src/alu_mods/add.v:16,35`, `shift_reg.v:20`, `four_bit_lookahead_tb.v:20` | Loop-generate constructs written **without `generate`/`endgenerate`**. Legal in IEEE 1800, not in 1364-2005 (§12.1.3). iverilog accepts them even under `-g2005`; a strict tool would not. |
| E4 | `tests/tb/alu_mods/add_rca_impl_tb.v:28` | `integer signed i, j;` — `signed` is not a legal qualifier on `integer` in 1364-2005. The near-identical sibling `add_cla_impl_tb.v:29` writes `integer i, j;`; copy drift. |
| E5 | `inc/assert.vh:12` | `assert_eq_fmt` places macro arguments **inside a string literal** — args do not expand inside strings in Verilog. The message prints the literal text *"expected signal to be format, but actual format"* and the two `$display` arguments are appended as bare decimals. The `format` parameter is inert; the macro is strictly worse than `assert_eq`. Same class at `:6`: the word `signal` never expands, so failures never name which signal failed. Affects `immediate_sign_extend_tb.v:37`, `add_rca_impl_tb.v:34-35`, `add_cla_impl_tb.v:35-36`, `sub_tb.v:28-29`. |
| E6 | `inc/assert.vh:7,13` | Failures call `$finish`, which exits **0**. With `.SILENT` in all six Makefiles and an `[INFO]` tag identical to the pass message, **`make ... all` returns 0 even when every test fails.** There is no red/green signal anywhere in the repo, and no CI. |
| E7 | `inc/assert.vh:4,10` | Macro parameters are unparenthesized: `if (signal !== value)`. `` `assert_eq(a & b, c) `` silently becomes `a & (b !== c)` and always passes. Latent trap in the repo's only test primitive. |
| E8 | `inc/assert.vh:1` | Include guard named `TESTBENCH_VH`, not `ASSERT_VH` — the only header in the repo whose guard doesn't match its filename. |
| E9 | `src/arithmetic_logic_unit.v:3-8` | Unguarded `` `define `` of `` `ADD ``, `` `SUB ``, `` `AND ``, `` `OR ``, `` `LT `` in a `.v` file. Generic names, compilation-unit-global, never `` `undef ``'d. `alu_decoder.v` duplicates the same encoding as bare literals — **two uncoordinated sources of truth**. Same pattern at `mul.v:3` (`` `define MUL_SHIFT_AND_ADD_IMPL `` unconditionally, immediately guarding an `` `ifdef `` that can never be false). |
| E10 | `src/alu_mods/overflow.v` | Never instantiated (dead code). Takes raw `opcode_in`/`funct7_in` instead of decoded control. Declares `input wire [31:25] funct7_in` and indexes `funct7_in[30]` — works only because of that declared range; a conventional `[6:0]` connection would silently return `x`. **Two real bugs:** for `ADDI` (`0010011`) `instr[30]` is part of the *immediate*, so a negative immediate selects the subtract rule; and with no `funct3` input it asserts overflow on `AND`/`OR`/`XOR`/`SLT`/shifts, which cannot overflow. The two sign rules themselves are correct. |
| E11 | `src/ctrl_unit_mods/main_decoder.v:78,58,69` | `alu_src_sel_out = 1'b00;` — malformed sized literal (the only surviving iverilog warning in the build). `:58` `2'b01` and `:69` `2'b00` are 2-bit literals into the 1-bit port at `:7`. All three truncate to the intended value, by luck. |
| E12 | `src/control_unit.v:4`, `src/ctrl_unit_mods/alu_decoder.v:4` | `input wire [14:12] funct3_in` — a 3-bit vector with indices 14..12. Comparisons work by value, but any `funct3_in[2]` is an out-of-range select returning `x`. Needed as `[2:0]` for the full-branch work. Same pattern at `overflow.v:6`. |
| E13 | `src/program_counter.v:9-12`, `d_flip_flop.v:8-13` | Async reset written with the *active* condition first (`if (rstn) … else reset`). Logically equivalent, but not the recognized inference template; strict flows warn or reject. |
| E14 | `src/alu_mods/add.v:37` | `localparam idx_end = i*`CLA_SUBCOMPONENT_BIT_WIDTH + 3;` — hardcodes `3` against a parameterized width. Same class at `four_bit_lookahead.v:9-12` (four hand-written equations) and `cla.vh:4`. Changing the macro breaks these silently. |
| E15 | `tests/tb/**` | 12 of 27 modules have **no testbench**, concentrated at the top of the hierarchy: `single_cycle_cpu`, `register_file`, `control_unit`, `arithmetic_logic_unit`, `main_decoder`, `alu_decoder`, `branch_target`, `instruction_increment`, `mux21_32b`, `mux31_32b`, `mux21`, `overflow`. **There is no top-level CPU test** — which is precisely why `4eb5844` shipped broken. |
| E16 | `tests/tb/**` | 8 of 16 testbenches never call `$finish`. `shift_reg_tb.v:37` asserts `n_out` (64-bit) against `n_in << i` (self-determined to **32 bits**), so the upper half of the register is untestable. `sub_tb.v:4` defines the CLA macro without `` `undef ``-ing RCA first, unlike its two siblings — fragile. `immediate_sign_extend_tb.v:9` drives a `clk_in` that connects to nothing. |
| E17 | Makefiles | `mul_tb` is defined but **missing from `alu_mods` `all:`** and from `.SILENT` — the repo's only multiplier test never runs in any aggregate build. `tests/wf/` **does not exist and no recipe creates it** (zero `mkdir` across all six Makefiles); `tests/bin/` is gitignored, so **a fresh clone cannot build**. 5 of 16 TBs produce no VCD. Viewer is `surfer` in three Makefiles and `gtkwave` in `shiftnadd_mod/Makefile:28`, which also uses a `SECOND_TARGET := $(word 2, $(MAKECMDGOALS))` hack that re-runs the test. Root `clean` uses a relative path, omits `tests/wf/`, and fails on an empty `tests/bin`. The five nested Makefiles are near-identical copy-paste with three separate drifts. |
| E18 | `verilog-style-guide.md` + `opencode.jsonc:12-14` | The vendored lowRISC guide is loaded as agent instructions on every session (98 KB). It is a **SystemVerilog** guide — 119 mentions of `logic`, 19 `always_comb`, 16 `always_ff`, 19 `typedef`, 12 `interface` — none legal under the 1364-2005 the project mandates. The two documents cannot both be followed, and the contradiction is nowhere acknowledged. |
| E19 | `AGENTS.md` | Drift: `:12` says **`vpv`** (no such tool; all Makefiles use `vvp`); `:13` says "3 base testbenches" (there are 4); `:14` claims `alu_mods all` includes `mul` (it does not); `:15` claims VCDs land in `tests/wf/` (the directory doesn't exist, and 5 TBs emit none); `:23` documents `assert_eq_fmt`'s `format` argument, which is inert; `:24` "~100 random inputs then `$finish`" is wrong for the 8 TBs that never `$finish` and the exhaustive ones; `:25` says assert at `@(posedge busy)` but `mul_tb.v:41-42` asserts after `@(negedge busy)`; `:34` omits `riscv_opcodes.vh` and `cla.vh`; `:37` understates the root Makefile (it recurses into all 5 nested Makefiles); `:47` points at a `CONTEXT.md` and `docs/adr/` that **do not exist**. |
| E20 | `README.md` | Four lines. No build instructions, no prerequisites, no directory map, no ISA description, no license mention despite `LICENSE` being present. All build knowledge lives in `AGENTS.md`, which is agent-facing and wrong in nine places. |
| E21 | `.gitignore` | Two lines. Does not cover `vivado.jou` / `vivado.log` (both untracked in the repo root at review time), nor `*.vcd`, `.Xil/`, `usage_statistics_webtalk.*`. `docs/` is untracked and `AGENTS.md` has uncommitted edits. |
| E22 | `tools/slang/slang.f` | Contains only `-Iinc` and `--std 1364-2005` — **no source file list**, so the language server elaborates nothing. Both it and `slang-server.f` use relative paths, so they only work from the repo root. |
| E23 | `src/single_cycle_cpu.v:6,40` | `prog_enable_in` gates only the IMEM write. There is no separate program-address port and no PC stall, so the load address is whatever the PC happens to be — while the PC is steered by control signals decoded from X. Program loading is not deterministic. |
| E24 | `src/instruction_increment.v:4-5` | `curr_pc_in` in, `curr_plus_four_instr_out` out. Mixed pc/instr nomenclature — the proximate cause of B1/B2: `4eb5844` renamed the *ports* as the superseded plan asked but never rewired the *connections*. |

### F. Reconciliation with the superseded plan

**Genuinely fixed by `4eb5844` — do not redo:** `register_file.v` (`output wire` + `assign`,
`localparam REG_FILE_SIZE`) · `mux31_32b.v` default arm · `immediate_sign_extend.v` default arm
— and its I/S/B/J bit-scrambles are **verified correct bit-by-bit against RV32I**, the cleanest
file in the design · `inc/riscv_opcodes.vh` extracted and guarded (all six encodings verified) ·
`program_counter.v` reset logic added · memories parameterized with `$clog2` (which *is* legal
in 1364-2005) · `alu_decoder.v:15`'s `!(op_in[5] && funct7_bit5_in)` guard, which correctly
stops `ADDI` with `imm[10]=1` decoding as SUB.

**Claimed done but still open:** B1, B2, B5, B6, B7, C3, C4 — superseded-plan items 2, 4, 5, 6.

**Introduced by the "fix" commit:** A1.

**Missed by the superseded plan entirely:** A2 (called a "slow `$HOME` scan"; it is a total build
failure) · B3 (dangling `rstn_in`) · B4a (`slt` returning all-ones, not just signed/unsigned) ·
B8's real hazard (that plan warned about *two* implementations elaborating; the live problem is
*zero*) · B10/B11 (mul double-pass, shift misalignment, `shift_reg` races) · D1/D2 (silent
branch and ALU-op mis-execution) · E2 (`-g2005` never passed) · E3/E4 (actual 1364-2005
violations) · E7 (unparenthesized macro args) · E10's `funct3` bug · E17 (fresh clone cannot
build) · E18 (the style-guide contradiction).

**Where it got the emphasis wrong:** its item 18 treats `modified_full_adder` as a minor
propagate tweak. It is the root cause of B13 — the CLA has no lookahead behavior at all.

**Ordering problem:** it puts `single_cycle_cpu_tb` at item 27 of 35, after the ALU rewrite and
the assertion migration. That is the one test that catches phases 1–2. It moves up.

---

## Part 2 — Phased plan

Each phase is independently verifiable. Stopping after any phase leaves the repository in a
better state than before it.

### Phase 0 — Make the build work *(prerequisite for everything)*

1. **`src/single_cycle_cpu.v:2`** — delete the `` `include "riscv_opcode.vh" `` line (A1).
2. **New `tests/mk/common.mk`** — derive the root from the makefile's own location, never `$HOME`:
   ```make
   PROJECT_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/..)
   ```
   Use `:=`, not `=`. Hold `COMPILE_FLAGS` (**add `-g2005 -Wall`**, E2), `SIMULATE_FLAGS`, the
   `iverilog`/`vvp` pattern rules, a single `view.%` target, and `clean`. The five suite
   Makefiles shrink to a target list plus source prerequisites. Drop the blanket `.SILENT` (E6)
   and the `SECOND_TARGET` hack; standardize on `surfer` (E17).
3. **Create output dirs** — order-only prerequisites that `mkdir -p` `tests/bin` and `tests/wf`,
   so a fresh clone builds (E17). Root `clean` → `rm -rf tests/bin/* tests/wf/*`.
4. **`make lint`** — a first-class target that elaborates the whole design
   (`iverilog -g2005 -Wall -Iinc -s single_cycle_cpu`) and fails on error. A1 survived a commit
   because nothing ever compiled the top module.
5. **`.gitignore`** — add `vivado.jou`, `vivado.log`, `*.vcd`, `.Xil/`,
   `usage_statistics_webtalk.*` (E21).
6. **New `tools/tcl/` build scripts (Windows)** — `build.tcl`, `synth.tcl`, `test.tcl` (or one
   entry script dispatching subcommands) that reproduce, via Vivado's `-mode tcl`, what the
   Makefiles do on Linux: elaborate/lint the design, run each testbench and report pass/fail, and
   drive synthesis. These scripts are the Windows build system going forward — they are not a
   stopgap and are not expected to shell out to `iverilog`/`make`. Keep the source file lists
   (`src/**/*.v`, `-Iinc`) in one place shared conceptually with `tests/mk/common.mk` so the two
   flows don't drift on *what* gets compiled, only *how*. UVM testbenches (once added) are
   SystemVerilog and are compiled/run by these Tcl scripts (or an equivalent SV-capable flow) on
   both platforms — never by `iverilog -g2005`, which cannot parse UVM.

*Verify (Linux):* `make lint` and `make -C tests/tb all` both run.
*Verify (Windows):* the Tcl build/synth/test scripts run end-to-end with no `make`/`iverilog`
dependency.

### Phase 1 — Datapath wiring

6. **`src/single_cycle_cpu.v`**
   - `:47` and `:110` → `.curr_pc_in(addr_instr_int)` (B1, B2).
   - Add `input wire rstn_in` to the port list; connect `.rstn_in(rstn_in)` on `pc` (B3).
   - `:52` → `.addr_in(addr_instr_int[9:2])`; `:94` → `.addr_in(alu_res_int[10:2])` (B5, B6).
     Derive both slices from the memories' `BUS_WIDTH` via a top-level `localparam`, not literals.
   - Header comment naming the implemented ISA.
7. **`src/instruction_memory.v:17`** — `=` → `<=` (B7). Make `BUS_WIDTH` a `localparam` so it
   cannot be overridden independently of `MEM_SIZE`.
8. **`src/program_counter.v:9-12`** and **`d_flip_flop.v:8-13`** — canonical
   `if (!rstn) … else …` template (E13).
9. **`src/instruction_increment.v`** — rename `curr_plus_four_instr_out` → `pc_plus_four_out`
   so both ports speak about the PC (E24). Update the one call site.
10. **Program-load protocol** (E23) — hold the PC in reset while `prog_enable_in` is asserted and
    give `instruction_memory` a dedicated `prog_addr_in` port. Document it in the top-module header.

### Phase 2 — Latch elimination and decoder hygiene

11. **`src/ctrl_unit_mods/main_decoder.v`** — assign **all eight** outputs to safe defaults
    *before* the `case`, then let each arm override. This structurally prevents C3 recurring
    rather than patching the one arm. Fix the three malformed literals at `:58`, `:69`, `:78` (E11).
12. **`src/ctrl_unit_mods/alu_decoder.v`** — same default-before-`case` structure; real value in
    `default` (C4). Change `funct3_in` to `[2:0]` here and in `src/control_unit.v:4` (E12).
13. **`src/arithmetic_logic_unit.v`** — default-assign `result_out` **and** `zero` before the
    `case`; give `default` a defined value (C1, C2).

*Verify:* Vivado `synth_design` reports **zero** inferred latches (see Verification §5).

### Phase 3 — Top-level testbench *(moved up from superseded item 27)*

14. **`tests/tb/single_cycle_cpu_tb.v`** — hand-assemble a program exercising
    `addi / add / sub / and / or / slt / sw / lw / beq taken / beq not-taken / jal`.
    Load via `prog_enable_in`/`instr_in`, release `rstn_in`, clock, then check architectural
    state through hierarchical references (`dut.reg_file.registers[…]`, `dut.dm.data_mem[…]`).
    **This is the regression gate for Phases 1–2 and for everything after it.**
15. Add `register_file_tb`, `control_unit_tb`, `arithmetic_logic_unit_tb` (E15).

### Phase 4 — Assertion infrastructure and a real pass/fail signal

16. **`inc/assert.vh`** — rewrite for 1364-2005:
    - guard → `ASSERT_VH` (E8)
    - **parenthesize every macro parameter** (E7)
    - never put arguments inside string literals (E5); use `%b`/`%h`/`%0d` and pass values as
      `$display` arguments. Provide `assert_eq`, `assert_eq_hex`, `assert_eq_dec`;
      **delete `assert_eq_fmt`** — 1364-2005 has no stringify operator (`` `" `` is IEEE 1800),
      so it cannot be made to work as designed.
    - increment a shared `error_count` instead of `$finish`-ing on the first failure
    - tag failures `[ERROR]`, not `[INFO]`
17. **All 16 testbenches** end with
    `$display("RESULT: %0s", (error_count == 0) ? "PASS" : "FAIL"); $finish;`
    and the shared make rule fails the target unless `RESULT: PASS` appears (E6). Migrate the
    four `assert_eq_fmt` call sites. Fix `shift_reg_tb.v:37`'s 32-bit shift truncation and
    `sub_tb.v:4`'s missing `` `undef `` (E16).

*Verify:* deliberately break one assertion; `make` must exit non-zero.

### Phase 5 — ALU rewrite and header hygiene

18. **`inc/alu.vh`** — becomes the single source of truth for the ALU opcode encoding, **widened
    to 4 bits** for Phase 6 (D3):
    ```
    ALU_OP_ADD 4'b0000   ALU_OP_SLT  4'b0011   ALU_OP_SRL 4'b0110
    ALU_OP_SUB 4'b0001   ALU_OP_SLTU 4'b0100   ALU_OP_SRA 4'b0111
    ALU_OP_SLL 4'b0010   ALU_OP_XOR  4'b0101   ALU_OP_OR  4'b1000
                                                ALU_OP_AND 4'b1001
    ```
    Remove the unguarded defines from `arithmetic_logic_unit.v:3-8` (E9); both the ALU and
    `alu_decoder.v` include this header.
19. **`src/alu_mods/add.v`** — `` `include "alu.vh" `` **in the file itself**, and restructure to
    `` `ifdef CARRY_LOOKAHEAD_ADDER_IMPL … `else …rca… `endif `` so exactly one implementation
    always elaborates (B8). 1364-2005 has no `` `elsif ``. Wrap both loop-generates in
    `generate`/`endgenerate` (E3); derive `idx_end` from the width macro instead of `+3` (E14).
    Do the same for `sub.v`, which inherits the hazard.
20. **`src/arithmetic_logic_unit.v`** — instantiate `add` (carry_in = 0) and `sub`; mux the result
    combinationally per `operation_control_in`. Fix `slt`:
    `` result_out = {{`WIDTH-1{1'b0}}, ($signed(operand_a_in) < $signed(operand_b_in))}; `` (B4).
    Make `zero` a continuous `` assign zero = (result_int == {`WIDTH{1'b0}}); ``. Rename the port
    `zero` → `zero_out` for consistency. Add `overflow_out`.
21. **`src/alu_mods/overflow.v`** — re-cut the interface to *decoded control*:
    `operand_a_sign_in`, `operand_b_sign_in`, `result_sign_in`, `is_subtract_in`. This removes
    both the `ADDI`-immediate bug and the "overflow on AND/OR" bug at once, because the ALU only
    asserts `is_subtract_in` for genuine add/sub ops (E10). Keep the two verified sign rules.
    Instantiate inside the ALU.
22. **`src/alu_mods/sub.v`** — `borrow_out` → `carry_out` (B12); update `sub_tb.v:29` (which can
    then drop its `~`) and `AGENTS.md`.
23. **`inc/common.vh:4`** — remove `` `timescale `` (E1); pass it from `tests/mk/common.mk` or
    declare it per-testbench.

*Verify:* `single_cycle_cpu_tb` from Phase 3 still green after the ALU is swapped out.

### Phase 6 — Full RV32I branches and ALU ops *(depends on Phases 2 and 5)*

24. **`src/ctrl_unit_mods/alu_decoder.v`** — widen `opctrl_out` to `[3:0]`; keep `alu_op_in` at
    2 bits with a new meaning for `01`:
    - `alu_op = 00` → `ALU_OP_ADD` (lw/sw/jal)
    - `alu_op = 01` → **branch compare**, decoded from `funct3`: `000`/`001` → SUB;
      `100`/`101` → SLT; `110`/`111` → SLTU; `010`/`011` (reserved) → ADD
    - `alu_op = 10` → R-type / OP-IMM, all eight `funct3` decoded (D2):
      `000` → SUB if `op_in[5] && funct7_bit5_in` else ADD · `001` → SLL · `010` → SLT ·
      `011` → SLTU · `100` → XOR · `101` → **SRA if `funct7_bit5_in` else SRL** ·
      `110` → OR · `111` → AND.
      Note the asymmetry: `SUB` is gated on `op_in[5]` (there is no `SUBI`) but `SRA`/`SRAI`
      both use `instr[30]`, so `101` must **not** be gated on `op_in[5]`.
25. **`src/arithmetic_logic_unit.v`** — add `SLL`/`SRL`/`SRA`/`XOR`/`SLTU`. Shifts use
    `operand_b_in[4:0]` as the shift amount, which is correct for both R-type (`rs2[4:0]`) and
    the shift-immediates (I-type `imm[4:0]` = `instr[24:20]` = `shamt`). `SRA` is
    `` $signed(operand_a_in) >>> operand_b_in[4:0] `` (`>>>` is Verilog-2001, legal here).
    `SLTU` is the unsigned comparison the old `LT` accidentally implemented — now zero-extended
    to `32'd1`.
26. **`src/control_unit.v`** — replace `` assign pc_src_sel_out = (zero_in & br_int) | jmp_int; ``
    with a `funct3`-driven branch resolver (D1). It needs two ALU status inputs, `zero_in` and
    the ALU result LSB:
    ```
    BEQ  000 →  zero      BLT  100 →  alu_lsb      BLTU 110 →  alu_lsb
    BNE  001 → !zero      BGE  101 → !alu_lsb      BGEU 111 → !alu_lsb
    default  → 0
    assign pc_src_sel_out = (br_int & br_taken_int) | jmp_int;
    ```
    This **depends on both Phase 2 (zero must be combinational, C1) and Phase 5 (`slt` must
    return `1`, not all-ones, B4a)** — with the current ALU it would silently mis-branch.
27. **`src/single_cycle_cpu.v`** — route `alu_res_int[0]` into `control_unit`; widen `opctrl_int`
    to `[3:0]`.
28. **Extend `single_cycle_cpu_tb`** with all six branch forms (taken and not-taken), signed
    `slt`/`slti` edge cases (`-1 < 1`, `INT_MIN`, `INT_MAX`), `sltu` wrap cases, and the three
    shift-immediates including `srai` with a negative operand.

### Phase 7 — `mul`, CLA, docs, tooling

29. **`src/alu_mods/mul.v`** — merge the two processes into one
    `always @(posedge clk or negedge rstn)` (B9); clear `accumulator` and `counter` on `set`;
    register `operand_b_in` at `set`; fix the shift/add alignment and the 33rd-cycle second pass
    (B10); fix the `` 2*`WIDTH'b0 `` literal to `` {(2*`WIDTH){1'b0}} ``; move
    `` `define MUL_SHIFT_AND_ADD_IMPL `` into a guarded header (E9). `mul` stays out of the datapath.
30. **`src/alu_mods/mul_mods/shiftnadd_mod/shift_reg.v`** — nonblocking assignments throughout,
    single-process async-reset template covering `busy` and `counter`, `generate`/`endgenerate`
    around the loop (B11, E3).
31. **`src/alu_mods/add_mods/cla_mod/modified_full_adder.v:8`** — `p_out = a_in | b_in;` (B13).
    This is the change that makes the CLA an actual carry-lookahead adder. Re-run all three CLA
    testbenches exhaustively; they must stay green (the current outputs are already numerically
    correct, so this is a pure structural fix).
32. **Retire the style guide** (E18) — remove `verilog-style-guide.md` from `opencode.jsonc:12-14`
    and replace it with a short project-specific `STYLE.md` covering only 1364-2005-legal
    practice: `always @*` with default-before-`case`; nonblocking in clocked blocks and blocking
    in combinational ones; the canonical async-reset template; `generate`/`endgenerate` required;
    sized, well-formed literals; guarded headers only, never `` `define `` in a `.v`;
    `_in`/`_out` port suffixes. The lowRISC document may be retained only if moved to
    `docs/reference/` with a header noting it is SystemVerilog and non-normative.
33. **Fix `add_rca_impl_tb.v:28`** (`integer signed` → `integer`) and wrap
    `four_bit_lookahead_tb.v:20`'s generate loop (E4, E3).
34. **Remaining testbenches** (E15): `main_decoder`, `alu_decoder`, `branch_target`,
    `instruction_increment`, `mux21_32b`, `mux31_32b`, `mux21`, `overflow`. Wire all into `all:`,
    and add `mul_tb` to `alu_mods` `all:` (E17).
35. **`tools/slang/slang.f`** — add the `src/**/*.v` list; make the paths root-relative-safe (E22).
36. **`AGENTS.md`** — correct all nine drifts in E19.
37. **`README.md`** — overview, implemented ISA, prerequisites, build/test/lint commands,
    directory map, license (E20).
38. **CI** — a GitHub Actions workflow running `make lint` and the full test suite. Only
    meaningful *after* Phase 4, since before that a fully-failing suite exits 0 (E6).
39. **Windows Tcl flow parity** — bring `tools/tcl/` up to date with whatever Phases 0–7 changed
    on the Linux side (new/renamed testbenches, the widened ALU encoding, `mul_tb` inclusion,
    etc.), and document both flows side by side in `README.md` (Linux: `make`/`iverilog`, plus
    SystemVerilog/UVM where applicable; Windows: `tools/tcl/*.tcl`).

### Deliberately out of scope

`JALR`, `LUI`, `AUIPC` (`imm_src_sel` is 2 bits with no room for U-type — widening it is a
separate change), byte/halfword memory access (`lb`/`lh`/`sb`/`sh` — the memories have no byte
enables), the M extension in the datapath, and CSRs/traps. All currently fall through
`main_decoder`'s safe `default` and write nothing, which is the correct behavior for an
unimplemented encoding.

---

## Key files

`src/single_cycle_cpu.v` · `src/arithmetic_logic_unit.v` · `src/control_unit.v` ·
`src/ctrl_unit_mods/{main_decoder,alu_decoder}.v` · `src/instruction_memory.v` ·
`src/program_counter.v` · `src/instruction_increment.v` · `src/alu_mods/{add,sub,mul,overflow}.v` ·
`src/alu_mods/add_mods/cla_mod/modified_full_adder.v` ·
`src/alu_mods/mul_mods/shiftnadd_mod/{shift_reg,d_flip_flop}.v` · `inc/{alu,assert,common}.vh` ·
**new** `tests/mk/common.mk` · **new** `tests/tb/single_cycle_cpu_tb.v` (+11 more TBs) ·
all 6 Makefiles · **new** `tools/tcl/{build,synth,test}.tcl` (Windows build/synth/test flow) ·
`opencode.jsonc` · **new** `STYLE.md` · `AGENTS.md` · `README.md` ·
`.gitignore` · `tools/slang/slang.f`

## Risks

- **Phase 6 depends on Phases 2 and 5.** Branch resolution reads `zero` and `alu_res[0]`; with
  the current latched `zero` and all-ones `slt` it would mis-branch silently. Do not reorder.
- **Port renames** (`borrow_out`→`carry_out`, `zero`→`zero_out`, `curr_plus_four_instr_out`→
  `pc_plus_four_out`, `opctrl` 3→4 bits) touch instantiation sites and testbenches together.
- **`assert.vh` migration** touches all 16 testbenches. Mechanical, but preserve each TB's
  semantics — several rely on `$finish` inside a loop for coverage.
- **Makefile refactor** must keep the documented target names working
  (`make -C tests/tb <name>_tb`, `all`, `view.%`).
- **CLA propagate fix** is structural, not numerical — the exhaustive TBs pass both before and
  after, so they cannot confirm the improvement. Confirm via Vivado's timing/logic-depth report,
  not via simulation.

## Verification

1. **`make lint`** — `iverilog -g2005 -Wall -Iinc -s single_cycle_cpu` over all of `src/**`
   elaborates with **zero** warnings. At review time: one malformed-literal warning plus a
   timescale warning for *every* module in the design.
2. **`make -C tests/tb all`** — succeeds, and **exits non-zero** when an assertion is deliberately
   broken. This gate does not exist today and is the single most important item in the plan.
3. **All suites** — `tests/tb/alu_mods`, `.../add_mods/rca_mod`, `.../add_mods/cla_mod`,
   `.../mul_mods/shiftnadd_mod` green, `mul_tb` included, VCDs in `tests/wf/` for every suite.
4. **`single_cycle_cpu_tb`** runs the hand-assembled program end-to-end and verifies register and
   memory state; after Phase 6 it covers all six branch forms and all ten ALU ops.
5. **Vivado synthesis** — Vivado 2026.1 is installed and licensed on the development machine
   (`vivado.log:2-3`). In `-mode tcl`: `read_verilog` the design,
   `synth_design -top single_cycle_cpu -part <part>`, then confirm `report_utilization` shows
   **zero LATCH primitives** and the log has no multiply-driven-net errors. **iverilog cannot
   detect latch inference**, so this is the only check that actually answers "is it
   synthesizable". Worth scripting as `make synth` and running from Phase 2 onward.
6. **Fresh-clone check** — `git clone` to a new directory and run `make lint && make -C tests/tb all`
   with no manual `mkdir`. This catches E17, which the current repo fails.
7. **Windows parity check** — from a fresh clone on Windows, run the `tools/tcl/` build, synth,
   and test scripts with no `make`/`iverilog` on `PATH`; confirm they report the same pass/fail
   set as the Linux `make -C tests/tb all` run (SystemVerilog/UVM testbenches excepted, since
   those don't run under `iverilog -g2005` on Linux either).

---

*Source review: 2026-08-26, against commit `4eb5844`. Supersedes
`.opencode/plans/refactor-plan-2026-08-25_13-51-59.md`.*
