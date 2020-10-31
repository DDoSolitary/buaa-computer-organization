.data
MAT0:
.space 64
MAT1:
.space 64
MAT2:
.space 128

.macro get_id(%out, %x, %y, %n)
mulu %out, %x, %n
addu %out, %out, %y
.end_macro

.text
li $v0, 5
syscall
move $s0, $v0
la $a0, MAT0
move $a1, $s0
la $a2, read_ele
jal loop_mat
la $a0, MAT1
move $a1, $s0
la $a2, read_ele
jal loop_mat
la $a0, MAT2
move $a1, $s0
la $a2, calc
jal loop_mat
la $a0, MAT2
move $a1, $s0
la $a2, print
jal loop_mat
li $v0, 10
syscall

loop_mat: # $a0: mat, $a1: n, $a2: op(mat, n, i, j)
subiu, $sp, $sp, 24
sw $ra, 20($sp)
sw $s0, 16($sp)
sw $s1, 12($sp)
sw $s2, 8($sp)
sw $s3, 4($sp)
sw $s4, ($sp)
move $s0, $a0
move $s1, $a1
move $s2, $a2
li $s3, 0
loop0_begin:
beq $s3, $s1, loop0_end
li $s4, 0
loop1_begin:
beq $s4, $s1, loop1_end
move $a0, $s0
move $a1, $s1
move $a2, $s3
move $a3, $s4
jalr $s2
addiu $s4, $s4, 1
b loop1_begin
loop1_end:
addiu $s3, $s3, 1
b loop0_begin
loop0_end:
lw $ra, 20($sp)
lw $s0, 16($sp)
lw $s1, 12($sp)
lw $s2, 8($sp)
lw $s3, 4($sp)
lw $s4, ($sp)
addiu $sp, $sp, 24
jr $ra

read_ele: # $a0: mat, $a1: n, $a2: i, $a3: j
get_id($t0, $a2, $a3, $a1)
addu $t0, $t0, $a0
li $v0, 5
syscall
sb $v0, ($t0)
jr $ra

calc: # $a0: mat, $a1: n, $a2: i, $a3: j
li $t0, 0
loop2_begin:
beq $t0, $a1, loop2_end
get_id($t1, $a2, $t0, $a1)
lbu $t1, MAT0($t1)
get_id($t2, $t0, $a3, $a1)
lbu $t2, MAT1($t2)
mulu $t1, $t1, $t2
get_id($t2, $a2, $a3, $a1)
mulu $t2, $t2, 2
addu $t2, $t2, $a0
lhu $t3, ($t2)
addu $t1, $t1, $t3
sh $t1, ($t2)
addiu $t0, $t0, 1
b loop2_begin
loop2_end:
jr $ra

print: # $a0: mat, $a1: n, $a2: i, $a3: j
get_id($t0, $a2, $a3, $a1)
mulu $t0, $t0, 2
addu $t0, $t0, $a0
lhu $a0, ($t0)
li $v0, 1
syscall
li $a0, 32
subu $t0, $a1, $a3
bne $t0, 1, L0
li $a0, 10
L0:
li $v0, 11
syscall
jr $ra
