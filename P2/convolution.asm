.data
MAT0:
.space 1600
MAT1:
.space 1600

.macro get_offset(%out, %x, %y, %m)
mulu %out, %x, %m
addu %out, %out, %y
mulu %out, %out, 4
.end_macro

.text
li $v0, 5
syscall
move $s0, $v0
li $v0, 5
syscall
move $s1, $v0
li $v0, 5
syscall
move $s2, $v0
li $v0, 5
syscall
move $s3, $v0

li $t0, 0
loop0_begin:
beq $t0, $s0, loop0_end
li $t1, 0
loop1_begin:
beq $t1, $s1, loop1_end
get_offset($t2, $t0, $t1, $s1)
li $v0, 5
syscall
sh $v0, MAT0($t2)
addiu $t1, $t1, 1
b loop1_begin
loop1_end:
addiu $t0, $t0, 1
b loop0_begin
loop0_end:

li $t0, 0
loop2_begin:
beq $t0, $s2, loop2_end
li $t1, 0
loop3_begin:
beq $t1, $s3, loop3_end
get_offset($t2, $t0, $t1, $s3)
li $v0, 5
syscall
sh $v0, MAT1($t2)
addiu $t1, $t1, 1
b loop3_begin
loop3_end:
addiu $t0, $t0, 1
b loop2_begin
loop2_end:

subu $s4, $s0, $s2
addiu $s4, $s4, 1
subu $s5, $s1, $s3
addiu $s5, $s5, 1

li $t0, 0
loop4_begin:
beq $t0, $s4, loop4_end
li $t1, 0
loop5_begin:
beq $t1, $s5, loop5_end
li $t4, 0
li $t2, 0
loop6_begin:
beq $t2, $s2, loop6_end
li $t3, 0
loop7_begin:
beq $t3, $s3, loop7_end
get_offset($t5, $t2, $t3, $s3)
lhu $t5, MAT1($t5)
addu $t6, $t0, $t2
addu $t7, $t1, $t3
get_offset($t6, $t6, $t7, $s1)
lhu $t6, MAT0($t6)
mulu $t5, $t5, $t6
addu $t4, $t4, $t5
addiu $t3, $t3, 1
b loop7_begin
loop7_end:
addiu $t2, $t2, 1
b loop6_begin
loop6_end:
move $a0, $t4
li $v0, 1
syscall
addiu $t1, $t1, 1
li $a0, 32
bne $t1, $s5, L0
li $a0, 10
L0:
li $v0, 11
syscall
b loop5_begin
loop5_end:
addiu $t0, $t0, 1
b loop4_begin
loop4_end:

li $v0, 10
syscall
