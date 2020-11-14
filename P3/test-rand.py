import os
import random
import sys
import numpy as np
import testlib

count = 1 if len(sys.argv) < 2 else int(sys.argv[1])

if not os.path.exists('test-rand-logs'):
    os.mkdir('test-rand-logs')

for i in range(0, count):
    sys.stdout.close()
    sys.stdout = open(os.path.join('test-rand-logs', f'test-rand-{i}.log'), 'w')
    testlib.init(os.path.join('test-rand-logs', f'test-rand-{i}-img.txt'))
    regs = [0] + sorted(random.sample(range(1, 5), 4))
    addrs = sorted(random.sample(range(0, 32), 3))
    for _ in range(0, 32):
        op = random.choices(range(0, 7), weights=[1, 1, 1, 1, 1, 2, 2])[0]
        rs = random.choice(regs)
        rt = random.choice(regs)
        rd = random.choice(regs)
        imm = random.randrange(0, 1 << 16)
        if op == 0:
            testlib.nop()
        elif op == 1:
            testlib.addu(rd, rs, rt)
        elif op == 2:
            testlib.subu(rd, rs, rt)
        elif op == 3:
            testlib.ori(rt, rs, imm)
        elif op == 4:
            testlib.lui(rt, imm)
        else:
            addr = random.choice(addrs)
            while True:
                base = random.choice(regs)
                offset = (addr << 2) - testlib.grf[base]
                ii16 = np.iinfo(np.int16)
                if offset in range(ii16.min, ii16.max + 1):
                    break
            if op == 5:
                testlib.lw(rt, base, offset)
            else:
                testlib.sw(rt, base, offset)
    testlib.run_test()
    if (i + 1) % 10 == 0:
        print(f'{(i + 1) / count * 100:.2f}% done', file=sys.stderr)
