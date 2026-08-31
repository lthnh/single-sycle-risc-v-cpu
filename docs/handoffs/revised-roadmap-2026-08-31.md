# Handoff: Single-Cycle RISC-V CPU Roadmap

## Current State

The repository was inspected and its refactor roadmap was rewritten. The working branch was `main`
at `c68e105`, synchronized with `origin/main` before this session's uncommitted documentation edits.

Current working-tree changes:

- Modified: `AGENTS.md`
- Modified: `.opencode/plans/claude-refactor-plan-2026-08-26_11-12-20.md`
- Untracked planning artifact: `.opencode/plans/1788162502322-quick-wolf.md`

Do not discard these changes. No source RTL, tests, build scripts, or configuration were modified.
No commit was requested or created.

## Decisions Made

- Vivado tools driven by version-controlled Tcl scripts are the sole future compile, simulation,
  and synthesis flow.
- Do not add or maintain an Icarus Verilog/Make flow.
- Vivado Tcl infrastructure belongs in `tools/tcl/`, resolves paths from script location, and uses
  one deterministic source manifest across compile, simulation, synthesis, CI, and tooling.
- The unused overflow detector is to be repaired, tested, and integrated into the ALU as a status
  output, not used as an architectural RV32I trap.
- The roadmap was fully rewritten rather than annotated.
- Linux and Windows should ultimately use the same Vivado Tcl flow and source/test inventory.

## Authoritative Artifacts

- Revised roadmap: `.opencode/plans/claude-refactor-plan-2026-08-26_11-12-20.md`
- Approved rewrite plan and rationale: `.opencode/plans/1788162502322-quick-wolf.md`
- Updated repository instructions: `AGENTS.md`, especially `Build & Simulation`
- Historical superseded roadmap: `.opencode/plans/refactor-plan-2026-08-25_13-51-59.md`

Read these artifacts rather than reconstructing or duplicating their milestone details.

## Verification Already Performed

- `git diff --check` passed.
- Searches found no stale operational `make -C`, `iverilog`, `vvp`, placeholder FPGA part, fixed
  “all 16” test count, or “Full RV32I” wording in the revised roadmap or updated `AGENTS.md`.
- An independent review identified and prompted fixes for:
  - the known-broken multiplier conflicting with an earlier all-leaf-tests-green gate;
  - insufficient decoder inputs for reserved `funct7` validation;
  - `AGENTS.md` presenting planned Tcl infrastructure as already present;
  - stale assertion, multiplier-test, and subtraction-carry guidance.
- No simulations or synthesis were run because `tools/tcl/` does not yet exist and `AGENTS.md`
  now explicitly states there is no approved command until those scripts are committed.

## Suggested Next Step

Confirm the documentation diff still matches the user's intent. If implementation is requested,
start with Milestone 0 and Milestone 1 of the revised roadmap: freeze the behavioral/tool contract,
then establish the authoritative Vivado Tcl flow and trustworthy test result handling. Do not jump
to RTL repairs before the test harness can reliably report failures.

## Suggested Skills

- `implement-spec`: execute one approved roadmap milestone in code.
- `tdd`: build the Vivado simulation harness and later RTL repairs test-first.
- `code-review`: review each milestone against the roadmap and repository standards before handoff.
- `diagnosing-bugs`: investigate Vivado elaboration, simulation, or synthesis failures that arise.
- `unlazy`: use for a substantial milestone requiring explicit acceptance gates and exhaustive
  verification.
- `handoff`: create another compact continuation document if the next session ends mid-milestone.

## Constraints

- RTL and ordinary testbenches must remain IEEE 1364-2005 Verilog, except any separately approved
  UVM testbench.
- Synthesizable source files must not contain simulation-only constructs.
- Follow the repository's no-destructive-git and no-unrequested-commit rules.
- Preserve unrelated or concurrent worktree changes.
