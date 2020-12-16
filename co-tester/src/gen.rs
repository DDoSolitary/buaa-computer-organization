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
	Lw,
	Sw,
	Beq,
	J,
	Jal,
	Jr,
}

impl InstructionType {
	fn is_branch(&self) -> bool {
		matches!(self, Self::Beq | Self::J | Self::Jal | Self::Jr)
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
			mem_addr_dist: Uniform::new(0, (MEM_SIZE * WORD_SIZE) as u32),
			imm_dist: Uniform::new_inclusive(0, u16::max_value()),
			branch_dist: Normal::new(0f64, 5f64).unwrap(),
		}
	}

	fn grf_last_written(&self) -> Option<u8> {
		self.machine.grf_log().last().map(|log| log.addr())
	}

	fn gen_grf_read_addr(&mut self) -> u8 {
		let last_written = self.grf_last_written();
		if let (Some(last_written), true) = (last_written, self.rng.gen_bool(0.5)) {
			last_written
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
						.filter(|x| !matches!(x, InstructionType::Jr)).collect::<Vec<_>>();
					**self.rng.rand_select(&instr_set)
				} else {
					*self.rng.rand_select(self.instr_set)
				}
			}
		};
		let instr: Box<dyn Instruction> = match instr_type {
			InstructionType::Nop => Box::new(NopInstr),
			InstructionType::Add => Box::new(AddInstr {
				rs: self.gen_grf_read_addr(),
				rt: self.gen_grf_read_addr(),
				rd: self.rng.sample(&self.grf_addr_dist),
			}),
			InstructionType::Addi => Box::new(AddiInstr {
				rs: self.gen_grf_read_addr(),
				rt: self.rng.sample(&self.grf_addr_dist),
				imm: self.rng.sample(&self.imm_dist) as i16,
			}),
			InstructionType::Addu => Box::new(AdduInstr {
				rs: self.gen_grf_read_addr(),
				rt: self.gen_grf_read_addr(),
				rd: self.rng.sample(&self.grf_addr_dist),
			}),
			InstructionType::Addiu => Box::new(AddiuInstr {
				rs: self.gen_grf_read_addr(),
				rt: self.rng.sample(&self.grf_addr_dist),
				imm: self.rng.sample(&self.imm_dist),
			}),
			InstructionType::Sub => Box::new(SubInstr {
				rs: self.gen_grf_read_addr(),
				rt: self.gen_grf_read_addr(),
				rd: self.rng.sample(&self.grf_addr_dist),
			}),
			InstructionType::Subu => Box::new(SubuInstr {
				rs: self.gen_grf_read_addr(),
				rt: self.gen_grf_read_addr(),
				rd: self.rng.sample(&self.grf_addr_dist),
			}),
			InstructionType::Sll => Box::new(SllInstr {
				rt: self.gen_grf_read_addr(),
				rd: self.rng.sample(&self.grf_addr_dist),
				sa: self.rng.gen_range(0, 32),
			}),
			InstructionType::Sllv => Box::new(SllvInstr {
				rs: self.gen_grf_read_addr(),
				rt: self.gen_grf_read_addr(),
				rd: self.rng.sample(&self.grf_addr_dist),
			}),
			InstructionType::Srl => Box::new(SrlInstr {
				rt: self.gen_grf_read_addr(),
				rd: self.rng.sample(&self.grf_addr_dist),
				sa: self.rng.gen_range(0, 32),
			}),
			InstructionType::Srlv => Box::new(SrlvInstr {
				rs: self.gen_grf_read_addr(),
				rt: self.gen_grf_read_addr(),
				rd: self.rng.sample(&self.grf_addr_dist),
			}),
			InstructionType::Sra => Box::new(SraInstr {
				rt: self.gen_grf_read_addr(),
				rd: self.rng.sample(&self.grf_addr_dist),
				sa: self.rng.gen_range(0, 32),
			}),
			InstructionType::Srav => Box::new(SravInstr {
				rs: self.gen_grf_read_addr(),
				rt: self.gen_grf_read_addr(),
				rd: self.rng.sample(&self.grf_addr_dist),
			}),
			InstructionType::And => Box::new(AndInstr {
				rs: self.gen_grf_read_addr(),
				rt: self.gen_grf_read_addr(),
				rd: self.rng.sample(&self.grf_addr_dist),
			}),
			InstructionType::Andi => Box::new(AndiInstr {
				rs: self.gen_grf_read_addr(),
				rt: self.rng.sample(&self.grf_addr_dist),
				imm: self.rng.sample(&self.imm_dist),
			}),
			InstructionType::Or => Box::new(OrInstr {
				rs: self.gen_grf_read_addr(),
				rt: self.gen_grf_read_addr(),
				rd: self.rng.sample(&self.grf_addr_dist),
			}),
			InstructionType::Ori => Box::new(OriInstr {
				rs: self.gen_grf_read_addr(),
				rt: self.rng.sample(&self.grf_addr_dist),
				imm: self.rng.sample(&self.imm_dist),
			}),
			InstructionType::Xor => Box::new(XorInstr {
				rs: self.gen_grf_read_addr(),
				rt: self.gen_grf_read_addr(),
				rd: self.rng.sample(&self.grf_addr_dist),
			}),
			InstructionType::Xori => Box::new(XoriInstr {
				rs: self.gen_grf_read_addr(),
				rt: self.rng.sample(&self.grf_addr_dist),
				imm: self.rng.sample(&self.imm_dist),
			}),
			InstructionType::Nor => Box::new(NorInstr {
				rs: self.gen_grf_read_addr(),
				rt: self.gen_grf_read_addr(),
				rd: self.rng.sample(&self.grf_addr_dist),
			}),
			InstructionType::Lui => Box::new(LuiInstr {
				rt: self.rng.sample(&self.grf_addr_dist),
				imm: self.rng.sample(&self.imm_dist),
			}),
			InstructionType::Lw => {
				let (base, offset) = self.gen_base_and_offset(!0b11);
				let mut rt = self.gen_grf_read_addr();
				if self.machine.state() == MachineState::InDelaySlot(self.machine.pc()) {
					while base == rt { rt = self.gen_grf_read_addr(); }
				}
				Box::new(LwInstr {
					base,
					rt,
					offset,
				})
			}
			InstructionType::Sw => {
				let (base, offset) = self.gen_base_and_offset(!0b11);
				let mut rt = self.gen_grf_read_addr();
				if self.machine.state() == MachineState::InDelaySlot(self.machine.pc()) {
					while base == rt { rt = self.gen_grf_read_addr(); }
				}
				Box::new(SwInstr {
					base,
					rt: self.rng.sample(&self.grf_addr_dist),
					offset,
				})
			}
			InstructionType::Beq => Box::new(BeqInstr {
				rs: self.gen_grf_read_addr(),
				rt: self.gen_grf_read_addr(),
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
		};
		self.machine.execute(&*instr);
		Some(instr)
	}
}
