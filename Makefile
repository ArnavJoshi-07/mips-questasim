# Runs the testbench in every module folder that has an exec_instructions.txt.
# The files to compile are taken from the "iverilog -o test ..." line of that
# file, so exec_instructions.txt stays the single list of sources per module.
#
#   make test                 run every module's testbench
#   make test MOD=alu         run only alu/
#   make gui  MOD=alu         run one module and open its waveform
#   make clean                remove build output
#   SIM=questa make test      same targets using QuestaSim
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

.PHONY: test gui clean

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
	rm -rf */work
