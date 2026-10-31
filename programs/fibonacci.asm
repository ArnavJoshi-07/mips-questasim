# Fibonacci: writes F(0) .. F(N-1) to data memory and leaves F(N-1) in $v0.
#
# Uses only the supported subset (add, addi, lw, sw, beq, j). The loop reads
# the two previous terms back from memory, so every iteration exercises:
#   - a load-use stall      (lw $t6 -> add)
#   - EX/MEM forwarding     (add $t7 -> sw)
#   - a taken jump and, on exit, a taken branch with a flush
#
# Expected result with N = 12:
#   dmem word 0..11 = 0, 1, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89
#   $v0 = 89, $t4 = 12, $s0 = 48 (byte address just past the last term)

        addi $s0, $zero, 0      # $s0 = address of the next free word
        addi $t0, $zero, 0      # F(0)
        addi $t1, $zero, 1      # F(1)
        addi $t3, $zero, 12     # N
        sw   $t0, 0($s0)
        sw   $t1, 4($s0)
        addi $s0, $s0, 8
        addi $t4, $zero, 2      # i = 2

loop:   beq  $t4, $t3, done
        lw   $t5, -8($s0)       # F(i-2)
        lw   $t6, -4($s0)       # F(i-1)
        add  $t7, $t5, $t6      # F(i)
        sw   $t7, 0($s0)
        addi $s0, $s0, 4
        addi $t4, $t4, 1
        j    loop

done:   lw   $v0, -4($s0)       # F(N-1)
halt:   j    halt               # the testbench stops when the PC reaches here
