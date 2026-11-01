# Directed test of branches and jumps. As in flush_test.asm, every right-
# path instruction adds 1 to $s6 and every wrong-path instruction adds to
# $s7, so a missed flush shows up as $s7 != 0 and a lost instruction as a
# low $s6.
#
#   A  counted loop            beq not taken 4 times, then taken to exit;
#                              j back to the top 4 times
#   B  backward taken beq      the target is behind the beq
#   C  beq to the next word    offset 0: taken, flushes the target itself
#                              out of IF/ID, then fetches it again
#   D  beq behind a beq        the first is taken, the second (in ID) is
#                              flushed and never resolves
#   E  not taken, then taken   two beqs in a row, only the second jumps
#   F  negative operands       -7 == -7, both forwarded
#   G  j behind a j            the second j is in IF when the first is in
#                              ID: it is flushed and never jumps
#   H  beq on 0x80000000 vs 0  differ only in bit 31: not taken
#
# Expected: $s6 = 9 + 5 (loop body) = 14 right-path marks, $s7 = 0,
#           $t1 = 15 (5 + 4 + 3 + 2 + 1)

        addi $t0, $zero, 5          # A: counter
        addi $t1, $zero, 0          #    sum
loop:   add  $t1, $t1, $t0
        addi $s6, $s6, 1            # 1 per iteration: 5
        addi $t0, $t0, -1
        beq  $t0, $zero, a_done     #    not taken 4 times, then taken
        j    loop
        addi $s7, $s7, 1            #    wrong path of the j
a_done: j    b_fwd
        addi $s7, $s7, 1
b_back: addi $s6, $s6, 1            # 6  B: reached backwards
        j    c_start
        addi $s7, $s7, 1
b_fwd:  beq  $zero, $zero, b_back   #    backward taken
        addi $s7, $s7, 1
        addi $s7, $s7, 1

c_start: beq $t1, $t1, c_next       # C: offset 0
c_next: addi $s6, $s6, 1            # 7  runs once

        beq  $zero, $zero, d_ok     # D
        beq  $zero, $zero, bad      #    in ID when the first resolves: flushed
        addi $s7, $s7, 1
d_ok:   addi $s6, $s6, 1            # 8

        addi $t2, $zero, 1
        beq  $t2, $zero, bad        # E: not taken
        beq  $t2, $t2, e_ok         #    taken
        addi $s7, $s7, 1
        addi $s7, $s7, 1
e_ok:   addi $s6, $s6, 1            # 9

        addi $a0, $zero, -7
        addi $a1, $zero, -7
        beq  $a0, $a1, f_ok         # F
        addi $s7, $s7, 1
        addi $s7, $s7, 1
f_ok:   addi $s6, $s6, 1            # 10

        j    g_ok                   # G
        j    bad                    #    flushed
        addi $s7, $s7, 1
g_ok:   addi $s6, $s6, 1            # 11

        addi $v0, $zero, -32768     # H: 0xffff8000, doubled 16 times
        add  $v0, $v0, $v0
        add  $v0, $v0, $v0
        add  $v0, $v0, $v0
        add  $v0, $v0, $v0
        add  $v0, $v0, $v0
        add  $v0, $v0, $v0
        add  $v0, $v0, $v0
        add  $v0, $v0, $v0
        add  $v0, $v0, $v0
        add  $v0, $v0, $v0
        add  $v0, $v0, $v0
        add  $v0, $v0, $v0
        add  $v0, $v0, $v0
        add  $v0, $v0, $v0
        add  $v0, $v0, $v0
        add  $v0, $v0, $v0          #    0x80000000
        beq  $v0, $zero, bad        #    not taken
        addi $s6, $s6, 1            # 12
        addi $s6, $s6, 1            # 13
        addi $s6, $s6, 1            # 14
        j    halt

bad:    addi $s7, $s7, 100          # only reached if a branch or j goes wrong
halt:   j    halt

# expect $s6 = 14
# expect $s7 = 0
# expect $t1 = 15
# expect $t0 = 0
# expect $v0 = 0x80000000
# expect beq_flushes = 6         # A, B, C, D, E, F
# expect j_flushes = 10          # 4 loop + a_done + b_back + G + "j halt" + 2 by the halt
# expect stalls = 0
# expect retired = 66
# 66 instructions + 4 to fill + 6 x 2 for the beqs + 8 x 1 for the j's
# (the halt's own 2 flushes come after the last instruction):
# expect cycles = 90
