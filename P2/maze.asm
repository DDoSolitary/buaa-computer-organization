.data
MAP:
.space 49
VIS:
.space 49

.text
li $v0, 5
syscall
move $s0, $v0
li $v0, 5
syscall
move $s1, $v0

li $t0, 0
L0:
li $t1, 0
L1:
li $v0, 5
syscall
mulu $t2, $t0, $s1
addu $t2, $t2, $t1
sb $v0, MAP($t2)
sb $0, VIS($t2)
addiu $t1, $t1, 1
bne $t1, $s1, L1
addiu $t0, $t0, 1
bne $t0, $s0, L0

li $v0, 5
syscall
subu $a0, $v0, 1
li $v0, 5
syscall
subu $a1, $v0, 1
li $v0, 5
syscall
subu $s2, $v0, 1
li $v0, 5
syscall
subu $s3, $v0, 1
jal dfs
move $a0, $v0
li $v0, 1
syscall

li $v0, 10
syscall

dfs:
bgeu $a0, $s0, L2
bgeu $a1, $s1, L2
mulu $t0, $a0, $s1
addu $t0, $t0, $a1
lbu $t1, VIS($t0)
bnez $t1, L2
lbu $t1, MAP($t0)
bnez $t1, L2
b L3
L2:
li $v0, 0
jr $ra
L3:
bne $a0, $s2, L4
bne $a1, $s3, L4
li $v0, 1
jr $ra
L4:
li $t1, 1
sb $t1, VIS($t0)
subiu $sp, $sp, 8
sw $ra, 4($sp)
sw $s4, ($sp)
li $s4, 0
addiu $a0, $a0, 1
jal dfs
addu $s4, $s4, $v0
subiu $a0, $a0, 2
jal dfs
addu $s4, $s4, $v0
addiu $a0, $a0, 1
addiu $a1, $a1, 1
jal dfs
addu $s4, $s4, $v0
subiu $a1, $a1, 2
jal dfs
addu $v0, $v0, $s4
addiu $a1, $a1, 1
mulu $t0, $a0, $s1
addu $t0, $t0, $a1
sb $zero, VIS($t0)
lw $ra, 4($sp)
lw $s4, ($sp)
addiu $sp, $sp, 8
jr $ra
