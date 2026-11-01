#!/usr/bin/env python3
"""Assembler and reference simulator for the supported MIPS subset.

    python3 programs/asm.py programs/alu_ops.asm [more.asm ...]

For each <name>.asm this writes:
  <name>.hex     one instruction word per line, the format imem loads with
                 $readmemh (+PROGRAM=<name>.hex);
  <name>.expect  the "# expect" lines of the source, in a form the suite
                 testbench (tests/tb_suite.v) reads with $fscanf.

It then runs the program on a small instruction-set simulator, independent
of the Verilog, and checks every register and memory expectation against
it. A wrong expectation is caught here, before any hardware runs. If
<name>_data.hex exists, it is loaded into data memory first, as the
testbench does with +DATA.

Supported: add sub and or slt addi lw sw beq j nop, labels, and
"j <address>" with a numeric target. Registers by name ($t0) or number ($8).

Expectations, anywhere in the source, one per line:
  # expect $v0 = 89            register after the halt
  # expect mem[3] = -7         data memory word 3 (byte address 12)
  # expect cycles = 116        pipeline counter, checked by tb_suite only
Pipeline counters: cycles retired stalls beq_flushes j_flushes
                   fwd_a_mem fwd_a_wb fwd_b_mem fwd_b_wb
"retired" (instructions other than nops, without the halt) is also checked
here.
"""
import re
import sys
from pathlib import Path

REGS = ["zero", "at", "v0", "v1", "a0", "a1", "a2", "a3",
        "t0", "t1", "t2", "t3", "t4", "t5", "t6", "t7",
        "s0", "s1", "s2", "s3", "s4", "s5", "s6", "s7",
        "t8", "t9", "k0", "k1", "gp", "sp", "fp", "ra"]
R_FUNCT = {"add": 0x20, "sub": 0x22, "and": 0x24, "or": 0x25, "slt": 0x2a}
OPCODE = {"addi": 0x08, "lw": 0x23, "sw": 0x2b, "beq": 0x04, "j": 0x02}
# Index of each pipeline counter in the .expect file ("p <index> <value>")
COUNTERS = ["cycles", "retired", "stalls", "beq_flushes", "j_flushes",
            "fwd_a_mem", "fwd_a_wb", "fwd_b_mem", "fwd_b_wb"]
MASK = 0xFFFFFFFF


class AsmError(Exception):
    pass


def reg(text):
    t = text.strip()
    if not t.startswith("$"):
        raise AsmError(f"expected a register, got '{t}'")
    t = t[1:]
    if t.isdigit() and int(t) < 32:
        return int(t)
    if t in REGS:
        return REGS.index(t)
    raise AsmError(f"unknown register '${t}'")


def num(text):
    return int(text.strip(), 0)


def signed(v):
    v &= MASK
    return v - (1 << 32) if v & 0x80000000 else v


def imm16(v, what):
    if not -0x8000 <= v <= 0x7FFF:
        raise AsmError(f"{what} {v} does not fit in 16 signed bits")
    return v & 0xFFFF


def parse(path):
    """Return (instructions, labels, expectations) from an .asm file."""
    insts, labels, expects = [], {}, []
    for lineno, line in enumerate(path.read_text().splitlines(), 1):
        m = re.match(r"\s*#\s*expect\s+(\S+)\s*=\s*(\S+)", line)
        if m:
            expects.append((lineno, m.group(1), num(m.group(2))))
            continue
        code = line.split("#", 1)[0].strip()
        while True:
            m = re.match(r"(\w+):\s*(.*)", code)
            if not m:
                break
            labels[m.group(1)] = 4 * len(insts)
            code = m.group(2)
        if code:
            mn, _, ops = code.partition(" ")
            ops = [o.strip() for o in ops.split(",")] if ops.strip() else []
            insts.append((lineno, mn.lower(), ops))
    return insts, labels, expects


def encode(mn, ops, addr, labels):
    def target(t):
        return labels[t] if t in labels else num(t)

    def need(n):
        if len(ops) != n:
            raise AsmError(f"{mn} takes {n} operands, got {len(ops)}")

    if mn == "nop":
        need(0)
        return 0
    if mn in R_FUNCT:
        need(3)
        rd, rs, rt = (reg(o) for o in ops)
        return (rs << 21) | (rt << 16) | (rd << 11) | R_FUNCT[mn]
    if mn == "addi":
        need(3)
        rt, rs = reg(ops[0]), reg(ops[1])
        return (OPCODE[mn] << 26) | (rs << 21) | (rt << 16) | imm16(num(ops[2]), "immediate")
    if mn in ("lw", "sw"):
        need(2)
        m = re.fullmatch(r"(.*)\((.*)\)", ops[1])
        if not m:
            raise AsmError(f"expected offset($reg), got '{ops[1]}'")
        off = num(m.group(1)) if m.group(1).strip() else 0
        return ((OPCODE[mn] << 26) | (reg(m.group(2)) << 21) | (reg(ops[0]) << 16)
                | imm16(off, "offset"))
    if mn == "beq":
        need(3)
        rs, rt = reg(ops[0]), reg(ops[1])
        off = (target(ops[2]) - (addr + 4)) // 4
        return (OPCODE[mn] << 26) | (rs << 21) | (rt << 16) | imm16(off, "branch offset")
    if mn == "j":
        need(1)
        return (OPCODE[mn] << 26) | ((target(ops[0]) >> 2) & 0x3FFFFFF)
    raise AsmError(f"unsupported instruction '{mn}'")


def simulate(words, data, max_steps=100000):
    """Run until a j to itself. Returns (regs, mem, retired)."""
    regs, mem = [0] * 32, list(data)
    pc, retired = 0, 0
    for _ in range(max_steps):
        w = words[(pc >> 2) & 0xFF] if (pc >> 2) & 0xFF < len(words) else 0
        op, rs, rt, rd = w >> 26, (w >> 21) & 31, (w >> 16) & 31, (w >> 11) & 31
        imm = (w & 0xFFFF) - 0x10000 if w & 0x8000 else w & 0xFFFF
        nxt = (pc + 4) & MASK
        if op == 0x02:
            tgt = (nxt & 0xF0000000) | ((w & 0x3FFFFFF) << 2)
            if tgt == pc:
                return regs, mem, retired
            nxt = tgt
        elif op == 0 and w != 0:
            a, b = regs[rs], regs[rt]
            funct = w & 0x3F
            res = {0x20: a + b, 0x22: a - b, 0x24: a & b, 0x25: a | b,
                   0x2a: int(signed(a) < signed(b))}.get(funct, 0)
            if funct in (0x20, 0x22, 0x24, 0x25, 0x2a) and rd:
                regs[rd] = res & MASK
        elif op == 0x08:
            if rt:
                regs[rt] = (regs[rs] + imm) & MASK
        elif op == 0x23:
            if rt:
                regs[rt] = mem[((regs[rs] + imm) >> 2) & 0xFF]
        elif op == 0x2B:
            mem[((regs[rs] + imm) >> 2) & 0xFF] = regs[rt]
        elif op == 0x04:
            if regs[rs] == regs[rt]:
                nxt = (nxt + (imm << 2)) & MASK
        retired += w != 0
        pc = nxt
    raise AsmError(f"no halt (j to itself) within {max_steps} instructions")


def load_data(path):
    mem = [0] * 256
    if path.exists():
        words = [t for line in path.read_text().splitlines()
                 for t in line.split("//", 1)[0].split()]
        for i, t in enumerate(words):
            mem[i] = int(t, 16)
    return mem


def assemble(path):
    insts, labels, expects = parse(path)
    words, lines = [], []
    for i, (lineno, mn, ops) in enumerate(insts):
        try:
            w = encode(mn, ops, 4 * i, labels)
        except (AsmError, KeyError, ValueError) as e:
            raise AsmError(f"{path}:{lineno}: {e}") from None
        words.append(w)
        text = "nop" if mn == "nop" else f"{mn:<4} {', '.join(ops)}"
        lines.append(f"{w:08x}  // {4 * i:02x}: {text}")
    if len(words) > 256:
        raise AsmError(f"{path}: {len(words)} instructions, imem holds 256")

    hexfile = path.with_suffix(".hex")
    hexfile.write_text(
        f"// {path.name} assembled for imem: one 32-bit word per line, starting at PC 0.\n"
        "// The comment on each line gives the byte address and the source instruction.\n"
        + "\n".join(lines) + "\n")

    regs, mem, retired = simulate(words, load_data(path.with_name(path.stem + "_data.hex")))

    out, errors = [], []
    for lineno, key, value in expects:
        value &= MASK
        m = re.fullmatch(r"mem\[(\w+)\]", key)
        if key.startswith("$"):
            r = reg(key)
            out.append(f"r {r} {value:08x} {key}")
            got = regs[r]
        elif m:
            wi = num(m.group(1))
            out.append(f"m {wi} {value:08x} {key}")
            got = mem[wi]
        elif key in COUNTERS:
            out.append(f"p {COUNTERS.index(key)} {value:08x} {key}")
            got = retired if key == "retired" else None
        else:
            raise AsmError(f"{path}:{lineno}: unknown expectation '{key}'")
        if got is not None and got != value:
            errors.append(f"{path}:{lineno}: expect {key} = {signed(value)}, "
                          f"simulator gives {signed(got)} ({got:08x})")
    path.with_suffix(".expect").write_text("\n".join(out) + "\n" if out else "")
    return len(words), len(expects), errors


def main(argv):
    if not argv:
        print(__doc__)
        return 2
    failed = False
    for a in argv:
        try:
            n, e, errors = assemble(Path(a))
        except AsmError as err:
            print(f"error: {err}")
            failed = True
            continue
        for msg in errors:
            print(f"error: {msg}")
        failed |= bool(errors)
        print(f"{'FAIL' if errors else 'ok  '}  {a}: {n} instructions, {e} expectations")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
