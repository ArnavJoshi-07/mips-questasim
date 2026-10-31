# Pipelined MIPS Processor in Verilog

A five-stage pipelined implementation of a 32-bit MIPS processor, written in Verilog (IEEE 1364-2005) and verified through simulation in **Siemens QuestaSim**.

The project follows the classic pipelined datapath described by Patterson and Hennessy in *Computer Organization and Design*. Instructions move through the **Fetch**, **Decode**, **Execute**, **Memory** and **Write-Back** stages concurrently. Dedicated hardware detects and resolves the data and control hazards that arise when instructions overlap.

---

## Table of Contents

- [Motivation](#motivation)
- [What Is a Pipelined Processor?](#what-is-a-pipelined-processor)
- [Architecture](#architecture)
- [Supported Instructions](#supported-instructions)
- [Hazard Handling](#hazard-handling)
- [Repository Structure](#repository-structure)
- [Getting Started](#getting-started)
- [Verification Strategy](#verification-strategy)
- [Project Status](#project-status)
- [References](#references)

---

## Motivation

A single-cycle processor completes each instruction in one long clock cycle, so most of its hardware sits idle at any given moment. Pipelining divides execution into shorter stages and lets a new instruction begin every cycle. Once the pipeline is full, the processor completes close to one instruction per cycle, and it can run at a much higher clock frequency.

The project has three aims:

1. To build a functionally correct, synthesizable-style RTL model of a pipelined MIPS core.
2. To show, through annotated simulation waveforms, how instructions overlap and how hazards are detected and resolved.
3. To check correctness with self-checking testbenches and to measure the cost of stalls and flushes in cycles per instruction (CPI).

## What Is a Pipelined Processor?

A pipeline works much like an assembly line. Each instruction passes through five stages, and every stage works on a different instruction in the same clock cycle:

```
Clock cycle:   1     2     3     4     5     6     7     8
            ┌─────┬─────┬─────┬─────┬─────┐
add         │ IF  │ ID  │ EX  │ MEM │ WB  │
            └─────┼─────┼─────┼─────┼─────┼─────┐
sub               │ IF  │ ID  │ EX  │ MEM │ WB  │
                  └─────┼─────┼─────┼─────┼─────┼─────┐
lw                      │ IF  │ ID  │ EX  │ MEM │ WB  │
                        └─────┼─────┼─────┼─────┼─────┼─────┐
sw                            │ IF  │ ID  │ EX  │ MEM │ WB  │
                              └─────┴─────┴─────┴─────┴─────┘
```

From cycle 5 onwards, all five stages are busy at once. Each instruction still takes five cycles from start to finish, but one instruction now completes every cycle.

## Architecture

```
      ┌──────┐   ┌───────┐   ┌──────┐   ┌────────┐   ┌──────┐   ┌────────┐   ┌──────┐   ┌────────┐   ┌──────┐
 PC ─►│  IF  │──►│ IF/ID │──►│  ID  │──►│ ID/EX  │──►│  EX  │──►│ EX/MEM │──►│ MEM  │──►│ MEM/WB │──►│  WB  │
      └──────┘   └───────┘   └──────┘   └────────┘   └──────┘   └────────┘   └──────┘   └────────┘   └──┬───┘
         ▲            ▲           ▲          ▲            ▲                                             │
         │   stall    │  flush    │          │ bubble     │ forward                                     │
         └──────┬─────┴───────────┘          │            │                                             │
         ┌──────┴──────────┐                 │      ┌─────┴────────────┐                                │
         │ Hazard Detection│─────────────────┘      │  Forwarding Unit │◄── EX/MEM, MEM/WB              │
         └─────────────────┘                        └──────────────────┘                                │
                                    ▲                                                                   │
                                    └──────────────────── register write-back ◄─────────────────────────┘
```

| Stage | Responsibility |
|-------|----------------|
| **IF**  — Instruction Fetch | Reads the instruction at the program counter and computes `PC + 4`. |
| **ID**  — Instruction Decode | Decodes the opcode, generates control signals, reads the register file and sign-extends the immediate. |
| **EX**  — Execute | Performs the ALU operation, or computes the effective address for a load or store, and evaluates branch conditions. |
| **MEM** — Memory Access | Reads from or writes to data memory for `lw` and `sw`. Other instructions pass through unchanged. |
| **WB**  — Write-Back | Writes the ALU result or the loaded value into the destination register. |

### Design Decisions

- **Harvard memory organisation.** Separate instruction and data memories remove the structural hazard between IF and MEM.
- **Write-first register file.** The register file writes on the falling clock edge, so a value written in WB can be read in ID during the same cycle.
- **Control signals travel with the data.** Each pipeline register carries the control bits its instruction still needs in later stages.
- **Register `$zero` is hard-wired to 0.** Writes to it are ignored, and it is never used as a forwarding source.

## Supported Instructions

| Format | Instructions |
|--------|--------------|
| **R-type** | `add`, `sub`, `and`, `or`, `slt` |
| **I-type** | `addi`, `lw`, `sw`, `beq` |
| **J-type** | `j` |
| *Planned extensions* | `andi`, `ori`, `slti`, `lui`, `bne`, `nor`, `sll`, `srl`, `jal`, `jr` |

## Hazard Handling

Overlapping instructions can interfere with one another. The processor handles each class of hazard as follows.

### Data Hazards — Forwarding

When an instruction needs a result that an earlier instruction has computed but not yet written back, the **forwarding unit** sends that value straight from the EX/MEM or MEM/WB pipeline register to the ALU inputs. If both registers hold a matching result, the newer one takes priority.

```asm
add  $t0, $t1, $t2     # $t0 produced in EX
sub  $t3, $t0, $t4     # $t0 forwarded from EX/MEM — no stall
and  $t5, $t0, $t6     # $t0 forwarded from MEM/WB — no stall
```

### Load-Use Hazards — Stalling

A loaded value is not available until the end of the MEM stage, so forwarding alone cannot supply it to the instruction immediately after the load. The **hazard detection unit** therefore:

1. freezes the PC and the IF/ID register, and
2. inserts a bubble into ID/EX by clearing its control signals.

This costs exactly one cycle.

```asm
lw   $t0, 0($s0)
add  $t1, $t0, $t2     # stalled for one cycle, then forwarded from MEM/WB
```

### Control Hazards — Flushing

The processor assumes that branches are **not taken** and keeps fetching sequentially. If a branch turns out to be taken, the instructions fetched in the meantime are **flushed**: they are turned into no-ops, and the PC is redirected to the branch target, `PC + 4 + (imm << 2)`.

## Repository Structure

Every module lives in its own folder with its testbench and an `exec_instructions.txt` that lists the commands to build and run it. Shared building blocks (multiplexers, demultiplexers, flip-flops, the full adder and the 32-bit adder) live in `library.v` at the root, and `library/` tests them.

```
mips-questasim/
├── library.v               # mux2/4/8, demux2/4/8, df, dfr, dfrl, fa,
│                           #   adder32, mux2_5/32, mux4_32, dfrl_32
├── library/                # Testbench for the word-wide library.v modules
├── pc_reg/                 # Program counter
├── imem/                   # Instruction memory
├── dmem/                   # Data memory
├── reg_file/               # 32 × 32-bit register file
├── control_unit/           # Main decoder
├── alu_control/            # ALU operation decoder
├── alu/                    # Arithmetic logic unit
│   ├── alu.v               #   design
│   ├── tb_alu.v            #   testbench (module tb)
│   └── exec_instructions.txt
├── sign_extend/            # Immediate sign extension
├── if_id_reg/              # IF/ID pipeline register
├── id_ex_reg/              # ID/EX pipeline register
├── ex_mem_reg/             # EX/MEM pipeline register
├── mem_wb_reg/             # MEM/WB pipeline register
├── forwarding_unit/        # Data-hazard forwarding logic
├── hazard_unit/            # Load-use stall and flush logic
├── mips_top/               # Top-level pipelined processor
├── programs/               # MIPS assembly tests and their .hex images
├── docs/                   # Diagrams, waveform captures and report
└── Makefile                # Runs every module's testbench at once
```

## Getting Started

### Prerequisites

- **Siemens QuestaSim** (or ModelSim) with Verilog-2005 support
- *Optional:* **Icarus Verilog** (`iverilog -g2005`) for quick command-line runs without a Questa licence
- *Optional:* a MIPS assembler, such as MARS, for producing new `.hex` program images

### Running One Module

Each folder's `exec_instructions.txt` holds the exact commands. For example, for the ALU with Icarus Verilog:

```bash
cd alu
iverilog -o test ../library.v alu.v tb_alu.v
vvp test
gtkwave tb_alu.vcd
```

And in QuestaSim:

```tcl
vlib work
vlog ../library.v alu.v tb_alu.v
vsim work.tb
add wave -r /*
run -all
```

### Running Every Module

The Makefile reads the source list from each folder's `exec_instructions.txt` and runs all the testbenches:

```bash
make test               # Run every module's testbench with a pass/fail summary
make test MOD=alu       # Run only alu/
make gui  MOD=alu       # Run one module and open its waveform
make clean              # Remove generated simulation artefacts
```

The Makefile uses Icarus Verilog by default. Prefix any target with `SIM=questa` to run it in QuestaSim instead, e.g. `SIM=questa make test`.

### Loading a Different Program

Instruction memory is initialised with `$readmemh`. To run another program, assemble it to a hex file of 32-bit words and pass the file to the simulator:

```bash
vvp test +PROGRAM=../programs/fibonacci.hex
```

Data memory starts at zero. A program that needs preloaded data can supply a second hex file with `+DATA=<file>.hex`.

`programs/fibonacci.asm` is the demo program. It writes the first 12 Fibonacci numbers (0 to 89) to data memory and leaves 89 in `$v0`. Each loop iteration includes a load-use stall, a forwarded result and a taken jump.

## Verification Strategy

Verification runs at two levels.

**Unit tests.** Each building block (ALU, register file, control unit, forwarding unit and hazard unit) has its own testbench that checks its expected behaviour exhaustively or through directed tests.

**System tests.** The top-level testbench loads a program, runs it until it reaches a halt condition, and compares the final register file and data memory against known-good values. It reports a clear **PASS** or **FAIL**. The test suite covers:

| Test Program | Purpose |
|--------------|---------|
| `alu_ops`       | Every arithmetic and logical instruction |
| `load_store`    | Word-aligned loads and stores |
| `forwarding`    | EX/MEM and MEM/WB forwarding, including double hazards |
| `load_use`      | Correct one-cycle stall insertion |
| `branches`      | Taken and not-taken branches, with pipeline flushes |
| `fibonacci`     | An end-to-end program combining all of the above |
| `bubble_sort`   | Heavy memory traffic and tight loop branching |

Code coverage is collected through QuestaSim's built-in coverage engine. For each program, the number of cycles and retired instructions is reported so that CPI can be measured.

## Project Status

| Milestone | Status |
|-----------|--------|
| Datapath components and unit tests | ☑ Done |
| Single-cycle reference implementation | ☐ Planned |
| Five-stage pipeline (hazard-free programs) | ☐ Planned |
| Forwarding unit | ☐ Planned |
| Load-use stall detection | ☐ Planned |
| Branch and jump handling with flushing | ☐ Planned |
| Full test suite and coverage report | ☐ Planned |
| Documentation and waveform analysis | ☐ Planned |

## References

- D. A. Patterson and J. L. Hennessy, *Computer Organization and Design: The Hardware/Software Interface*, MIPS Edition — Chapter 4, "The Processor".
- D. M. Harris and S. L. Harris, *Digital Design and Computer Architecture* — Chapter 7, "Microarchitecture".
- MIPS Technologies, *MIPS32 Architecture for Programmers, Volume II: The MIPS32 Instruction Set*.
