# Directed test of the load-use stall. The hazard unit stalls one cycle
# when the instruction in ID names, as rs or rt, the register the lw in EX
# is loading; the loaded value is then forwarded from MEM/WB.
#
#   A  lw -> add, rs            stall
#   B  lw -> sub, rt            stall
#   C  lw -> sw, store data     stall
#   D  lw -> sw, base address   stall
#   E  lw -> lw, base address   stall (pointer chasing)
#   F  lw -> addi, rs           stall
#   G  lw -> beq                stall, then the beq is taken
#   H  lw -> addi, rt           stall, although addi only WRITES its rt.
#                               The hazard unit compares rt for every
#                               instruction, so this stall is not needed:
#                               it costs a cycle but gives the right result.
#   I  lw, unrelated, use       no stall: the value is forwarded from MEM/WB
#   J  lw -> unrelated          no stall
#   K  lw $zero -> reads $zero  no stall: a load into $zero is ignored
#
# Expected: 8 stalls (A to H), each costing one cycle.

        addi $s0, $zero, 40         # data at word 10
        addi $t0, $zero, 6
        addi $t1, $zero, 44         # a pointer to word 11
        sw   $t0, 0($s0)            # word 10 = 6
        sw   $t1, 4($s0)            # word 11 = 44
        sw   $t1, 8($s0)            # word 12 = 44
        addi $t9, $zero, 0          # (keeps the sw $t1 out of A's way)

        lw   $a0, 0($s0)            # A
        add  $a1, $a0, $t0          #   stall; 6 + 6 = 12
        lw   $a2, 0($s0)            # B
        sub  $a3, $t1, $a2          #   stall; 44 - 6 = 38
        lw   $v0, 0($s0)            # C
        sw   $v0, 12($s0)           #   stall; word 13 = 6
        lw   $v1, 8($s0)            # D: $v1 = 44
        sw   $t0, 0($v1)            #   stall; word 11 = 6
        lw   $t2, 4($s0)            # E: $t2 = 6 (word 11, just written)
        lw   $t3, 0($t1)            #   no stall: different register; 6
        lw   $t4, 4($s0)            #   $t4 = 6
        lw   $t5, 34($t4)           #   stall; base 6 + 34 = 40: word 10 = 6
        lw   $t6, 0($s0)            # F
        addi $t7, $t6, 100          #   stall; 106
        lw   $s1, 0($s0)            # G: $s1 = 6
        beq  $s1, $t0, g_ok         #   stall, then taken
        addi $s7, $s7, 1            #   wrong path: flushed
        addi $s7, $s7, 1            #   wrong path: flushed
g_ok:   lw   $s2, 0($s0)            # H: $s2 = 6
        addi $s2, $zero, 1          #   stall (not needed); $s2 = 1
        lw   $s3, 0($s0)            # I
        addi $s4, $zero, 2          #   (unrelated)
        add  $s5, $s3, $s3          #   from MEM/WB, no stall; 12
        lw   $s6, 0($s0)            # J
        addi $t8, $zero, 3          #   no stall
        lw   $zero, 0($s0)          # K
        add  $k0, $zero, $zero      #   no stall; 0
        addi $k1, $zero, 5          #   ($zero in both its rs and rt)

# expect $a1 = 12
# expect $a3 = 38
# expect mem[13] = 6
# expect mem[11] = 6
# expect $t3 = 6
# expect $t5 = 6
# expect $t7 = 106
# expect $s2 = 1
# expect $s5 = 12
# expect $s7 = 0
# expect $k0 = 0
# expect $zero = 0
# expect stalls = 8
# expect beq_flushes = 1

# 33 instructions + 4 to fill + 8 stalls + 2 for the beq:
# expect cycles = 47

halt:   j    halt
