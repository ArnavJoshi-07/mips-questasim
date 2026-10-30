# Simulator: iverilog (default, runs locally) or questa (lab machines)
#   make test                 run every unit testbench
#   make test TB=alu          run only tb/tb_alu.v
#   make gui  TB=alu          run one testbench and open its waveform
#   make clean                remove build output
#   SIM=questa make test      same targets using QuestaSim
SIM   ?= iverilog
BUILD := build

RTL   := $(wildcard rtl/*.v)
# Unit testbenches: every tb/tb_<name>.v except the system-level tb_mips.v
UNIT  := $(filter-out mips,$(patsubst tb/tb_%.v,%,$(wildcard tb/tb_*.v)))
TB    ?= $(UNIT)

ifeq ($(SIM),iverilog)
  COMPILE = iverilog -g2005 -Wall -s tb_$(T) -o $(BUILD)/tb_$(T).vvp $(RTL) tb/tb_$(T).v
  RUN     = vvp -n $(BUILD)/tb_$(T).vvp
  GUI     = gtkwave $(BUILD)/tb_$(TB).vcd
else ifeq ($(SIM),questa)
  COMPILE = vlib $(BUILD)/work >/dev/null; vlog -work $(BUILD)/work $(RTL) tb/tb_$(T).v
  RUN     = vsim -c -work $(BUILD)/work tb_$(T) -do "run -all; quit -f"
  GUI     = vsim -gui -work $(BUILD)/work tb_$(TB) -do "add wave -r /*; run -all"
else
  $(error SIM must be iverilog or questa, got '$(SIM)')
endif

.PHONY: test gui clean run-one

# A testbench passes when it compiles, prints a line starting with PASS
# and prints no line starting with FAIL. Questa prefixes output with "# ".
test:
	@mkdir -p $(BUILD)
	@pass=0; fail=0; \
	for t in $(TB); do \
	  log=$(BUILD)/tb_$$t.log; \
	  if $(MAKE) -s --no-print-directory run-one T=$$t > $$log 2>&1 \
	     && grep -Eq '^(# )?PASS' $$log && ! grep -Eq '^(# )?FAIL' $$log; then \
	    echo "  PASS  $$t"; pass=$$((pass+1)); \
	  else \
	    echo "  FAIL  $$t   (see $$log)"; fail=$$((fail+1)); \
	  fi; \
	done; \
	echo "$$pass passed, $$fail failed"; \
	[ $$fail -eq 0 ]

run-one:
	$(COMPILE)
	$(RUN)

gui:
	@[ "$(words $(TB))" = 1 ] || { echo "Pick one testbench: make gui TB=<name>"; exit 1; }
	@$(MAKE) -s --no-print-directory test TB=$(TB)
	$(GUI)

clean:
	rm -rf $(BUILD) work transcript modelsim.ini *.wlf *.vcd *.vvp
