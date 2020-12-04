extern crate clap;
extern crate futures;
extern crate num_cpus;
extern crate tempdir;
extern crate tokio;
extern crate rand;
extern crate rand_distr;

use std::fmt::{Display, Formatter};
use std::process::Stdio;

use futures::prelude::*;
use tokio::prelude::*;
use rand::prelude::*;

use rand::distributions::Uniform;
use rand_distr::Normal;
use tempdir::TempDir;
use tokio::fs::File;
use tokio::process::Command;

#[repr(u32)]
#[allow(dead_code)]
#[derive(Eq, PartialEq)]
enum Op {
	Nop,
	Addu,
	Subu,
	Andi,
	Ori,
	Lui,
	Lw,
	Sw,
	Beq,
	J,
	Jal,
	Jr,
}

impl Display for Op {
	fn fmt(&self, f: &mut Formatter<'_>) -> std::fmt::Result {
		match self {
			Op::Nop => write!(f, "nop"),
			Op::Addu => write!(f, "addu"),
			Op::Subu => write!(f, "subu"),
			Op::Andi => write!(f, "andi"),
			Op::Ori => write!(f, "ori"),
			Op::Lui => write!(f, "lui"),
			Op::Lw => write!(f, "lw"),
			Op::Sw => write!(f, "sw"),
			Op::Beq => write!(f, "beq"),
			Op::J => write!(f, "j"),
			Op::Jal => write!(f, "jal"),
			Op::Jr => write!(f, "jr"),
		}
	}
}

impl Op {
	fn is_jump(&self) -> bool {
		match self {
			Op::Beq | Op::J | Op::Jal | Op::Jr => true,
			_ => false,
		}
	}
}

const OP_MAX: Op = Op::Jr;
const INSTR_COUNT: i32 = 1022;

fn reg_rand_or_last<T: rand::Rng>(x: i32, rng: &mut T, last_written: Option<i32>) -> i32 {
	if let Some(y) = last_written {
		if rng.gen_bool(0.5) { x } else { y }
	} else {
		x
	}
}

#[tokio::main]
async fn main() {
	let default_threads = num_cpus::get().to_string();
	let sys_tmp_dir = std::env::temp_dir().into_os_string();
	let matches = clap::App::new(env!("CARGO_PKG_NAME"))
		.version(env!("CARGO_PKG_VERSION"))
		.author(env!("CARGO_PKG_AUTHORS"))
		.arg(clap::Arg::with_name("count")
			.short("c")
			.long("count")
			.takes_value(true)
			.default_value("1")
			.help("Number of tests to run in total."))
		.arg(clap::Arg::with_name("threads")
			.short("t")
			.long("threads")
			.takes_value(true)
			.default_value(&default_threads)
			.help("Number of threads used to run the tests in parallel."))
		.arg(clap::Arg::with_name("tmp-dir")
			.short("d")
			.long("tmp-dir")
			.takes_value(true)
			.default_value_os(&sys_tmp_dir)
			.help("Path to the temporary directory used to store generated data."))
		.arg(clap::Arg::with_name("mars-path")
			.short("m")
			.long("mars-path")
			.takes_value(true)
			.default_value("Mars-log.jar")
			.help("Path to the patched version of MARS."))
		.arg(clap::Arg::with_name("subject-path")
			.index(1)
			.value_name("TEST_SUBJECT")
			.required(true)
			.help("Path to the compiled output of iverilog to be tested."))
		.get_matches();
	let test_count = matches.value_of("count").unwrap().parse::<u32>().unwrap();
	let thread_count = matches.value_of("threads").unwrap().parse::<usize>().unwrap();
	let tmp_dir = matches.value_of_os("tmp-dir").unwrap();
	let mars_path = matches.value_of_os("mars-path").unwrap();
	let subject_path = matches.value_of_os("subject-path").unwrap();

	stream::iter(0..test_count).for_each_concurrent(thread_count, |_| async {
		let asm_data = tokio::task::spawn_blocking(|| {
			let mut rng = rand::thread_rng();
			let op_dist = Uniform::new_inclusive(0, OP_MAX as u32);
			let reg_dist = Uniform::new(0, 32);
			let imm_dist = Uniform::new_inclusive(0, u16::max_value());
			let mem_addr_dist = Uniform::new(0u16, 1024);
			let mut reg_last_written = None;
			let mut mem_last_written = None;
			let mut in_delay_slot = false;
			let mut asm_lines = Vec::new();
			let mut pc = 0;
			let mut instr_id = 0;
			let mut instr_addrs = Vec::new();
			let mut pending_labels = Vec::new();
			let mut pending_addrs = Vec::new();
			loop {
				let op = unsafe { std::mem::transmute::<_, Op>(rng.sample(op_dist)) };
				let mut instr_count = 1;
				let mut rs = rng.sample(reg_dist);
				let mut rt = rng.sample(reg_dist);
				let rd = rng.sample(reg_dist);
				let imm = rng.sample(imm_dist);
				match op {
					Op::Addu | Op::Subu => {
						rs = reg_rand_or_last(rs, &mut rng, reg_last_written);
						rt = reg_rand_or_last(rt, &mut rng, reg_last_written);
						reg_last_written = Some(rd);
						asm_lines.push(format!("L{}: {} ${}, ${}, ${}\n", instr_id, op, rd, rs, rt));
					}
					Op::Andi | Op::Ori => {
						rs = reg_rand_or_last(rs, &mut rng, reg_last_written);
						reg_last_written = Some(rt);
						asm_lines.push(format!("L{}: {} ${}, ${}, {}\n", instr_id, op, rt, rs, imm));
					}
					Op::Lui => {
						reg_last_written = Some(rt);
						asm_lines.push(format!("L{}: {} ${}, {}\n", instr_id, op, rt, imm));
					}
					Op::Lw | Op::Sw => {
						let rand_addr = rng.sample(mem_addr_dist) << 2;
						let addr = if op == Op::Lw && rng.gen_bool(0.5) {
							mem_last_written.unwrap_or(rand_addr)
						} else {
							rand_addr
						};
						let (base, offset) = if rs != 0 {
							let offset = rng.sample(imm_dist) as i16;
							let base = addr as i32 - offset as i32;
							instr_count = if base < 0 { 3 } else { 2 };
							if pc + instr_count > INSTR_COUNT { continue; }
							(base, offset)
						} else {
							let offset = addr as i16;
							if offset < 0 { continue; }
							(0, offset)
						};
						if op == Op::Lw {
							reg_last_written = Some(rt);
						} else {
							reg_last_written = Some(rs);
							rt = reg_rand_or_last(rt, &mut rng, Some(rs));
							mem_last_written = Some(addr);
						}
						if rs != 0 {
							if base < 0 {
								asm_lines.push(format!("L{}: {} ${}, {}\n", instr_id, Op::Lui, rs, (base >> 16) as u16));
								asm_lines.push(format!("{} ${}, ${}, {}\n", Op::Ori, rs, rs, base as u16));
							} else {
								asm_lines.push(format!("L{}: {} ${}, $0, {}\n", instr_id, Op::Ori, rs, base as u16));
							}
							asm_lines.push(format!("{} ${}, {}(${})\n", op, rt, offset, rs));
						} else {
							asm_lines.push(format!("L{}: {} ${}, {}(${})\n", instr_id, op, rt, offset, rs));
						}
					}
					Op::Beq => {
						if pc + 2 > INSTR_COUNT || in_delay_slot { continue; }
						let must_jump = pc + 3 > INSTR_COUNT && rng.gen_bool(0.5);
						rs = reg_rand_or_last(rs, &mut rng, reg_last_written);
						rt = if must_jump { rs } else { reg_rand_or_last(rt, &mut rng, reg_last_written) };
						asm_lines.push(format!("L{}: {} ${}, ${}, L", instr_id, op, rs, rt));
						pending_labels.push(instr_id);
					}
					Op::J | Op::Jal => {
						if pc + 2 > INSTR_COUNT || in_delay_slot { continue; }
						asm_lines.push(format!("L{}: {} L", instr_id, op));
						pending_labels.push(instr_id);
					}
					Op::Jr => {
						if pc + 3 > INSTR_COUNT { continue; }
						rs = reg_rand_or_last(rs, &mut rng, reg_last_written);
						if rs == 0 { rs = rng.gen_range(1, 32); }
						instr_count = 2;
						asm_lines.push(format!("L{}: {} ${}, $0, ", instr_id, Op::Ori, rs));
						asm_lines.push(format!("{} ${}\n", op, rs));
						pending_addrs.push(instr_id);
					}
					_ => asm_lines.push(format!("L{}: {}\n", instr_id, Op::Nop)),
				}
				instr_addrs.push(pc as usize);
				pc += instr_count;
				instr_id += 1;
				in_delay_slot = op.is_jump();
				if pc >= INSTR_COUNT { break; }
			}
			let target_dist = Normal::new(0f64, 5f64).unwrap();
			let gen_target = |rng: &mut ThreadRng, begin: usize, end: usize| {
				let target = begin + (rng.sample(target_dist).abs() as usize) + 1;
				if target < end { target } else { end - 1 }
			};
			for i in pending_labels {
				let target = gen_target(&mut rng, i, instr_id);
				asm_lines[instr_addrs[i]] += &format!("{}\n", target);
			}
			for i in pending_addrs {
				let target = instr_addrs[gen_target(&mut rng, i, instr_id)];
				asm_lines[instr_addrs[i]] += &format!("{}\n", (target << 2) | 0x3000);
			}
			let mut asm_data = Vec::new();
			for line in asm_lines {
				asm_data.extend(line.as_bytes());
			}
			asm_data
		}).await.unwrap();
		let dir = TempDir::new_in(tmp_dir, "co-tester").unwrap();
		let dir_path = dir.path();
		let asm_path = dir_path.join("test.asm");
		let code_path = dir_path.join("code.txt");
		let mars_log_path = dir_path.join("mars.log");
		let vvp_log_path = dir_path.join("vvp.log");
		File::create(&asm_path).await.unwrap().write_all(&asm_data).await.unwrap();
		let mars_res = Command::new("java")
			.arg("-jar").arg(mars_path)
			.args(&[
				"nc", "db", "mc", "CompactDataAtZero",
				"dump", ".text", "HexText", code_path.to_str().unwrap(),
				asm_path.to_str().unwrap(),
			])
			.stdin(Stdio::null()).stdout(Stdio::piped()).stderr(Stdio::null())
			.output().await.unwrap();
		assert!(mars_res.status.success());
		let vvp_res = Command::new("vvp")
			.arg(std::env::current_dir().unwrap().join(subject_path))
			.current_dir(dir_path)
			.stdin(Stdio::null()).stdout(Stdio::piped()).stderr(Stdio::null())
			.output().await.unwrap();
		assert!(mars_res.status.success());
		let mars_log = String::from_utf8(mars_res.stdout).unwrap();
		let vvp_log = String::from_utf8(vvp_res.stdout).unwrap();
		File::create(&mars_log_path).await.unwrap().write_all(mars_log.as_bytes()).await.unwrap();
		File::create(&vvp_log_path).await.unwrap().write_all(vvp_log.as_bytes()).await.unwrap();
		let res = tokio::task::spawn_blocking(move || {
			std::panic::catch_unwind(|| {
				let mut mars_lines = mars_log.split('\n');
				for vvp_line in vvp_log.split_terminator('\n') {
					let pos = if let Some(pos) = vvp_line.find('@') { pos } else { continue; };
					let mut mars_line;
					loop {
						mars_line = mars_lines.next().unwrap();
						if mars_line.starts_with('@') && !mars_line.contains("$ 0") {
							break;
						}
					}
					assert_eq!(&vvp_line[pos..vvp_line.len()], mars_line);
				}
				for line in mars_lines {
					assert!(!line.starts_with('@') || line.contains("$ 0"));
				}
			})
		}).await.unwrap();
		if res.is_err() {
			println!("Test directory: {}", dir_path.to_string_lossy());
			std::process::exit(1);
		}
	}).await;
}
