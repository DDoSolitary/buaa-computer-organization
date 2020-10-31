.data
ARR:
.space 6

.text
li $v0, 5
syscall
move $s0, $v0

li $t0, 1
L0:
sb $t0, ARR+-1($t0)
move $a0, $t0
li $v0, 1
syscall
li $a0, 32
li $v0, 11
syscall
addiu $t0, $t0, 1
bleu $t0, $s0, L0
li $a0, 10
li $v0, 11
syscall

L1:
move $t0, $s0
L2:
subiu $t0, $t0, 1
beqz $t0, L6
subu $t1, $t0, 1
lbu $t1, ARR($t1)
lbu $t2, ARR($t0)
bgeu $t1, $t2, L2
move $t2, $s0
L3:
subiu $t2, $t2, 1
lbu $t3, ARR($t2)
bleu $t3, $t1, L3
sb $t3, ARR+-1($t0)
sb $t1, ARR($t2)
move $t1, $t0
subu $t2, $s0, 1
L4:
lbu $t3, ARR($t1)
lbu $t4, ARR($t2)
sb $t3, ARR($t2)
sb $t4, ARR($t1)
addiu $t1, $t1, 1
subiu $t2, $t2, 1
bltu $t1, $t2, L4
li $t1, 0
L5:
lbu $a0, ARR($t1)
li $v0, 1
syscall
li $a0, 32
li $v0, 11
syscall
addiu $t1, $t1, 1
bne $t1, $s0, L5
li $a0, 10
li $v0, 11
syscall
b L1
L6:

li $v0, 10
syscall
