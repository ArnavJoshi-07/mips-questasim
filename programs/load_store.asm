# Word loads and stores: positive, zero and negative offsets, $zero as the
# base, the last word of dmem, a word never written, a load straight after
# a store to the same word, an overwrite, a load into $zero (dropped), a
# forwarded base address, and an address above 1 KB (dmem ignores the bits
# above bit 9, so it wraps around to the bottom).

        addi $s0, $zero, 0x100      # base: byte 256 = word 64
        addi $t0, $zero, 111
        addi $t1, $zero, -222
        addi $t2, $zero, 0x7abc
        sw   $t0, 0($s0)            # word 64
        sw   $t1, 4($s0)            # word 65
        sw   $t2, -4($s0)           # word 63, negative offset
        sw   $t0, 0($zero)          # word 0, $zero as the base
        addi $s1, $zero, 0x3fc      # byte address of the last word
        sw   $t1, 0($s1)            # word 255; $s1 forwarded from EX/MEM

        lw   $s2, 0($s0)
        lw   $s3, 4($s0)
        lw   $s4, -4($s0)
        lw   $s5, 0($s1)
        lw   $s6, 8($s0)            # word 66, never written: 0
        sw   $t2, 8($s0)            # now write it...
        lw   $s7, 8($s0)            # ...and read it back in the next cycle
        sw   $t1, 0($s0)            # overwrite word 64
        lw   $t3, 0($s0)
        lw   $zero, 4($s0)          # dropped: $zero stays 0, and no stall below
        add  $t4, $zero, $t0        # reads $zero right after the lw
        sw   $t0, 0x408($zero)      # byte 1032 wraps to word 2
        lw   $t5, 8($zero)          # word 2
        addi $t6, $s0, 16           # byte 0x110 = word 68
        sw   $t6, 0($t6)            # base and data both from EX/MEM
        lw   $t7, 0($t6)            # base from MEM/WB

# expect mem[0] = 111
# expect mem[2] = 111
# expect mem[63] = 0x7abc
# expect mem[64] = -222
# expect mem[65] = -222
# expect mem[66] = 0x7abc
# expect mem[68] = 0x110
# expect mem[255] = -222
# expect $s2 = 111
# expect $s3 = -222
# expect $s4 = 0x7abc
# expect $s5 = -222
# expect $s6 = 0
# expect $s7 = 0x7abc
# expect $t3 = -222
# expect $zero = 0
# expect $t4 = 111
# expect $t5 = 111
# expect $t7 = 0x110
# expect stalls = 0

# 26 instructions + 4 to fill:
# expect cycles = 30

halt:   j    halt
