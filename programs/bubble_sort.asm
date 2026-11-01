# Bubble sort of the 10 signed words at dmem words 0..9, which the
# testbench preloads from bubble_sort_data.hex (+DATA). Sorts in place,
# ascending, and stops early after a pass with no swaps.
#
# Heavy memory traffic and tight loops: every inner iteration has two loads,
# a load-use stall (lw $t2 -> slt), a beq that is taken when no swap is
# needed, and a j back to the top.
#
# Expected: dmem words 0..9 = -100, -5, 0, 1, 7, 7, 12, 34, 55, 89

        addi $s0, $zero, 10         # n
outer:  addi $s0, $s0, -1           # compare words 0..n-1 with their right neighbour
        beq  $s0, $zero, done
        addi $s1, $zero, 0          # swapped = 0
        addi $t0, $zero, 0          # byte address of a[i]
        add  $t9, $s0, $s0
        add  $t9, $t9, $t9          # end = 4 * (n - 1)
inner:  beq  $t0, $t9, pass_end
        lw   $t1, 0($t0)            # a[i]
        lw   $t2, 4($t0)            # a[i+1]
        slt  $t3, $t2, $t1          # out of order?  (load-use stall)
        beq  $t3, $zero, no_swap
        sw   $t2, 0($t0)
        sw   $t1, 4($t0)
        addi $s1, $zero, 1          # swapped = 1
no_swap: addi $t0, $t0, 4
        j    inner
pass_end: beq $s1, $zero, done      # no swaps: sorted
        j    outer
done:
halt:   j    halt

# expect mem[0] = -100
# expect mem[1] = -5
# expect mem[2] = 0
# expect mem[3] = 1
# expect mem[4] = 7
# expect mem[5] = 7
# expect mem[6] = 12
# expect mem[7] = 34
# expect mem[8] = 55
# expect mem[9] = 89
# expect mem[10] = 0
# Measured, to pin the performance (one stall per inner iteration):
# expect stalls = 42
# expect cycles = 574
