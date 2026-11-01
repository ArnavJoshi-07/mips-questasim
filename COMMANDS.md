# Command Reference

Every command you can run in this project, what it does and how to use it.
Unless a section says otherwise, run commands from the repo root:

```bash
cd ~/projects/mips/mips-questasim
```

Tools: **Icarus Verilog** (`iverilog`, `vvp`) and **GTKWave** (`gtkwave`) by
default, or **QuestaSim** (`vlib`, `vlog`, `vsim`) when it is on your PATH.

---

## 1. Makefile (the quickest way)

| Command | What it does |
|---|---|
| `make test` | Compiles and runs every module's testbench, prints `PASS`/`FAIL` per module and a summary |
| `make test MOD=<folder>` | Runs only one module, e.g. `make test MOD=alu` |
| `make test MOD="alu dmem"` | Runs several chosen modules |
| `make gui MOD=<folder>` | Runs one module, then opens its waveform in GTKWave |
| `make clean` | Deletes build output: `test` binaries, `test.log`, `.vcd`, Questa files |
| `SIM=questa make test` | Same as `make test`, using QuestaSim instead of Icarus |
| `SIM=questa make gui MOD=<folder>` | Opens the module in the QuestaSim GUI with all signals added |

Each module writes its full output to `<folder>/test.log`:

```bash
cat mips_top/test.log          # full log of one module
grep -c PASS */test.log        # quick check that every module passed
```

A module passes when it compiles, prints a line starting with `PASS` and
prints no line starting with `FAIL`.

### Module folders you can pass as `MOD=`

| Folder | What it tests |
|---|---|
| `library` | Shared building blocks in `library.v` (gates, muxes, flip-flops, adders) |
| `alu` | 32-bit ALU |
| `alu_control` | ALU control (funct + ALUOp → ALU operation) |
| `control_unit` | Main control unit (opcode → control signals) |
| `reg_file` | 32 × 32-bit register file |
| `sign_extend` | 16 → 32-bit sign extension |
| `pc_reg` | Program counter register |
| `imem` | Instruction memory |
| `dmem` | Data memory |
| `if_id_reg` | IF/ID pipeline register (load/stall, flush) |
| `id_ex_reg` | ID/EX pipeline register |
| `ex_mem_reg` | EX/MEM pipeline register |
| `mem_wb_reg` | MEM/WB pipeline register |
| `forwarding_unit` | Forwarding unit (EX/MEM and MEM/WB → ALU inputs) |
| `hazard_unit` | Load-use hazard detection (stall) |
| `single_cycle` | Complete single-cycle processor running Fibonacci |
| `mips_top` | Complete 5-stage pipelined processor running Fibonacci |
| `flush_test` | Directed test of branch and jump flushing on `mips_top` |

---

## 2. Running a module by hand (Icarus)

Every module folder has an `exec_instructions.txt` with its three commands:
compile, run, view waveform. The Makefile reads its file list from there.

```bash
cd <folder>
iverilog -o test <files from exec_instructions.txt>   # compile into ./test
vvp test                                              # run the simulation
gtkwave tb_<name>.vcd                                 # open the waveform
cd ..
```

| Command / option | Usage |
|---|---|
| `iverilog -o test file1.v file2.v ...` | Compile the listed sources into an executable called `test` |
| `iverilog -g2005 -Wall ...` | Same, forcing Verilog-2005 and showing all warnings (what `make` uses) |
| `vvp test` | Run the compiled simulation |
| `vvp -n test` | Run it and exit at `$finish` instead of dropping into the interactive prompt |
| `vvp test +PROGRAM=<file.hex>` | Load a different program into instruction memory (processors only, see §3) |
| `vvp test +DATA=<file.hex>` | Preload data memory from a hex file |
| `gtkwave <file.vcd>` | Open a waveform dump |
| `gtkwave <file.vcd> <view.gtkw>` | Open a waveform with a saved view (signals, zoom, marker) |

Compile lines for each module (from that module's folder):

```bash
# library
iverilog -o test ../library.v tb_library.v
# alu
iverilog -o test ../library.v alu.v tb_alu.v
# alu_control
iverilog -o test alu_control.v tb_alu_control.v
# control_unit
iverilog -o test control_unit.v tb_control_unit.v
# reg_file
iverilog -o test ../library.v regfile.v tb_regfile.v
# sign_extend
iverilog -o test sign_extend.v tb_sign_extend.v
# pc_reg
iverilog -o test ../library.v pc_reg.v tb_pc_reg.v
# imem
iverilog -o test imem.v tb_imem.v
# dmem
iverilog -o test dmem.v tb_dmem.v
# if_id_reg / id_ex_reg / ex_mem_reg / mem_wb_reg
iverilog -o test ../library.v if_id_reg.v tb_if_id_reg.v
iverilog -o test ../library.v id_ex_reg.v tb_id_ex_reg.v
iverilog -o test ../library.v ex_mem_reg.v tb_ex_mem_reg.v
iverilog -o test ../library.v mem_wb_reg.v tb_mem_wb_reg.v
# forwarding_unit
iverilog -o test forwarding_unit.v tb_forwarding_unit.v
# hazard_unit
iverilog -o test hazard_unit.v tb_hazard_unit.v
# single_cycle
iverilog -o test ../library.v ../pc_reg/pc_reg.v ../imem/imem.v ../control_unit/control_unit.v ../alu_control/alu_control.v ../reg_file/regfile.v ../sign_extend/sign_extend.v ../alu/alu.v ../dmem/dmem.v mips_single.v tb_mips_single.v
# mips_top
iverilog -o test ../library.v ../pc_reg/pc_reg.v ../imem/imem.v ../control_unit/control_unit.v ../alu_control/alu_control.v ../reg_file/regfile.v ../sign_extend/sign_extend.v ../alu/alu.v ../dmem/dmem.v ../if_id_reg/if_id_reg.v ../id_ex_reg/id_ex_reg.v ../ex_mem_reg/ex_mem_reg.v ../mem_wb_reg/mem_wb_reg.v ../forwarding_unit/forwarding_unit.v ../hazard_unit/hazard_unit.v mips_top.v tb_mips_top.v
# flush_test
iverilog -o test ../library.v ../pc_reg/pc_reg.v ../imem/imem.v ../control_unit/control_unit.v ../alu_control/alu_control.v ../reg_file/regfile.v ../sign_extend/sign_extend.v ../alu/alu.v ../dmem/dmem.v ../if_id_reg/if_id_reg.v ../id_ex_reg/id_ex_reg.v ../ex_mem_reg/ex_mem_reg.v ../mem_wb_reg/mem_wb_reg.v ../forwarding_unit/forwarding_unit.v ../hazard_unit/hazard_unit.v ../mips_top/mips_top.v tb_flush_test.v
```

---

## 3. Running programs on the processors

Programs live in `programs/`: the `.asm` is the readable source, the `.hex`
is what gets loaded (one instruction word per line, with comments).

| Program | What it is for |
|---|---|
| `fibonacci.hex` | Plain Fibonacci, no hazard padding. Runs on the single-cycle core and on the pipeline (stalls + flushes) |
| `fibonacci_nops.hex` | Padded with nops for every hazard: works on a pipeline with no forwarding |
| `fibonacci_fwd.hex` | Only the nops forwarding can't remove (load-use + branch/jump delay slots) |
| `fibonacci_stall.hex` | Like `_fwd` but without the load-use nop: the hazard unit stalls instead |
| `flush_test.hex` | Directed test of branch/jump flushing, run by `flush_test/` |

All of them leave F(0)..F(11) in dmem words 0..11 and `$v0 = 89`.

### Single-cycle processor

```bash
cd single_cycle
vvp -n test                                         # default: fibonacci.hex
vvp -n test +PROGRAM=../programs/fibonacci.hex      # same, explicitly
vvp -n test | grep -E 'v0|mem\[|CPI|PASS|FAIL'      # only the interesting lines
gtkwave tb_mips_single.vcd
cd ..
```

Expected: `cycles=90 instructions=90 CPI=1.00`, `PASS`.

### Pipelined processor (`mips_top`)

Build it once with `make test MOD=mips_top` (or the compile line above), then:

```bash
cd mips_top
vvp -n test                                              # default: fibonacci_fwd.hex
vvp -n test +PROGRAM=../programs/fibonacci_nops.hex
vvp -n test +PROGRAM=../programs/fibonacci_fwd.hex
vvp -n test +PROGRAM=../programs/fibonacci_stall.hex
vvp -n test +PROGRAM=../programs/fibonacci.hex
cd ..
```

Current results:

| Program | Cycles | CPI | Stalls | Result |
|---|---|---|---|---|
| `fibonacci_nops.hex` | 168 | 1.86 | 0 | PASS |
| `fibonacci_fwd.hex` (default) | 136 | 1.51 | 0 | PASS |
| `fibonacci_stall.hex` | 136 | 1.51 | 10 | PASS |
| `fibonacci.hex` | 116 | 1.28 | 10 | PASS (1 beq flush, 12 j flushes; no nops needed) |

The delay-slot nops in the first three programs are now flushed rather than
executed, so their results and cycle counts are unchanged.

Each line of the trace shows `PC:instruction` in every stage, then what
happened that cycle:

| Tag at end of line | Meaning |
|---|---|
| `$t0 <= 5` | Register written in WB |
| `mem[...] <= 5` | Word stored in MEM |
| `beq taken -> ..., FLUSH IF/ID+ID/EX` | Branch taken in EX; the 2 instructions behind it become bubbles |
| `j -> ..., FLUSH IF/ID` | Jump in ID; the instruction behind it becomes a bubble |
| `A<-EX/MEM`, `A<-MEM/WB`, `B<-...` | That ALU operand was forwarded |
| `STALL (load-use)` | Hazard unit stalled this cycle; a bubble (`00:nop`) appears in EX next cycle |

Filters:

```bash
vvp -n test +PROGRAM=../programs/fibonacci_stall.hex | grep STALL          # every stall
vvp -n test +PROGRAM=../programs/fibonacci_stall.hex | grep -A2 STALL      # stall + the 2 cycles after it
vvp -n test +PROGRAM=../programs/fibonacci_nops.hex  | grep -E 'cycles=|PASS|FAIL'
```

### Seeing the load-use stall in the waveform

```bash
cd mips_top
vvp -n test +PROGRAM=../programs/fibonacci_stall.hex
gtkwave tb_mips_top.vcd load_use_stall.gtkw
```

`load_use_stall.gtkw` opens on the first stall (t = 150, cycle 15) with the
signals grouped by stage: `STALL` high, `load_if` low, `pc_if`/`instr_id`
held, a `00000000` bubble in `instr_ex`, then `forward_a_ex = 01` when the
`add` reaches EX.

**Run the `vvp` step first.** `make test` reruns the default program and
overwrites `tb_mips_top.vcd`, which then has no stalls in it.

### Branch and jump flushing (`flush_test`)

```bash
make test MOD=flush_test                 # build + run, PASS/FAIL
cd flush_test
vvp -n test                              # trace of programs/flush_test.hex
vvp -n test | grep -E 'FLUSH|STALL'      # only the cycles that stall or flush
gtkwave tb_flush_test.vcd flush.gtkw     # waveform view of the flushes
cd ..
```

Expected: `cycles=32 stalls=2 beq flushes=3 j flushes=2`, `$s6 = 6`,
`$s7 = 0`, `PASS`. `flush.gtkw` opens on cycle 6 (t = 60), where the taken
`beq` of case A raises `FLUSH_IF_ID` and `FLUSH_ID_EX`. At t = 220 (cycle 22)
the `j` of case E stalls behind a `lw`: `stall` is high and `jump_flush` stays
low, so the `j` waits and flushes one cycle later.

---

## 4. QuestaSim

Through the Makefile: `SIM=questa make test`, `SIM=questa make gui MOD=<folder>`.

By hand, from a module folder (example: the pipeline):

```bash
cd mips_top
vlib work                                          # create the work library
vlog -work work <files from exec_instructions.txt> # compile
vsim -c work.tb -do "run -all; quit -f"            # run in the console
vsim -c work.tb -do "run -all; quit -f" +PROGRAM=../programs/fibonacci_stall.hex
vsim -gui work.tb -do "add wave -r /*; run -all"   # run with waveforms
cd ..
```

| Command | Usage |
|---|---|
| `vlib work` | Create the `work` library (once per folder) |
| `vlog file1.v file2.v ...` | Compile sources into `work` |
| `vsim -c work.tb -do "..."` | Run the testbench top `tb` in console mode |
| `vsim -gui work.tb -do "..."` | Run in the GUI |
| `+PROGRAM=...` / `+DATA=...` | Same plusargs as with `vvp` |

Useful commands in the Questa GUI transcript:

```tcl
add wave /tb/clk /tb/pc /tb/instr          # add chosen signals
add wave -radix unsigned /tb/dut/*         # all DUT signals as unsigned
add wave /tb/dut/stall /tb/dut/flush_id_ex # the hazard signals
restart -f                                 # restart the simulation
run -all                                   # run to $finish
wave zoom full                             # fit the whole run in the window
```

---

## 5. Looking around the project

```bash
cat programs/fibonacci_stall.asm         # read a program
cat programs/fibonacci_stall.hex         # its machine code
cat mips_top/mips_top.v                  # pipelined datapath
cat single_cycle/mips_single.v           # single-cycle datapath
cat library.v                            # shared building blocks
tree -I 'work|*.vcd|test|test.log'       # project layout (or: ls -R)
git log --oneline                        # build-up history
```

---

## 6. Cleaning up

```bash
make clean                               # removes test, test.log, *.vcd, Questa files
```
