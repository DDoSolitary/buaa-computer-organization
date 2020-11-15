import testlib

testlib.init('code.txt')

testlib.lui(1, 24)
testlib.ori(1, 1, 42)
testlib.lui(2, 54321)
testlib.ori(2, 2, 12345)
testlib.addu(3, 1, 2)
testlib.subu(4, 1, 2)
testlib.ori(5, 1, 233)
testlib.lui(1, 0xdead)

testlib.run_test()
