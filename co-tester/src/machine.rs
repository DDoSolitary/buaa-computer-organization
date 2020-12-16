use std::fmt::{self, Display, Formatter};
use std::mem;

use super::log::{GrfLogEntry, MemLogEntry};

pub const WORD_SIZE: usize = mem::size_of::<u32>();
pub const GRF_SIZE: usize = 32;
pub const MEM_SIZE: usize = 1024;
pub const TEXT_START_ADDR: u32 = 0x3000;

#[derive(Debug, Eq, PartialEq, Copy, Clone)]
pub enum MachineState {
	Normal,
	InDelaySlot(u32),
	Branching(u32),
}

pub struct MipsMachine {
	delayed_branching: bool,
	pc: u32,
	state: MachineState,
	grf: Box<[u32; GRF_SIZE]>,
	mem: Box<[u32; MEM_SIZE]>,
	grf_log: Vec<GrfLogEntry>,
	mem_log: Vec<MemLogEntry>,
}

impl MipsMachine {
	pub fn new(delayed_branching: bool) -> Self {
		Self {
			delayed_branching,
			pc: TEXT_START_ADDR,
			state: MachineState::Normal,
			grf: Box::new([0u32; GRF_SIZE]),
			mem: Box::new([0u32; MEM_SIZE]),
			grf_log: Vec::new(),
			mem_log: Vec::new(),
		}
	}

	pub fn pc(&self) -> u32 { self.pc }
	pub fn state(&self) -> MachineState { self.state }
	pub fn grf(&self) -> &[u32; GRF_SIZE] { &self.grf }
	pub fn grf_log(&self) -> &[GrfLogEntry] { &self.grf_log }
	pub fn mem_log(&self) -> &[MemLogEntry] { &self.mem_log }

	fn get_word_addr(addr: u32) -> usize {
		let addr = addr as usize;
		let word_addr = addr / WORD_SIZE;
		debug_assert_eq!(word_addr * WORD_SIZE, addr);
		word_addr
	}

	pub fn execute<T: Instruction + ?Sized>(&mut self, instr: &T) {
		match self.state {
			MachineState::Normal => {
				let res = instr.execute_on(self);
				self.pc += WORD_SIZE as u32;
				match res {
					BranchResult::None => (),
					BranchResult::No => self.state = MachineState::InDelaySlot(self.pc + WORD_SIZE as u32),
					BranchResult::Yes(target) => {
						debug_assert!(target >= self.pc);
						Self::get_word_addr(target);
						if self.delayed_branching {
							self.state = MachineState::InDelaySlot(target);
						} else if target > self.pc {
							self.state = MachineState::Branching(target);
						}
					}
				}
			}
			MachineState::InDelaySlot(target) => {
				debug_assert!(self.delayed_branching);
				let res = instr.execute_on(self);
				debug_assert_eq!(res, BranchResult::None);
				if target == self.pc {
					let res = instr.execute_on(self);
					debug_assert_eq!(res, BranchResult::None);
				}
				self.pc += WORD_SIZE as u32;
				if target <= self.pc {
					self.state = MachineState::Normal
				} else {
					self.state = MachineState::Branching(target)
				}
			}
			MachineState::Branching(target) => {
				self.pc += WORD_SIZE as u32;
				if target == self.pc {
					self.state = MachineState::Normal
				}
			}
		};
	}

	fn read_grf(&self, addr: u8) -> u32 {
		self.grf[addr as usize]
	}

	fn write_grf(&mut self, addr: u8, data: u32) {
		if addr != 0 {
			self.grf[addr as usize] = data;
			self.grf_log.push(GrfLogEntry::new(self.pc, addr, data));
		}
	}

	fn read_mem(&self, addr: u32) -> u32 {
		self.mem[Self::get_word_addr(addr)]
	}

	fn write_mem(&mut self, addr: u32, data: u32) {
		self.mem[Self::get_word_addr(addr)] = data;
		self.mem_log.push(MemLogEntry::new(self.pc, addr, data));
	}
}

fn gen_machine_code_r(op: u8, rs: u8, rt: u8, rd: u8, shamt: u8, func: u8) -> u32 {
	debug_assert!(op < 64);
	debug_assert!(rs < 32);
	debug_assert!(rt < 32);
	debug_assert!(rd < 32);
	debug_assert!(shamt < 32);
	debug_assert!(func < 64);
	(op as u32) << 26 | (rs as u32) << 21 | (rt as u32) << 16 | (rd as u32) << 11 | (shamt as u32) << 6 | func as u32
}

fn gen_machine_code_i(op: u8, rs: u8, rt: u8, imm: u16) -> u32 {
	debug_assert!(op < 64);
	debug_assert!(rs < 32);
	debug_assert!(rt < 32);
	(op as u32) << 26 | (rs as u32) << 21 | (rt as u32) << 16 | imm as u32
}

fn gen_machine_code_j(op: u8, addr: u32) -> u32 {
	debug_assert!(op < 64);
	debug_assert!(addr < 1 << 26);
	(op as u32) << 26 | addr
}

#[derive(Debug, Eq, PartialEq, Copy, Clone)]
pub enum BranchResult {
	None,
	No,
	Yes(u32),
}

pub trait Instruction: Display {
	fn to_machine_code(&self) -> u32;
	fn execute_on(&self, machine: &mut MipsMachine) -> BranchResult;
}

#[derive(Debug, Copy, Clone)]
pub struct NopInstr;

impl Display for NopInstr {
	fn fmt(&self, f: &mut Formatter<'_>) -> std::fmt::Result {
		write!(f, "nop")
	}
}

impl Instruction for NopInstr {
	fn to_machine_code(&self) -> u32 { 0 }
	fn execute_on(&self, _machine: &mut MipsMachine) -> BranchResult { BranchResult::None }
}

#[derive(Debug, Copy, Clone)]
pub struct AdduInstr {
	pub rs: u8,
	pub rt: u8,
	pub rd: u8,
}

impl Display for AdduInstr {
	fn fmt(&self, f: &mut Formatter<'_>) -> fmt::Result {
		write!(f, "addu ${}, ${}, ${}", self.rd, self.rs, self.rt)
	}
}

impl Instruction for AdduInstr {
	fn to_machine_code(&self) -> u32 {
		gen_machine_code_r(0, self.rs, self.rt, self.rd, 0, 0b100001)
	}

	fn execute_on(&self, machine: &mut MipsMachine) -> BranchResult {
		machine.write_grf(
			self.rd,
			u32::wrapping_add(machine.read_grf(self.rs), machine.read_grf(self.rt)),
		);
		BranchResult::None
	}
}

#[derive(Debug, Copy, Clone)]
pub struct SubuInstr {
	pub rs: u8,
	pub rt: u8,
	pub rd: u8,
}

impl Display for SubuInstr {
	fn fmt(&self, f: &mut Formatter<'_>) -> fmt::Result {
		write!(f, "subu ${}, ${}, ${}", self.rd, self.rs, self.rt)
	}
}

impl Instruction for SubuInstr {
	fn to_machine_code(&self) -> u32 {
		gen_machine_code_r(0, self.rs, self.rt, self.rd, 0, 0b100011)
	}

	fn execute_on(&self, machine: &mut MipsMachine) -> BranchResult {
		machine.write_grf(
			self.rd,
			u32::wrapping_sub(machine.read_grf(self.rs), machine.read_grf(self.rt)),
		);
		BranchResult::None
	}
}

#[derive(Debug, Copy, Clone)]
pub struct SllInstr {
	pub rt: u8,
	pub rd: u8,
	pub sa: u8,
}

impl Display for SllInstr {
	fn fmt(&self, f: &mut Formatter<'_>) -> fmt::Result {
		write!(f, "sll ${}, ${}, {}", self.rd, self.rt, self.sa)
	}
}

impl Instruction for SllInstr {
	fn to_machine_code(&self) -> u32 {
		gen_machine_code_r(0, 0, self.rt, self.rd, self.sa, 0b000000)
	}

	fn execute_on(&self, machine: &mut MipsMachine) -> BranchResult {
		machine.write_grf(self.rd, machine.read_grf(self.rt) << self.sa);
		BranchResult::None
	}
}

#[derive(Debug, Copy, Clone)]
pub struct SllvInstr {
	pub rs: u8,
	pub rt: u8,
	pub rd: u8,
}

impl Display for SllvInstr {
	fn fmt(&self, f: &mut Formatter<'_>) -> fmt::Result {
		write!(f, "sllv ${}, ${}, ${}", self.rd, self.rt, self.rs)
	}
}

impl Instruction for SllvInstr {
	fn to_machine_code(&self) -> u32 {
		gen_machine_code_r(0, self.rs, self.rt, self.rd, 0, 0b000100)
	}

	fn execute_on(&self, machine: &mut MipsMachine) -> BranchResult {
		machine.write_grf(self.rd, machine.read_grf(self.rt) << machine.read_grf(self.rs));
		BranchResult::None
	}
}

#[derive(Debug, Copy, Clone)]
pub struct SrlInstr {
	pub rt: u8,
	pub rd: u8,
	pub sa: u8,
}

impl Display for SrlInstr {
	fn fmt(&self, f: &mut Formatter<'_>) -> fmt::Result {
		write!(f, "srl ${}, ${}, {}", self.rd, self.rt, self.sa)
	}
}

impl Instruction for SrlInstr {
	fn to_machine_code(&self) -> u32 {
		gen_machine_code_r(0, 0, self.rt, self.rd, self.sa, 0b000010)
	}

	fn execute_on(&self, machine: &mut MipsMachine) -> BranchResult {
		machine.write_grf(self.rd, machine.read_grf(self.rt) >> self.sa);
		BranchResult::None
	}
}

#[derive(Debug, Copy, Clone)]
pub struct SrlvInstr {
	pub rs: u8,
	pub rt: u8,
	pub rd: u8,
}

impl Display for SrlvInstr {
	fn fmt(&self, f: &mut Formatter<'_>) -> fmt::Result {
		write!(f, "srlv ${}, ${}, ${}", self.rd, self.rt, self.rs)
	}
}

impl Instruction for SrlvInstr {
	fn to_machine_code(&self) -> u32 {
		gen_machine_code_r(0, self.rs, self.rt, self.rd, 0, 0b000110)
	}

	fn execute_on(&self, machine: &mut MipsMachine) -> BranchResult {
		machine.write_grf(self.rd, machine.read_grf(self.rt) >> machine.read_grf(self.rs));
		BranchResult::None
	}
}

#[derive(Debug, Copy, Clone)]
pub struct SraInstr {
	pub rt: u8,
	pub rd: u8,
	pub sa: u8,
}

impl Display for SraInstr {
	fn fmt(&self, f: &mut Formatter<'_>) -> fmt::Result {
		write!(f, "sra ${}, ${}, {}", self.rd, self.rt, self.sa)
	}
}

impl Instruction for SraInstr {
	fn to_machine_code(&self) -> u32 {
		gen_machine_code_r(0, 0, self.rt, self.rd, self.sa, 0b000011)
	}

	fn execute_on(&self, machine: &mut MipsMachine) -> BranchResult {
		machine.write_grf(self.rd, (machine.read_grf(self.rt) as i32 >> self.sa) as u32);
		BranchResult::None
	}
}

#[derive(Debug, Copy, Clone)]
pub struct SravInstr {
	pub rs: u8,
	pub rt: u8,
	pub rd: u8,
}

impl Display for SravInstr {
	fn fmt(&self, f: &mut Formatter<'_>) -> fmt::Result {
		write!(f, "srav ${}, ${}, ${}", self.rd, self.rt, self.rs)
	}
}

impl Instruction for SravInstr {
	fn to_machine_code(&self) -> u32 {
		gen_machine_code_r(0, self.rs, self.rt, self.rd, 0, 0b000111)
	}

	fn execute_on(&self, machine: &mut MipsMachine) -> BranchResult {
		machine.write_grf(
			self.rd,
			(machine.read_grf(self.rt) as i32 >> machine.read_grf(self.rs)) as u32
		);
		BranchResult::None
	}
}

#[derive(Debug, Copy, Clone)]
pub struct AndInstr {
	pub rs: u8,
	pub rt: u8,
	pub rd: u8,
}

impl Display for AndInstr {
	fn fmt(&self, f: &mut Formatter<'_>) -> fmt::Result {
		write!(f, "and ${}, ${}, ${}", self.rd, self.rs, self.rt)
	}
}

impl Instruction for AndInstr {
	fn to_machine_code(&self) -> u32 {
		gen_machine_code_r(0, self.rs, self.rt, self.rd, 0, 0b100100)
	}

	fn execute_on(&self, machine: &mut MipsMachine) -> BranchResult {
		machine.write_grf(
			self.rd,
			machine.read_grf(self.rs) & machine.read_grf(self.rt),
		);
		BranchResult::None
	}
}

#[derive(Debug, Copy, Clone)]
pub struct AndiInstr {
	pub rs: u8,
	pub rt: u8,
	pub imm: u16,
}

impl Display for AndiInstr {
	fn fmt(&self, f: &mut Formatter<'_>) -> fmt::Result {
		write!(f, "andi ${}, ${}, {}", self.rt, self.rs, self.imm)
	}
}

impl Instruction for AndiInstr {
	fn to_machine_code(&self) -> u32 {
		gen_machine_code_i(0b001100, self.rs, self.rt, self.imm)
	}

	fn execute_on(&self, machine: &mut MipsMachine) -> BranchResult {
		machine.write_grf(
			self.rt,
			machine.read_grf(self.rs) & self.imm as u32,
		);
		BranchResult::None
	}
}

#[derive(Debug, Copy, Clone)]
pub struct OrInstr {
	pub rs: u8,
	pub rt: u8,
	pub rd: u8,
}

impl Display for OrInstr {
	fn fmt(&self, f: &mut Formatter<'_>) -> fmt::Result {
		write!(f, "or ${}, ${}, ${}", self.rd, self.rs, self.rt)
	}
}

impl Instruction for OrInstr {
	fn to_machine_code(&self) -> u32 {
		gen_machine_code_r(0, self.rs, self.rt, self.rd, 0, 0b100101)
	}

	fn execute_on(&self, machine: &mut MipsMachine) -> BranchResult {
		machine.write_grf(
			self.rd,
			machine.read_grf(self.rs) | machine.read_grf(self.rt),
		);
		BranchResult::None
	}
}

#[derive(Debug, Copy, Clone)]
pub struct OriInstr {
	pub rs: u8,
	pub rt: u8,
	pub imm: u16,
}

impl Display for OriInstr {
	fn fmt(&self, f: &mut Formatter<'_>) -> fmt::Result {
		write!(f, "ori ${}, ${}, {}", self.rt, self.rs, self.imm)
	}
}

impl Instruction for OriInstr {
	fn to_machine_code(&self) -> u32 {
		gen_machine_code_i(0b001101, self.rs, self.rt, self.imm)
	}

	fn execute_on(&self, machine: &mut MipsMachine) -> BranchResult {
		machine.write_grf(
			self.rt,
			machine.read_grf(self.rs) | self.imm as u32,
		);
		BranchResult::None
	}
}

#[derive(Debug, Copy, Clone)]
pub struct XorInstr {
	pub rs: u8,
	pub rt: u8,
	pub rd: u8,
}

impl Display for XorInstr {
	fn fmt(&self, f: &mut Formatter<'_>) -> fmt::Result {
		write!(f, "xor ${}, ${}, ${}", self.rd, self.rs, self.rt)
	}
}

impl Instruction for XorInstr {
	fn to_machine_code(&self) -> u32 {
		gen_machine_code_r(0, self.rs, self.rt, self.rd, 0, 0b100110)
	}

	fn execute_on(&self, machine: &mut MipsMachine) -> BranchResult {
		machine.write_grf(
			self.rd,
			machine.read_grf(self.rs) ^ machine.read_grf(self.rt),
		);
		BranchResult::None
	}
}

#[derive(Debug, Copy, Clone)]
pub struct XoriInstr {
	pub rs: u8,
	pub rt: u8,
	pub imm: u16,
}

impl Display for XoriInstr {
	fn fmt(&self, f: &mut Formatter<'_>) -> fmt::Result {
		write!(f, "xori ${}, ${}, {}", self.rt, self.rs, self.imm)
	}
}

impl Instruction for XoriInstr {
	fn to_machine_code(&self) -> u32 {
		gen_machine_code_i(0b001110, self.rs, self.rt, self.imm)
	}

	fn execute_on(&self, machine: &mut MipsMachine) -> BranchResult {
		machine.write_grf(
			self.rt,
			machine.read_grf(self.rs) ^ self.imm as u32,
		);
		BranchResult::None
	}
}

#[derive(Debug, Copy, Clone)]
pub struct NorInstr {
	pub rs: u8,
	pub rt: u8,
	pub rd: u8,
}

impl Display for NorInstr {
	fn fmt(&self, f: &mut Formatter<'_>) -> fmt::Result {
		write!(f, "nor ${}, ${}, ${}", self.rd, self.rs, self.rt)
	}
}

impl Instruction for NorInstr {
	fn to_machine_code(&self) -> u32 {
		gen_machine_code_r(0, self.rs, self.rt, self.rd, 0, 0b100111)
	}

	fn execute_on(&self, machine: &mut MipsMachine) -> BranchResult {
		machine.write_grf(
			self.rd,
			!(machine.read_grf(self.rs) | machine.read_grf(self.rt)),
		);
		BranchResult::None
	}
}

#[derive(Debug, Copy, Clone)]
pub struct LuiInstr {
	pub rt: u8,
	pub imm: u16,
}

impl Display for LuiInstr {
	fn fmt(&self, f: &mut Formatter<'_>) -> fmt::Result {
		write!(f, "lui ${}, {}", self.rt, self.imm)
	}
}

impl Instruction for LuiInstr {
	fn to_machine_code(&self) -> u32 {
		gen_machine_code_i(0b001111, 0, self.rt, self.imm)
	}

	fn execute_on(&self, machine: &mut MipsMachine) -> BranchResult {
		machine.write_grf(self.rt, (self.imm as u32) << 16);
		BranchResult::None
	}
}

#[derive(Debug, Copy, Clone)]
pub struct LwInstr {
	pub base: u8,
	pub rt: u8,
	pub offset: i16,
}

impl Display for LwInstr {
	fn fmt(&self, f: &mut Formatter<'_>) -> fmt::Result {
		write!(f, "lw ${}, {}(${})", self.rt, self.offset, self.base)
	}
}

impl Instruction for LwInstr {
	fn to_machine_code(&self) -> u32 {
		gen_machine_code_i(0b100011, self.base, self.rt, self.offset as u16)
	}

	fn execute_on(&self, machine: &mut MipsMachine) -> BranchResult {
		let addr = u32::wrapping_add(machine.read_grf(self.base), self.offset as u32);
		machine.write_grf(self.rt, machine.read_mem(addr));
		BranchResult::None
	}
}

#[derive(Debug, Copy, Clone)]
pub struct SwInstr {
	pub base: u8,
	pub rt: u8,
	pub offset: i16,
}

impl Display for SwInstr {
	fn fmt(&self, f: &mut Formatter<'_>) -> fmt::Result {
		write!(f, "sw ${}, {}(${})", self.rt, self.offset, self.base)
	}
}

impl Instruction for SwInstr {
	fn to_machine_code(&self) -> u32 {
		gen_machine_code_i(0b101011, self.base, self.rt, self.offset as u16)
	}

	fn execute_on(&self, machine: &mut MipsMachine) -> BranchResult {
		let addr = u32::wrapping_add(machine.read_grf(self.base), self.offset as u32);
		machine.write_mem(addr, machine.read_grf(self.rt));
		BranchResult::None
	}
}

#[derive(Debug, Copy, Clone)]
pub struct BeqInstr {
	pub rs: u8,
	pub rt: u8,
	pub offset: i16,
}

impl Display for BeqInstr {
	fn fmt(&self, f: &mut Formatter<'_>) -> fmt::Result {
		write!(f, "beq ${}, ${}, {}", self.rs, self.rt, self.offset)
	}
}

impl Instruction for BeqInstr {
	fn to_machine_code(&self) -> u32 {
		gen_machine_code_i(0b000100, self.rs, self.rt, self.offset as u16)
	}

	fn execute_on(&self, machine: &mut MipsMachine) -> BranchResult {
		if machine.read_grf(self.rs) == machine.read_grf(self.rt) {
			let addr = u32::wrapping_add(
				machine.pc(),
				u32::wrapping_mul(self.offset as u32, WORD_SIZE as u32),
			);
			let addr = u32::wrapping_add(addr, WORD_SIZE as u32);
			BranchResult::Yes(addr)
		} else {
			BranchResult::No
		}
	}
}

const PC_MUSK: u32 = u32::max_value() >> 28 << 28;

#[derive(Debug, Copy, Clone)]
pub struct JInstr {
	pub addr: u32,
}

impl Display for JInstr {
	fn fmt(&self, f: &mut Formatter<'_>) -> fmt::Result {
		write!(f, "j {}", self.addr)
	}
}

impl Instruction for JInstr {
	fn to_machine_code(&self) -> u32 {
		gen_machine_code_j(0b000010, self.addr)
	}

	fn execute_on(&self, machine: &mut MipsMachine) -> BranchResult {
		debug_assert!(self.addr < 1 << 26);
		BranchResult::Yes(machine.pc() & PC_MUSK | (self.addr * WORD_SIZE as u32))
	}
}

#[derive(Debug, Copy, Clone)]
pub struct JalInstr {
	pub addr: u32,
}

impl Display for JalInstr {
	fn fmt(&self, f: &mut Formatter<'_>) -> fmt::Result {
		write!(f, "jal {}", self.addr)
	}
}

impl Instruction for JalInstr {
	fn to_machine_code(&self) -> u32 {
		gen_machine_code_j(0b000011, self.addr)
	}

	fn execute_on(&self, machine: &mut MipsMachine) -> BranchResult {
		machine.write_grf(31, machine.pc() + WORD_SIZE as u32 * 2);
		debug_assert!(self.addr < 1 << 26);
		BranchResult::Yes(machine.pc() & PC_MUSK | (self.addr * WORD_SIZE as u32))
	}
}

pub struct JrInstr {
	pub rs: u8,
}

impl Display for JrInstr {
	fn fmt(&self, f: &mut Formatter<'_>) -> fmt::Result {
		write!(f, "jr ${}", self.rs)
	}
}

impl Instruction for JrInstr {
	fn to_machine_code(&self) -> u32 {
		gen_machine_code_r(0, self.rs, 0, 0, 0, 0b001000)
	}

	fn execute_on(&self, machine: &mut MipsMachine) -> BranchResult {
		BranchResult::Yes(machine.read_grf(self.rs))
	}
}
