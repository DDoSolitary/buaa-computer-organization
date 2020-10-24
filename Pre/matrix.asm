li $v0, 5
syscall
move $s0, $v0
li $v0, 5
syscall
move $s1, $v0

li $s2, 0
li $t0, 0
loop0_begin:
beq $t0, $s0, loop0_end
li $t1, 0
loop1_begin:
beq $t1, $s1, loop1_end
li $v0, 5
syscall
move $t2, $v0
beqz $t2, L0
addiu $s2, $s2, 1
subiu $sp, $sp, 12
addiu $t3, $t0, 1
sw $t3, 8($sp)
addiu $t3, $t1, 1
sw $t3, 4($sp)
sw $t2, ($sp)
L0:
addiu $t1, $t1, 1
j loop1_begin
loop1_end:
addiu $t0, $t0, 1
j loop0_begin
loop0_end:

li $t0, 0
loop2_begin:
beq $t0, $s2, loop2_end
lw $a0, 8($sp)
li $v0, 1
syscall
li $a0, ' '
li $v0, 11
syscall
lw $a0, 4($sp)
li $v0, 1
syscall
li $a0, ' '
li $v0, 11
syscall
lw $a0, ($sp)
li $v0, 1
syscall
li $a0, '\n'
li $v0, 11
syscall
addiu $sp, $sp, 12
addiu $t0, $t0, 1
j loop2_begin
loop2_end:

li $v0, 10
syscall
