.data
STR:
.space 20

.text
li $v0, 5
syscall
move $s0, $v0
li $t0, 0
loop0_begin:
beq $t0, $s0, loop0_end
li $v0, 12
syscall
sb $v0, STR($t0)
addiu $t0, $t0, 1
b loop0_begin
loop0_end:
li $s3, 1
divu $s1, $s0, 2
li $t0, 0
loop1_begin:
beq $t0, $s1, loop1_end
lbu $t1, STR($t0)
subu $t2, $s0, $t0
subiu $t2, $t2, 1
lbu $t2, STR($t2)
beq $t1, $t2, L0
li $s3, 0
L0:
addiu $t0, $t0, 1
b loop1_begin
loop1_end:
addu $a0, $s3, 48
li $v0, 11
syscall
li $v0, 10
syscall
