# Fibonacci for the pipeline with forwarding and load-use stalls:
# fibonacci_fwd.asm without the load-use nop.
#
# In the loop, add reads $t6 right after lw $t6 loads it. The hazard unit
# sees the lw in EX and the add in ID reading its destination, and stalls
# one cycle: the add waits in ID while a bubble goes down the pipeline. When
# the add reaches EX the lw is in WB, and $t6 is forwarded from MEM/WB.
# This happens once per iteration, 10 times in all.
#
# The program still covers the control hazards itself:
#   - beq is resolved in EX, so the 2 instructions after it always run
#     (2 delay-slot nops);
#   - j is resolved in ID, so the instruction after it always runs
#     (1 delay-slot nop).
#
# Same result as fibonacci.asm with N = 12:
#   dmem word 0..11 = 0, 1, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89
#   $v0 = 89, $t4 = 12, $s0 = 48

        addi $t0, $zero, 0      # F(0)
        addi $t1, $zero, 1      # F(1)
        addi $s0, $zero, 0      # $s0 = address of the next free word
        sw   $t0, 0($s0)
        sw   $t1, 4($s0)
        addi $s0, $s0, 8
        addi $t3, $zero, 12     # N
        addi $t4, $zero, 2      # i = 2

loop:   beq  $t4, $t3, done
        nop                     # branch delay slots
        nop
        lw   $t5, -8($s0)       # F(i-2)
        lw   $t6, -4($s0)       # F(i-1)
        add  $t7, $t6, $t5      # F(i); load-use on $t6: 1-cycle stall
        sw   $t7, 0($s0)
        addi $s0, $s0, 4
        addi $t4, $t4, 1
        j    loop
        nop                     # jump delay slot

done:   lw   $v0, -4($s0)       # F(N-1)
halt:   j    halt               # the testbench stops when this reaches WB
