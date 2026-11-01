# Fibonacci for the pipeline with forwarding but no stalls or flushes:
# fibonacci.asm with only the nops that forwarding cannot remove.
#
# Forwarding hands an ALU result to the next two instructions, so ALU-to-ALU
# dependencies need no nops. The software still has to cover:
#   - load-use: a loaded value is ready only at the end of MEM, so the
#     instruction right after a lw cannot use it (1 nop, then the value is
#     forwarded from MEM/WB);
#   - beq is resolved in EX, so the 2 instructions after it always run
#     (2 delay-slot nops);
#   - j is resolved in ID, so the instruction after it always runs
#     (1 delay-slot nop).
#
# The program uses all four forwarding paths (operand A = rs, B = rt):
#   addi $t4 -> beq   A from EX/MEM   (first iteration)
#   addi $t3 -> beq   B from MEM/WB   (first iteration)
#   lw $t6   -> add   A from MEM/WB, after the load-use nop
#   add $t7  -> sw    B from EX/MEM: the store data, not an ALU input
#   addi $s0 -> sw    A from EX/MEM, then MEM/WB (the two prologue stores)
# To set these up, the prologue of fibonacci.asm is reordered (same eight
# instructions) and the add's operands are swapped. Every nop is an R-type
# that "writes" $zero, so they also check that $zero never forwards.
#
# Same result as fibonacci.asm with N = 12:
#   dmem word 0..11 = 0, 1, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89
#   $v0 = 89, $t4 = 12, $s0 = 48

        addi $t0, $zero, 0      # F(0)
        addi $t1, $zero, 1      # F(1)
        addi $s0, $zero, 0      # $s0 = address of the next free word
        sw   $t0, 0($s0)        # $s0 from EX/MEM (address)
        sw   $t1, 4($s0)        # $s0 from MEM/WB
        addi $s0, $s0, 8
        addi $t3, $zero, 12     # N
        addi $t4, $zero, 2      # i = 2

loop:   beq  $t4, $t3, done     # first time: $t4 from EX/MEM, $t3 from MEM/WB
        nop                     # branch delay slots
        nop
        lw   $t5, -8($s0)       # F(i-2)
        lw   $t6, -4($s0)       # F(i-1)
        nop                     # load-use: add reads $t6
        add  $t7, $t6, $t5      # F(i); $t6 from MEM/WB
        sw   $t7, 0($s0)        # $t7 from EX/MEM
        addi $s0, $s0, 4
        addi $t4, $t4, 1
        j    loop
        nop                     # jump delay slot

done:   lw   $v0, -4($s0)       # F(N-1)
halt:   j    halt               # the testbench stops when this reaches WB

# expect mem[0] = 0
# expect mem[1] = 1
# expect mem[2] = 1
# expect mem[3] = 2
# expect mem[4] = 3
# expect mem[5] = 5
# expect mem[6] = 8
# expect mem[7] = 13
# expect mem[8] = 21
# expect mem[9] = 34
# expect mem[10] = 55
# expect mem[11] = 89
# expect $v0 = 89
# expect $t4 = 12
# expect $s0 = 48
# expect retired = 90
# 132 instructions with the nops + 4 to fill; forwarding paths as listed at the top:
# expect cycles = 136
# expect stalls = 0
# expect fwd_a_mem = 2
# expect fwd_a_wb = 11
# expect fwd_b_mem = 10
# expect fwd_b_wb = 1
