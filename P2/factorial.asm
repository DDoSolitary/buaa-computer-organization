.data
DATA:
.half 1
.space 498

.text
li $v0, 5
syscall
move $s0, $v0
li $s1, 10000
li $t0, 1
li $t1, 2
li $t2, 0
L0:
move $t3, $t2
li $t4, 0
L1:
lhu $t5, DATA($t3)
mulu $t5, $t5, $t0
addu $t4, $t4, $t5
div $t4, $s1
mflo $t4
mfhi $t5
sh $t5, DATA($t3)
addiu $t3, $t3, 2
bne $t3, $t1, L1
beqz $t4, L2
sh $t4, DATA($t1)
addiu $t1, $t1, 2
L2:
lhu $t3, DATA($t2)
bnez $t3, L3
addiu $t2, $t2, 2
L3:
addiu $t0, $t0, 1
bleu $t0, $s0, L0

li $s1, 10
L4:
addiu $t1, $t1, -2
lhu $t0, DATA($t1)
beqz $t0, L4
move $a0, $t0
li $v0, 1
syscall
L5:
beqz $t1, L6
addiu $t1, $t1, -2
lhu $t0, DATA($t1)
div $t0, $s1
mflo $t0
mfhi $t2
div $t0, $s1
mflo $t0
mfhi $t3
div $t0, $s1
mflo $a0
syscall
mfhi $a0
syscall
move $a0, $t3
syscall
move $a0, $t2
syscall
b L5
L6:

li $v0, 10
syscall
