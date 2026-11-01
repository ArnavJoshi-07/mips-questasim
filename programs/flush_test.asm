# Directed test of branch and jump flushing on the pipeline (flush_test/).
#
# Every instruction on a wrong path adds to $s7, and every instruction on
# the right path adds 1 to $s6. If flushing works, the run ends with
# $s6 = 6 and $s7 = 0. An instruction that should have been squashed but
# ran shows up as $s7 != 0; a lost right-path instruction as $s6 < 6.
#
#   A  taken beq           both instructions behind it are flushed
#                          (IF/ID and ID/EX), 2 cycles lost
#   B  not-taken beq       nothing is flushed, the fall-through runs
#   C  j                   the instruction behind it is flushed (IF/ID)
#   D  lw -> beq           load-use stall on the beq, then a taken branch
#   E  lw $s0 -> j         the hazard unit stalls on the j: its address bits
#                          20:16 (taken as rt) are 16 = $s0. The j must
#                          survive the stall and jump a cycle later, not
#                          flush itself out of IF/ID
#   F  taken beq + j       the beq in EX and a j in ID in the same cycle:
#                          the branch wins and the j is squashed with the
#                          rest
#
# For E, the jump target is 0x00400058 rather than 0x58. imem ignores the
# address bits above bit 9, so both are the same word, but the high address
# sets bit 20 of the j's address field. (0x00400000 is where MARS and SPIM
# place .text, so with their addressing every j has rt = $s0.) From case F
# on, the PC runs at 0x004000xx, so the halt jumps to 0x00400070.
#
# Expected: $s6 = 6, $s7 = 0, $t3 = 5, $s0 = 5, dmem word 0 = 5,
#           2 load-use stalls (D, E)

        addi $t0, $zero, 5
        addi $t1, $zero, 5
        addi $t2, $zero, 7
        beq  $t0, $t1, caseB    # A: taken
        addi $s7, $s7, 1        #    in ID when the beq is in EX: flushed
        addi $s7, $s7, 1        #    in IF when the beq is in EX: flushed
        addi $s7, $s7, 1        #    never fetched
caseB:  addi $s6, $s6, 1        # 1
        beq  $t0, $t2, bad      # B: not taken
        addi $s6, $s6, 1        # 2  must run
        j    caseD              # C
        addi $s7, $s7, 1        #    in IF when the j is in ID: flushed
caseD:  addi $s6, $s6, 1        # 3
        sw   $t0, 0($zero)      #    dmem word 0 = 5
        lw   $t3, 0($zero)      # D
        beq  $t3, $t1, caseE    #    load-use stall, then taken
        addi $s7, $s7, 1
        addi $s7, $s7, 1
caseE:  addi $s6, $s6, 1        # 4
        lw   $s0, 0($zero)      # E
        j    0x00400058         #    = caseF; stalled, then jumps
        addi $s7, $s7, 1
caseF:  addi $s6, $s6, 1        # 5
        beq  $zero, $zero, done # F: taken, and resolved while...
        j    bad                #    ...this j is in ID: squashed
        addi $s7, $s7, 1
        addi $s7, $s7, 1
done:   addi $s6, $s6, 1        # 6
halt:   j    0x00400070         # j to itself; the testbench stops when it reaches WB

bad:    addi $s7, $s7, 100      # only reached if a branch or j goes wrong
        j    0x00400070

# expect $s6 = 6
# expect $s7 = 0
# expect $t3 = 5
# expect $s0 = 5
# expect mem[0] = 5
# expect stalls = 2
# expect beq_flushes = 3
# expect j_flushes = 4          # C, E and 2 by the halt
# 18 right-path instructions + 4 to fill + 2 stalls + 3 x 2 for the beqs
# + 2 x 1 for the j's:
# expect cycles = 32
