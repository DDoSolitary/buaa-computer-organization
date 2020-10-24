li $v0, 5
syscall
move $s0, $v0
li $s1, 0
li $t0, 4
divu $s0, $t0
mfhi $t1
bnez $t1, L0
li $s1, 1
L0:
li $t0, 100
divu $s0, $t0
mfhi $t1
bnez $t1, L1
li $s1, 0
L1:
li $t0, 400
divu $s0, $t0
mfhi $t1
bnez $t1, L2
li $s1, 1
L2:
move $a0, $s1
li $v0, 1
syscall
li $v0, 10
syscall
