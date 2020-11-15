import os
import subprocess
import numpy as np

_img_out = None
global _std_log, grf, _mem, _pc;

def init(img_name):
    global _img_out, _std_log, grf, _mem, _pc
    if _img_out is not None and not _img_out.closed:
        _img_out.close()
    _img_out = open(img_name, 'w')
    _std_log = []
    grf = [np.uint32(0)] * 32
    _mem = [np.uint32(0)] * 1024
    _pc = 0x3000
    np.seterr(over='ignore')

def append_reg_log(addr):
    _std_log.append(f'@{_pc:08x}: ${addr:2d} <= {grf[addr]:08x}')

def append_mem_log(addr):
    _std_log.append(f'@{_pc:08x}: *{addr << 2:08x} <= {_mem[addr]:08x}')

def addu(rd, rs, rt):
    global _pc
    instr = (rs << 21) + (rt << 16) + (rd << 11) + 0b100001
    _img_out.write(f'{instr:08x}\n')
    grf[rd] = grf[rs] + grf[rt]
    append_reg_log(rd)
    grf[0] = np.uint32(0)
    _pc += 4

def subu(rd, rs, rt):
    global _pc
    instr = (rs << 21) + (rt << 16) + (rd << 11) + 0b100011
    _img_out.write(f'{instr:08x}\n')
    grf[rd] = grf[rs] - grf[rt]
    append_reg_log(rd)
    grf[0] = np.uint32(0)
    _pc += 4

def ori(rt, rs, imm):
    global _pc
    instr = (0b001101 << 26) + (rs << 21) + (rt << 16) + imm
    _img_out.write(f'{instr:08x}\n')
    grf[rt] = grf[rs] | np.uint16(imm)
    append_reg_log(rt)
    grf[0] = np.uint32(0)
    _pc += 4

def lw(rt, base, offset):
    global _pc
    instr = (0b100011 << 26) + (base << 21) + (rt << 16) + np.uint16(offset)
    _img_out.write(f'{instr:08x}\n')
    addr = (grf[base] + offset) >> 2
    grf[rt] = _mem[addr]
    append_reg_log(rt)
    grf[0] = np.uint32(0)
    _pc += 4

def sw(rt, base, offset):
    global _pc
    instr = (0b101011 << 26) + (base << 21) + (rt << 16) + np.uint16(offset)
    _img_out.write(f'{instr:08x}\n')
    addr = (grf[base] + offset) >> 2
    _mem[addr] = grf[rt]
    append_mem_log(addr)
    _pc += 4

def lui(rt, imm):
    global _pc
    instr = (0b001111 << 26) + (rt << 16) + imm
    _img_out.write(f'{instr:08x}\n')
    grf[rt] = np.uint32(imm << 16)
    append_reg_log(rt)
    grf[0] = np.uint32(0)
    _pc += 4

def nop():
    global _pc
    _img_out.write('00000000\n')
    _pc += 4

def run_test():
    for x in _std_log:
        print(x)
    print()
    if not _img_out.closed:
        _img_out.close()
    output = subprocess.check_output(['vvp', 'out/P4'], text=True)
    for i, line in enumerate(x for x in output.strip().split('\n') if x.startswith('@')):
        print(line)
        assert line == _std_log[i]
