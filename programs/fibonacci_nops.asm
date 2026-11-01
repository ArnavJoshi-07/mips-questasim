# Fibonacci for the pipeline before hazard handling: fibonacci.asm with nops
# inserted so that no instruction depends on one still in the pipeline.
#
# Without forwarding, stalls or flushes the software has to keep the pipeline
# safe:
#   - a register is read in ID and written in WB on the falling edge, so a
#     consumer must come at least 3 instructions after its producer
#     (2 nops if they would otherwise be adjacent);
#   - beq is resolved in EX, so the 2 instructions after it are always
#     fetched and executed (2 delay-slot nops);
#   - j is resolved in ID, so the instruction after it is always executed
#     (1 delay-slot nop).
# Once the hazard unit and forwarding are in place, fibonacci.asm runs as is.
#
# Same result as fibonacci.asm with N = 12:
#   dmem word 0..11 = 0, 1, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89
#   $v0 = 89, $t4 = 12, $s0 = 48

        addi $s0, $zero, 0      # $s0 = address of the next free word
        addi $t0, $zero, 0      # F(0)
        addi $t1, $zero, 1      # F(1)
        addi $t3, $zero, 12     # N
        sw   $t0, 0($s0)        # $t0 is 3 instructions back: safe
        sw   $t1, 4($s0)
        addi $s0, $s0, 8
        addi $t4, $zero, 2      # i = 2
        nop                     # beq reads $t4
        nop

loop:   beq  $t4, $t3, done
        nop                     # branch delay slots
        nop
        lw   $t5, -8($s0)       # F(i-2)
        lw   $t6, -4($s0)       # F(i-1)
        nop                     # add reads $t6
        nop
        add  $t7, $t5, $t6      # F(i)
        nop                     # sw reads $t7
        nop
        sw   $t7, 0($s0)
        addi $s0, $s0, 4
        addi $t4, $t4, 1        # beq is 3 instructions later: safe
        j    loop
        nop                     # jump delay slot

done:   lw   $v0, -4($s0)       # F(N-1)
halt:   j    halt               # the testbench stops when this reaches WB
