# Directed test of the forwarding unit. Each case sets up one hazard; the
# pipeline counters at the end pin how often each path was used. No case
# needs a stall or a nop.
#
#   A  EX/MEM -> A            the next instruction reads the result as rs
#   B  EX/MEM -> B            ... as rt
#   C  MEM/WB -> A            two instructions later, as rs
#   D  MEM/WB -> B            two instructions later, as rt
#   E  double hazard          EX/MEM and MEM/WB both write $t3: the newer
#                             (EX/MEM) value must win, on both operands
#   F  A and B from different stages in the same cycle
#   G  store data             sw's rt (the value stored) from EX/MEM
#   H  loaded value           from MEM/WB, two instructions after the lw
#   I  $zero                  an instruction "writes" $zero just before a
#                             read of $zero: nothing may be forwarded
#   J  three apart            no forwarding: the register file is written on
#                             the falling edge, before ID reads it
#   K  beq operands           both from forwarding; taken, so the two wrong-
#                             path instructions behind it are flushed
#   L  chain                  each add reads the one before, 4 times
#
# Forward counts (the dut signals, as tb_mips_top counts them):
#   A<-EX/MEM  6   A, E, and the 4 adds of L
#   A<-MEM/WB  4   C, F, H, K
#   B<-EX/MEM 11   B, E, F, G, K, the 4 adds of L, and 2 harmless matches:
#                  the second addi $t3 (E) and the second addi $s6 (J)
#                  have the previous instruction's destination as their
#                  rt. For addi rt is the destination, and alu_src picks
#                  the immediate, so the forwarded value is not used.
#   B<-MEM/WB  2   D, H

        addi $t0, $zero, 5
        add  $t1, $t0, $zero        # A: rs from EX/MEM               t1 = 5
        add  $t2, $zero, $t1        # B: rt from EX/MEM               t2 = 5

        addi $a0, $zero, 7
        addi $a1, $zero, 1          # (unrelated)
        add  $a2, $a0, $zero        # C: rs from MEM/WB               a2 = 7
        addi $a3, $zero, 9
        addi $v1, $zero, 2          # (unrelated)
        sub  $v0, $zero, $a3        # D: rt from MEM/WB               v0 = -9

        addi $t3, $zero, 1
        addi $t3, $zero, 2          # E: $t3 in MEM/WB (1) and EX/MEM (2)
        add  $t4, $t3, $t3          #    must use 2 on both sides     t4 = 4

        addi $t5, $zero, 10
        addi $t6, $zero, 20
        sub  $t7, $t5, $t6          # F: A from MEM/WB, B from EX/MEM t7 = -10

        addi $s0, $zero, 77
        sw   $s0, 0($zero)          # G: store data from EX/MEM       word 0 = 77

        lw   $s1, 0($zero)
        addi $s2, $zero, 3          # (unrelated: no load-use stall)
        add  $s3, $s1, $s1          # H: both from MEM/WB, the load   s3 = 154

        add  $zero, $t0, $t0        # I: "writes" 10 to $zero
        add  $s4, $zero, $t0        #    rs is $zero: must read 0     s4 = 5

        addi $s5, $zero, 9
        addi $s6, $zero, 1          # (unrelated)
        addi $s6, $zero, 1          # (unrelated)
        add  $s7, $s5, $zero        # J: from the register file       s7 = 9

        addi $t8, $zero, -4
        addi $t9, $zero, -4
        beq  $t8, $t9, k_ok         # K: A from MEM/WB, B from EX/MEM; taken
        addi $k0, $zero, 1          #    flushed
        addi $k0, $zero, 1          #    flushed
k_ok:   addi $k1, $zero, 1          # L
        add  $k1, $k1, $k1          # 2
        add  $k1, $k1, $k1          # 4
        add  $k1, $k1, $k1          # 8
        add  $k1, $k1, $k1          # 16

# expect $t1 = 5
# expect $t2 = 5
# expect $a2 = 7
# expect $v0 = -9
# expect $t4 = 4
# expect $t7 = -10
# expect mem[0] = 77
# expect $s3 = 154
# expect $zero = 0
# expect $s4 = 5
# expect $s7 = 9
# expect $k0 = 0
# expect $k1 = 16
# expect stalls = 0
# expect beq_flushes = 1
# expect fwd_a_mem = 6
# expect fwd_a_wb = 4
# expect fwd_b_mem = 11
# expect fwd_b_wb = 2

# 34 instructions + 4 to fill + 2 for the beq:
# expect cycles = 40

halt:   j    halt
