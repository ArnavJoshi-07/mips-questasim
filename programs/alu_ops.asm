# Every ALU instruction (add, sub, and, or, slt, addi) with positive,
# negative and zero operands, the 16-bit immediate limits, and the 32-bit
# wrap-around of add, addi and sub. The ALU ignores overflow (no trap), so
# the results wrap. slt must stay correct when a - b overflows: it uses the
# sign of the difference corrected by the overflow bit.
#
# Most instructions depend on the one before, so this is also a dense
# forwarding workout; the single-cycle comparison in tb_suite catches any
# operand that arrives wrong.

        addi $t0, $zero, 12
        addi $t1, $zero, 10         # 0b1010
        addi $t2, $zero, -3         # 0xfffffffd
        addi $t3, $zero, 0x7fff     # largest immediate
        addi $t4, $zero, -32768     # smallest immediate, 0xffff8000
# expect $t0 = 12
# expect $t1 = 10
# expect $t2 = -3
# expect $t3 = 0x7fff
# expect $t4 = 0xffff8000

        add  $s0, $t0, $t1          # positive + positive
        add  $s1, $t0, $t2          # positive + negative
        sub  $s2, $t1, $t0          # negative result
        sub  $s3, $t0, $t0          # zero result
        and  $s4, $t0, $t1          # 1100 & 1010
        or   $s5, $t0, $t1          # 1100 | 1010
        and  $s6, $t2, $t3          # 0xfffffffd & 0x7fff
        or   $s7, $t2, $t1          # 0xfffffffd | 0xa
# expect $s0 = 22
# expect $s1 = 9
# expect $s2 = -2
# expect $s3 = 0
# expect $s4 = 8
# expect $s5 = 14
# expect $s6 = 0x7ffd
# expect $s7 = 0xffffffff

        slt  $t5, $t1, $t0          # 10 < 12
        slt  $t6, $t0, $t1          # 12 < 10
        slt  $t7, $t2, $t1          # -3 < 10: signed, not unsigned
        slt  $t8, $t1, $t2          # 10 < -3
        slt  $t9, $t0, $t0          # equal
# expect $t5 = 1
# expect $t6 = 0
# expect $t7 = 1
# expect $t8 = 0
# expect $t9 = 0

        addi $a0, $t4, -1           # below the smallest immediate
        add  $a1, $t3, $t3          # 0x7fff + 0x7fff
# expect $a0 = 0xffff7fff
# expect $a1 = 0xfffe

        # 0x80000000, the most negative word: -32768 doubled 16 times
        add  $v0, $t4, $t4
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
        addi $v1, $v0, -1           # wraps to 0x7fffffff, the most positive
        addi $a2, $v1, 1            # wraps back to 0x80000000
        sub  $sp, $v0, $t0          # wraps to 0x7ffffff4
        slt  $a3, $v0, $v1          # min < max: true, although min - max overflows
        slt  $gp, $v1, $v0          # max < min: false, although max - min overflows
        add  $fp, $v1, $v0          # max + min = -1
# expect $v0 = 0x80000000
# expect $v1 = 0x7fffffff
# expect $a2 = 0x80000000
# expect $sp = 0x7ffffff4
# expect $a3 = 1
# expect $gp = 0
# expect $fp = -1

        # Operations with $zero, and writes to $zero
        and  $k0, $t2, $zero        # x & 0
        or   $k1, $t3, $zero        # x | 0
        sub  $ra, $zero, $t1        # 0 - x
        add  $zero, $t0, $t1        # dropped: $zero stays 0
        add  $at, $zero, $t0        # reads 0, not 22: $zero is never forwarded
        addi $zero, $zero, 5        # dropped too
        or   $s3, $zero, $zero      # 0 | 0
# expect $k0 = 0
# expect $k1 = 0x7fff
# expect $ra = -10
# expect $zero = 0
# expect $at = 12
# expect $s3 = 0

# expect retired = 49
# 49 instructions + 4 to fill:
# expect cycles = 53

halt:   j    halt
