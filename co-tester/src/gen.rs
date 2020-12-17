use rand::prelude::*;
use rand::rngs::ThreadRng;
use rand_distr::{Normal, Uniform};
use strum_macros::{AsStaticStr, EnumIter, EnumString, EnumVariantNames};
use super::machine::*;

#[derive(Debug, Copy, Clone, Eq, PartialEq, AsStaticStr, EnumIter, EnumString, EnumVariantNames)]
#[strum(serialize_all = "kebab_case")]
pub enum InstructionType {
	Nop,
	Add,
	Addi,
	Addu,
	Addiu,
	Sub,
	Subu,
	Sll,
	Sllv,
	Srl,
	Srlv,
	Sra,
	Srav,
	And,
	Andi,
	Or,
	Ori,
	Xor,
	Xori,
	Nor,
	Lui,
	Lb,
	Lbu,
	Lh,
	Lhu,
	Lw,
	Sb,
	Sh,
	Sw,
	Slt,
	Slti,
	Sltu,
	Sltiu,
	Beq,
	Bne,
	Blez,
	Bltz,
	Bgez,
	Bgtz,
	J,
	Jal,
	Jr,
	Jalr,
	Mult,
	Multu,
	Div,
	Divu,
	Mflo,
	Mfhi,
	Mtlo,
	Mthi,
}

impl InstructionType {
	fn is_branch(&self) -> bool {
		matches!(self, Self::Beq | Self::Bne | Self::Blez | Self::Bltz | Self::Bgez | Self::Bgtz | Self::J | Self::Jal | Self::Jr | Self::Jalr)
	}
}

trait RngExt {
	fn rand_select<'a, 'b, T>(&'a mut self, data: &'b [T]) -> &'b T;
}

impl<T: Rng> RngExt for T {
	fn rand_select<'a, 'b, U>(&'a mut self, data: &'b [U]) -> &'b U {
		&data[self.gen_range(0, data.len())]
	}
}

pub struct InstructionGenerator<'a> {
	machine: &'a mut MipsMachine,
	instr_set: &'a [InstructionType],
	instr_set_no_branch: Vec<InstructionType>,
	text_limit: u32,
	rng: ThreadRng,
	grf_addr_dist: Uniform<u8>,
	grf_addr_excluded_dist: Uniform<u8>,
	mem_addr_dist: Uniform<u32>,
	imm_dist: Uniform<u16>,
	branch_dist: Normal<f64>,
}

impl<'a> InstructionGenerator<'a> {
	pub fn new(machine: &'a mut MipsMachine, instr_set: &'a [InstructionType], instr_count: u32) -> Self {
		Self {
			machine,
			instr_set,
			instr_set_no_branch: instr_set.iter()
				.filter_map(|x| if x.is_branch() { None } else { Some(*x) })
				.collect(),
			text_limit: TEXT_START_ADDR + instr_count * WORD_SIZE as u32,
			rng: rand::thread_rng(),
			grf_addr_dist: Uniform::new(0, GRF_SIZE as u8),
			grf_addr_excluded_dist: Uniform::new(0, GRF_SIZE as u8 - 1),
			mem_addr_dist: Uniform::new(0, (MEM_SIZE * WORD_SIZE) as u32),
			imm_dist: Uniform::new_inclusive(0, u16::max_value()),
			branch_dist: Normal::new(0f64, 5f64).unwrap(),
		}
	}

	fn grf_last_written(&self) -> Option<u8> {
		self.machine.grf_log().last().map(|log| log.addr())
	}

	fn gen_grf_read_addr(&mut self, exclude_addr: Option<u8>) -> u8 {
		let last_written = self.grf_last_written();
		if let (Some(last_written), true) = (last_written, self.rng.gen_bool(0.5)) {
			if exclude_addr != Some(last_written) {
				return last_written;
			}
		}
		if let Some(exclude_addr) = exclude_addr {
			let addr = self.rng.sample(&self.grf_addr_excluded_dist);
			if addr >= exclude_addr { addr + 1 } else { addr }
		} else {
			self.rng.sample(&self.grf_addr_dist)
		}
	}

	fn gen_mem_read_addr(&mut self) -> u32 {
		let last_written = self.machine.mem_log().last().map(|log| log.addr());
		if let (Some(last_written), true) = (last_written, self.rng.gen_bool(0.3)) {
			last_written
		} else {
			self.rng.sample(&self.mem_addr_dist)
		}
	}

	fn gen_base_and_offset(&mut self, addr_mask: u32) -> (u8, i16) {
		let addr = self.gen_mem_read_addr() & addr_mask;
		let candidates = self.machine.grf().iter().enumerate().filter_map(|(id, value)| {
			let offset = addr as i64 - *value as i64;
			let offset_i16 = offset as i16;
			if offset_i16 as i64 == offset {
				Some((id as u8, offset_i16))
			} else {
				None
			}
		}).collect::<Vec<_>>();
		let last_written = self.grf_last_written()
			.and_then(|x| candidates.iter().find(|(y, _)| x == *y));
		if let (Some(last_written), true) = (last_written, self.rng.gen_bool(0.5)) {
			*last_written
		} else {
			*self.rng.rand_select(&candidates)
		}
	}

	fn gen_branch_offset(&mut self) -> i16 {
		let offset = (self.rng.sample(&self.branch_dist) as i16).abs();
		let addr = self.machine.pc() + (offset as u32 + 1) * WORD_SIZE as u32;
		if addr < self.text_limit {
			offset
		} else {
			((self.text_limit - self.machine.pc() - 1) / WORD_SIZE as u32) as i16
		}
	}

	fn gen_jump_addr(&mut self) -> u32 {
		self.machine.pc() / WORD_SIZE as u32 + self.gen_branch_offset() as u32 + 1
	}

	fn gen_grf_load_addr(&mut self, base: u8) -> u8 {
		if self.machine.state() == MachineState::InDelaySlot(self.machine.pc()) {
			let addr = self.rng.sample(&self.grf_addr_excluded_dist);
			if addr >= base { addr + 1 } else { addr }
		} else {
			self.rng.sample(&self.grf_addr_dist)
		}
	}
}

impl Iterator for InstructionGenerator<'_> {
	type Item = Box<dyn Instruction>;

	fn next(&mut self) -> Option<Self::Item> {
		if self.machine.pc() >= self.text_limit { return None; }
		let jr_candidates = self.machine.grf().iter().enumerate()
			.filter_map(|(i, x)| {
				let is_in_range = (self.machine.pc() + 1..self.text_limit).contains(x);
				let is_aligned = x / WORD_SIZE as u32 * WORD_SIZE as u32 == *x;
				if is_in_range && is_aligned { Some(i as u8) } else { None }
			})
			.collect::<Vec<_>>();
		let is_last_instr = self.machine.pc() + WORD_SIZE as u32 == self.text_limit;
		let instr_type = match (self.machine.state(), is_last_instr) {
			(MachineState::InDelaySlot(_), _) | (_, true) => *self.rng.rand_select(&self.instr_set_no_branch),
			_ => {
				if jr_candidates.is_empty() {
					let instr_set = self.instr_set.iter()
						.filter(|x| !matches!(x, InstructionType::Jr | InstructionType::Jalr)).collect::<Vec<_>>();
					**self.rng.rand_select(&instr_set)
				} else {
					*self.rng.rand_select(self.instr_set)
				}
			}
		};
		let instr: Box<dyn Instruction> = match instr_type {
			InstructionType::Nop => Box::new(NopInstr),
			InstructionType::Add => Box::new(AddInstr {
				rs: self.gen_grf_read_addr(None),
				rt: self.gen_grf_read_addr(None),
				rd: self.rng.sample(&self.grf_addr_dist),
			}),
			InstructionType::Addi => Box::new(AddiInstr {
				rs: self.gen_grf_read_addr(None),
				rt: self.rng.sample(&self.grf_addr_dist),
				imm: self.rng.sample(&self.imm_dist) as i16,
			}),
			InstructionType::Addu => Box::new(AdduInstr {
				rs: self.gen_grf_read_addr(None),
				rt: self.gen_grf_read_addr(None),
				rd: self.rng.sample(&self.grf_addr_dist),
			}),
			InstructionType::Addiu => Box::new(AddiuInstr {
				rs: self.gen_grf_read_addr(None),
				rt: self.rng.sample(&self.grf_addr_dist),
				imm: self.rng.sample(&self.imm_dist) as i16,
			}),
			InstructionType::Sub => Box::new(SubInstr {
				rs: self.gen_grf_read_addr(None),
				rt: self.gen_grf_read_addr(None),
				rd: self.rng.sample(&self.grf_addr_dist),
			}),
			InstructionType::Subu => Box::new(SubuInstr {
				rs: self.gen_grf_read_addr(None),
				rt: self.gen_grf_read_addr(None),
				rd: self.rng.sample(&self.grf_addr_dist),
			}),
			InstructionType::Sll => Box::new(SllInstr {
				rt: self.gen_grf_read_addr(None),
				rd: self.rng.sample(&self.grf_addr_dist),
				sa: self.rng.gen_range(0, 32),
			}),
			InstructionType::Sllv => Box::new(SllvInstr {
				rs: self.gen_grf_read_addr(None),
				rt: self.gen_grf_read_addr(None),
				rd: self.rng.sample(&self.grf_addr_dist),
			}),
			InstructionType::Srl => Box::new(SrlInstr {
				rt: self.gen_grf_read_addr(None),
				rd: self.rng.sample(&self.grf_addr_dist),
				sa: self.rng.gen_range(0, 32),
			}),
			InstructionType::Srlv => Box::new(SrlvInstr {
				rs: self.gen_grf_read_addr(None),
				rt: self.gen_grf_read_addr(None),
				rd: self.rng.sample(&self.grf_addr_dist),
			}),
			InstructionType::Sra => Box::new(SraInstr {
				rt: self.gen_grf_read_addr(None),
				rd: self.rng.sample(&self.grf_addr_dist),
				sa: self.rng.gen_range(0, 32),
			}),
			InstructionType::Srav => Box::new(SravInstr {
				rs: self.gen_grf_read_addr(None),
				rt: self.gen_grf_read_addr(None),
				rd: self.rng.sample(&self.grf_addr_dist),
			}),
			InstructionType::Slt => Box::new(SltInstr {
				rs: self.gen_grf_read_addr(None),
				rt: self.gen_grf_read_addr(None),
				rd: self.rng.sample(&self.grf_addr_dist),
			}),
			InstructionType::Slti => Box::new(SltiInstr {
				rs: self.gen_grf_read_addr(None),
				rt: self.rng.sample(&self.grf_addr_dist),
				imm: self.rng.sample(&self.imm_dist) as i16,
			}),
			InstructionType::Sltu => Box::new(SltuInstr {
				rs: self.gen_grf_read_addr(None),
				rt: self.gen_grf_read_addr(None),
				rd: self.rng.sample(&self.grf_addr_dist),
			}),
			InstructionType::Sltiu => Box::new(SltiuInstr {
				rs: self.gen_grf_read_addr(None),
				rt: self.rng.sample(&self.grf_addr_dist),
				imm: self.rng.sample(&self.imm_dist) as i16,
			}),
			InstructionType::And => Box::new(AndInstr {
				rs: self.gen_grf_read_addr(None),
				rt: self.gen_grf_read_addr(None),
				rd: self.rng.sample(&self.grf_addr_dist),
			}),
			InstructionType::Andi => Box::new(AndiInstr {
				rs: self.gen_grf_read_addr(None),
				rt: self.rng.sample(&self.grf_addr_dist),
				imm: self.rng.sample(&self.imm_dist),
			}),
			InstructionType::Or => Box::new(OrInstr {
				rs: self.gen_grf_read_addr(None),
				rt: self.gen_grf_read_addr(None),
				rd: self.rng.sample(&self.grf_addr_dist),
			}),
			InstructionType::Ori => Box::new(OriInstr {
				rs: self.gen_grf_read_addr(None),
				rt: self.rng.sample(&self.grf_addr_dist),
				imm: self.rng.sample(&self.imm_dist),
			}),
			InstructionType::Xor => Box::new(XorInstr {
				rs: self.gen_grf_read_addr(None),
				rt: self.gen_grf_read_addr(None),
				rd: self.rng.sample(&self.grf_addr_dist),
			}),
			InstructionType::Xori => Box::new(XoriInstr {
				rs: self.gen_grf_read_addr(None),
				rt: self.rng.sample(&self.grf_addr_dist),
				imm: self.rng.sample(&self.imm_dist),
			}),
			InstructionType::Nor => Box::new(NorInstr {
				rs: self.gen_grf_read_addr(None),
				rt: self.gen_grf_read_addr(None),
				rd: self.rng.sample(&self.grf_addr_dist),
			}),
			InstructionType::Lui => Box::new(LuiInstr {
				rt: self.rng.sample(&self.grf_addr_dist),
				imm: self.rng.sample(&self.imm_dist),
			}),
			InstructionType::Lb => {
				let (base, offset) = self.gen_base_and_offset(!0);
				Box::new(LbInstr {
					base,
					rt: self.gen_grf_load_addr(base),
					offset,
				})
			}
			InstructionType::Lbu => {
				let (base, offset) = self.gen_base_and_offset(!0);
				Box::new(LbuInstr {
					base,
					rt: self.gen_grf_load_addr(base),
					offset,
				})
			}
			InstructionType::Lh => {
				let (base, offset) = self.gen_base_and_offset(!0b1);
				Box::new(LhInstr {
					base,
					rt: self.gen_grf_load_addr(base),
					offset,
				})
			}
			InstructionType::Lhu => {
				let (base, offset) = self.gen_base_and_offset(!0b1);
				Box::new(LhuInstr {
					base,
					rt: self.gen_grf_load_addr(base),
					offset,
				})
			}
			InstructionType::Lw => {
				let (base, offset) = self.gen_base_and_offset(!0b11);
				Box::new(LwInstr {
					base,
					rt: self.gen_grf_load_addr(base),
					offset,
				})
			}
			InstructionType::Sb => {
				let (base, offset) = self.gen_base_and_offset(!0);
				Box::new(SbInstr {
					base,
					rt: self.gen_grf_read_addr(None),
					offset,
				})
			}
			InstructionType::Sh => {
				let (base, offset) = self.gen_base_and_offset(!0b1);
				Box::new(SbInstr {
					base,
					rt: self.gen_grf_read_addr(None),
					offset,
				})
			}
			InstructionType::Sw => {
				let (base, offset) = self.gen_base_and_offset(!0b11);
				Box::new(SwInstr {
					base,
					rt: self.gen_grf_read_addr(None),
					offset,
				})
			}
			InstructionType::Beq => Box::new(BeqInstr {
				rs: self.gen_grf_read_addr(None),
				rt: self.gen_grf_read_addr(None),
				offset: self.gen_branch_offset(),
			}),
			InstructionType::Bne => Box::new(BneInstr {
				rs: self.gen_grf_read_addr(None),
				rt: self.gen_grf_read_addr(None),
				offset: self.gen_branch_offset(),
			}),
			InstructionType::Blez => Box::new(BlezInstr {
				rs: self.gen_grf_read_addr(None),
				offset: self.gen_branch_offset(),
			}),
			InstructionType::Bltz => Box::new(BltzInstr {
				rs: self.gen_grf_read_addr(None),
				offset: self.gen_branch_offset(),
			}),
			InstructionType::Bgez => Box::new(BgezInstr {
				rs: self.gen_grf_read_addr(None),
				offset: self.gen_branch_offset(),
			}),
			InstructionType::Bgtz => Box::new(BgtzInstr {
				rs: self.gen_grf_read_addr(None),
				offset: self.gen_branch_offset(),
			}),
			InstructionType::J => Box::new(JInstr {
				addr: self.gen_jump_addr(),
			}),
			InstructionType::Jal => Box::new(JalInstr {
				addr: self.gen_jump_addr(),
			}),
			InstructionType::Jr => Box::new(JrInstr {
				rs: *self.rng.rand_select(&jr_candidates),
			}),
			InstructionType::Jalr => {
				let rs = *self.rng.rand_select(&jr_candidates);
				Box::new(JalrInstr {
					rs,
					rd: self.gen_grf_read_addr(Some(rs)),
				})
			},
			InstructionType::Mult => Box::new(MultInstr {
				rs: self.gen_grf_read_addr(None),
				rt: self.gen_grf_read_addr(None),
			}),
			InstructionType::Multu => Box::new(MultuInstr {
				rs: self.gen_grf_read_addr(None),
				rt: self.gen_grf_read_addr(None),
			}),
			InstructionType::Div => Box::new(DivInstr {
				rs: self.gen_grf_read_addr(None),
				rt: self.gen_grf_read_addr(None),
			}),
			InstructionType::Divu => Box::new(DivuInstr {
				rs: self.gen_grf_read_addr(None),
				rt: self.gen_grf_read_addr(None),
			}),
			InstructionType::Mflo => Box::new(MfloInstr {
				rd: self.rng.sample(&self.grf_addr_dist),
			}),
			InstructionType::Mfhi => Box::new(MfhiInstr {
				rd: self.rng.sample(&self.grf_addr_dist),
			}),
			InstructionType::Mtlo => Box::new(MtloInstr {
				rs: self.gen_grf_read_addr(None),
			}),
			InstructionType::Mthi => Box::new(MthiInstr {
				rs: self.gen_grf_read_addr(None),
			}),
		};
		self.machine.execute(&*instr);
		Some(instr)
	}
}
