import testlib

testlib.init('test-dm-img.txt')

testlib.lui(1, 24)
testlib.ori(1, 1, 42)
testlib.ori(2, 2, 5)
testlib.sw(1, 2, -1)
testlib.lw(2, 0, 4)

testlib.run_test()
