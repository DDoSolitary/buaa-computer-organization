.data

graph:
.align 2
.space 49

vis:
.align 2
.space 7

.macro get_id(%id, %x, %y, %m)
multu %x, %m
mflo %id
addu %id, %id, %y
.end_macro

.text

li $v0, 5
syscall
move $s0, $v0
li $v0, 5
syscall
move $s1, $v0

li $t0, 0
multu $s0, $s0
mflo $t1
init_graph_begin:
bgeu $t0, $t1, init_graph_end
sw $0, graph($t0)
addiu $t0, $t0, 4
j init_graph_begin
init_graph_end:

li $t0, 0
init_vis_begin:
bgeu $t0, $s0, init_vis_end
sw $0, vis($t0)
addiu $t0, $t0, 4
j init_vis_begin
init_vis_end:

li $t0, 0
input_loop_begin:
beq $t0, $s1, input_loop_end
li $v0, 5
syscall
subiu $t1, $v0, 1
li $v0, 5
syscall
subiu $t2, $v0, 1
li $t3, 1
get_id($t4, $t1, $t2, $s0)
sb $t3, graph($t4)
get_id($t4, $t2, $t1, $s0)
sb $t3, graph($t4)
addiu $t0, $t0, 1
j input_loop_begin
input_loop_end:

li $a0, 0
move $a1, $s0
jal dfs
move $a0, $v0
li $v0, 1
syscall

li $v0, 10
syscall

dfs:
subiu $sp, $sp, 4
sw $ra, 4($sp)

li $t0, 1
sb $t0, vis($a0)
li $t1, 0

dfs_loop_begin:
beq $t1, $a1, dfs_loop_end

get_id($t2, $a0, $t1, $a1)
lbu $t2, graph($t2)

bnez $t1, L0
and $t0, $t0, $t2
L0:

lbu $t3, vis($t1)

bnez $t3, L1
li $t0, 0
beqz $t2, L1

subiu $sp, $sp, 12
sw $a0, 12($sp)
sw $t0, 8($sp)
sw $t1, 4($sp)
move $a0, $t1
jal dfs
lw $a0, 12($sp)
lw $t0, 8($sp)
lw $t1, 4($sp)
addiu $sp, $sp, 12

or $t0, $t0, $v0
bnez $v0, dfs_loop_end

L1:
addiu $t1, $t1, 1
j dfs_loop_begin
dfs_loop_end:

lw $ra, 4($sp)
addiu $sp, $sp, 4

sb $0, vis($a0)
move $v0, $t0
jr $ra
