#!/usr/bin/env bash
# Runs programs on tests/tb_suite.v (both cores) and prints PASS/FAIL for
# each, with the same rule as "make test": a run passes when it prints a
# line starting with PASS and none starting with FAIL. Called by the
# Makefile ("make suite"), which compiles the testbench first.
#
#   tests/run_suite.sh <sim> <jobs> <program> [...]
#
# <sim> is iverilog or questa; <jobs> is how many programs run at once.
# Run from the repo root. Logs go to tests/build/<program>.log, coverage
# counts to tests/build/cov/<program>.txt and, with Questa, code coverage
# to tests/build/ucdb/<program>.ucdb.
set -u
sim=$1 jobs=$2
shift 2
build=tests/build
mkdir -p "$build/cov" "$build/ucdb"

run_one() {
    local t=$1
    local args=(+PROGRAM=programs/$t.hex +EXPECT=programs/$t.expect +COV=$build/cov/$t.txt)
    [ -f "programs/${t}_data.hex" ] && args+=(+DATA=programs/${t}_data.hex)
    if [ "$sim" = questa ]; then
        vsim -c -coverage -lib "$build/work" tb "${args[@]}" \
             -do "coverage save -onexit $build/ucdb/$t.ucdb; run -all; quit -f"
    else
        vvp -n "$build/suite" "${args[@]}"
    fi > "$build/$t.log" 2>&1
}

# Start up to $jobs runs at a time
running=0
for t in "$@"; do
    run_one "$t" &
    running=$((running + 1))
    if [ "$running" -ge "$jobs" ]; then
        wait -n
        running=$((running - 1))
    fi
done
wait

pass=0 fail=0
for t in "$@"; do
    log=$build/$t.log
    if grep -Eq '^(# )?PASS' "$log" && ! grep -Eq '^(# )?FAIL' "$log"; then
        printf '  PASS  %-16s %s\n' "$t" "$(grep -Eo 'cycles=[0-9]+ retired=[0-9]+ CPI=[0-9.]+' "$log")"
        pass=$((pass + 1))
    else
        echo "  FAIL  $t   (see $log)"
        fail=$((fail + 1))
    fi
done
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
