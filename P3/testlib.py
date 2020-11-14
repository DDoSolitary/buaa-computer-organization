import pathlib
import os
import subprocess
import numpy as np

_img_out = None
global _std_log, grf, _mem

def init(img_name):
    global _img_out, _std_log, grf, _mem
    if _img_out is not None and not _img_out.closed:
        _img_out.close()
    _img_out = open(img_name, 'w')
    _img_out.write('v2.0 raw\n')
    _std_log = [[0, 0, 0, 0, 0, 0, 0]]
    grf = [np.uint32(0)] * 32
    _mem = [np.uint32(0)] * 32
    np.seterr(over='ignore')

def append_std_log(data):
    if len(_std_log) == 0 or _std_log[-1] != data:
        _std_log.append(data)

def addu(rd, rs, rt):
    instr = (rs << 21) + (rt << 16) + (rd << 11) + 0b100001
    _img_out.write(f'{instr:08x}\n')
    grf[rd] = grf[rs] + grf[rt]
    append_std_log([instr, 1, rd, grf[rd], 0, 0, 0])
    grf[0] = np.uint32(0)

def subu(rd, rs, rt):
    instr = (rs << 21) + (rt << 16) + (rd << 11) + 0b100011
    _img_out.write(f'{instr:08x}\n')
    grf[rd] = grf[rs] - grf[rt]
    append_std_log([instr, 1, rd, grf[rd], 0, 0, 0])
    grf[0] = np.uint32(0)

def ori(rt, rs, imm):
    instr = (0b001101 << 26) + (rs << 21) + (rt << 16) + imm
    _img_out.write(f'{instr:08x}\n')
    grf[rt] = grf[rs] | np.uint16(imm)
    append_std_log([instr, 1, rt, grf[rt], 0, 0, 0])
    grf[0] = np.uint32(0)

def lw(rt, base, offset):
    instr = (0b100011 << 26) + (base << 21) + (rt << 16) + np.uint16(offset)
    _img_out.write(f'{instr:08x}\n')
    addr = (grf[base] + offset) >> 2
    grf[rt] = _mem[addr]
    append_std_log([instr, 1, rt, grf[rt], 0, 0, 0])
    grf[0] = np.uint32(0)

def sw(rt, base, offset):
    instr = (0b101011 << 26) + (base << 21) + (rt << 16) + np.uint16(offset)
    _img_out.write(f'{instr:08x}\n')
    addr = (grf[base] + offset) >> 2
    _mem[addr] = grf[rt]
    append_std_log([instr, 0, 0, 0, 1, addr, _mem[addr]])

def lui(rt, imm):
    instr = (0b001111 << 26) + (rt << 16) + imm
    _img_out.write(f'{instr:08x}\n')
    grf[rt] = np.uint32(imm << 16)
    append_std_log([instr, 1, rt, grf[rt], 0, 0, 0])
    grf[0] = np.uint32(0)

def nop():
    _img_out.write('00000000\n')
    append_std_log([0, 0, 0, 0, 0, 0, 0])

def run_test():
    append_std_log([0, 0, 0, 0, 0, 0, 0])
    for x in _std_log:
        print(x)
    print()
    if not _img_out.closed:
        _img_out.close()
    logisim_path = pathlib.PurePath(os.path.dirname(os.path.realpath(__file__))) / '..' / 'logisim-generic-2.7.1.jar'
    output = subprocess.check_output(['java', '-jar', logisim_path, '-tty', 'table', '-load', os.path.realpath(_img_out.name), 'P3-test.circ'], text=True)
    for i, line in enumerate(output.strip().split('\n')):
        log_data = [int(x.replace(' ', ''), 2) for x in line.split('\t')]
        print(log_data)
        assert log_data == _std_log[i]
