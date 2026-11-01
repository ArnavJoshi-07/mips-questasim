# Runs the testbench in every module folder that has an exec_instructions.txt.
# The files to compile are taken from the "iverilog -o test ..." line of that
# file, so exec_instructions.txt stays the single list of sources per module.
#
#   make test                 run every module's testbench
#   make test MOD=alu         run only alu/
#   make gui  MOD=alu         run one module and open its waveform
#   make clean                remove build output
#   SIM=questa make test      same targets using QuestaSim
#
# Program suite (tests/tb_suite.v, every programs/*.asm on both cores):
#   make programs             assemble programs/*.asm into .hex and .expect
#   make suite                run every program, PASS/FAIL per program
#   make suite TESTS=branches run only programs/branches.asm
#   make coverage             run the suite and write docs/coverage.md
#   SIM=questa make coverage  same, plus QuestaSim code coverage (UCDB + HTML)
SIM ?= iverilog

MODULES := $(patsubst %/exec_instructions.txt,%,$(wildcard */exec_instructions.txt))
MOD     ?= $(MODULES)

# Shell snippet that sets $files from the module's exec_instructions.txt
FILES = files=$$(sed -n 's/^iverilog -o test //p' exec_instructions.txt)

ifeq ($(SIM),iverilog)
  COMPILE = iverilog -g2005 -Wall -o test $$files
  RUN     = vvp -n test
  GUI     = gtkwave *.vcd
else ifeq ($(SIM),questa)
  COMPILE = vlib work >/dev/null; vlog -work work $$files
  RUN     = vsim -c work.tb -do "run -all; quit -f"
  GUI     = vsim -gui work.tb -do "add wave -r /*; run -all"
else
  $(error SIM must be iverilog or questa, got '$(SIM)')
endif

.PHONY: test gui clean programs suite coverage

# A module passes when it compiles, prints a line starting with PASS and
# prints no line starting with FAIL. Questa prefixes output with "# ".
test:
	@pass=0; fail=0; \
	for m in $(MOD); do \
	  log=$$m/test.log; \
	  if (cd $$m && $(FILES) && $(COMPILE) && $(RUN)) > $$log 2>&1 \
	     && grep -Eq '^(# )?PASS' $$log && ! grep -Eq '^(# )?FAIL' $$log; then \
	    echo "  PASS  $$m"; pass=$$((pass+1)); \
	  else \
	    echo "  FAIL  $$m   (see $$log)"; fail=$$((fail+1)); \
	  fi; \
	done; \
	echo "$$pass passed, $$fail failed"; \
	[ $$fail -eq 0 ]

gui:
	@[ "$(words $(MOD))" = 1 ] || { echo "Pick one module: make gui MOD=<folder>"; exit 1; }
	@$(MAKE) -s --no-print-directory test MOD=$(MOD)
	cd $(MOD) && $(GUI)

clean:
	rm -f */test */test.log */*.vcd */*.wlf */transcript */modelsim.ini
	rm -rf */work tests/build


# ---------------------------------------------------------------- suite
# Both cores are compiled into one testbench. Every program runs from the
# repo root, so the paths below are relative to it.
SUITE_SRCS := library.v pc_reg/pc_reg.v imem/imem.v control_unit/control_unit.v \
              alu_control/alu_control.v reg_file/regfile.v sign_extend/sign_extend.v \
              alu/alu.v dmem/dmem.v if_id_reg/if_id_reg.v id_ex_reg/id_ex_reg.v \
              ex_mem_reg/ex_mem_reg.v mem_wb_reg/mem_wb_reg.v \
              forwarding_unit/forwarding_unit.v hazard_unit/hazard_unit.v \
              mips_top/mips_top.v single_cycle/mips_single.v
SUITE_TB := tests/tb_suite.v
PROGRAMS := $(sort $(basename $(notdir $(wildcard programs/*.asm))))
TESTS    ?= $(PROGRAMS)
BUILD    := tests/build

# Programs run in parallel with Icarus; one at a time with Questa, which may
# have a single licence.
ifeq ($(SIM),iverilog)
  JOBS          ?= $(shell nproc 2>/dev/null || echo 1)
  SUITE_COMPILE = iverilog -g2005 -Wall -o $(BUILD)/suite $(SUITE_SRCS) $(SUITE_TB)
else
  JOBS          ?= 1
  # Code coverage on the design only (statement, branch, condition,
  # expression, toggle), not on the testbench
  SUITE_COMPILE = vlib $(BUILD)/work >/dev/null && \
                  vlog -work $(BUILD)/work +cover=bcest $(SUITE_SRCS) && \
                  vlog -work $(BUILD)/work $(SUITE_TB)
endif

programs:
	@python3 programs/asm.py $(wildcard programs/*.asm)

suite: programs
	@mkdir -p $(BUILD)
	@$(SUITE_COMPILE) > $(BUILD)/compile.log 2>&1 || { cat $(BUILD)/compile.log; exit 1; }
	@tests/run_suite.sh $(SIM) $(JOBS) $(TESTS)

coverage:
	@$(MAKE) -s --no-print-directory suite TESTS="$(PROGRAMS)"
	@python3 tests/coverage_report.py $(BUILD)/cov $(PROGRAMS) > docs/coverage.md
	@echo "Functional coverage: docs/coverage.md ($$(grep -m1 -o '[0-9]* of [0-9]* bins' docs/coverage.md))"
ifeq ($(SIM),questa)
	@vcover merge $(BUILD)/merged.ucdb $(addprefix $(BUILD)/ucdb/,$(addsuffix .ucdb,$(PROGRAMS)))
	@vcover report -summary $(BUILD)/merged.ucdb | tee $(BUILD)/code_coverage.txt
	@vcover report -details -output $(BUILD)/code_coverage_details.txt $(BUILD)/merged.ucdb
	@vcover report -html -output $(BUILD)/coverage_html $(BUILD)/merged.ucdb
	@echo "Code coverage: $(BUILD)/code_coverage.txt, $(BUILD)/coverage_html/index.html"
endif
