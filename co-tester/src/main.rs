extern crate clap;
extern crate futures;
extern crate num_cpus;
extern crate strum;
extern crate strum_macros;
extern crate tempdir;
extern crate tokio;
extern crate rand;
extern crate rand_distr;

use std::collections::HashSet;
use std::process::Stdio;
use std::str::FromStr;
use std::sync::Arc;

use futures::prelude::*;
use tokio::prelude::*;
use rand::prelude::*;

use rand::distributions::Uniform;
use rand_distr::Normal;
use strum::{AsStaticRef, IntoEnumIterator, VariantNames};
use strum_macros::{Display, AsStaticStr, EnumIter, EnumString, EnumVariantNames};
use tempdir::TempDir;
use tokio::fs::File;
use tokio::process::Command;

#[derive(Copy, Clone, Eq, PartialEq, Display, AsStaticStr, EnumIter, EnumString, EnumVariantNames)]
#[strum(serialize_all = "kebab_case")]
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

impl Op {
	fn is_jump(&self) -> bool {
		match self {
			Op::Beq | Op::J | Op::Jal | Op::Jr => true,
			_ => false,
		}
	}

	fn dependencies(&self) -> Vec<Op> {
		match self {
			Op::Lw | Op::Sw => vec![Op::Ori, Op::Lui],
			Op::Jr => vec![Op::Ori],
			_ => vec![],
		}
	}
}

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
	let about_str = format!("Supported instructions: {}", Op::VARIANTS.join(", "));
	let default_threads = num_cpus::get().to_string();
	let sys_tmp_dir = std::env::temp_dir().into_os_string();
	let matches = clap::App::new(env!("CARGO_PKG_NAME"))
		.version(env!("CARGO_PKG_VERSION"))
		.author(env!("CARGO_PKG_AUTHORS"))
		.about(&*about_str)
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
		.arg(clap::Arg::with_name("only-instr")
			.long("only-instr")
			.takes_value(true)
			.conflicts_with("exclude-instr")
			.help("A comma-separated list of instructions that will be generated."))
		.arg(clap::Arg::with_name("exclude-instr")
			.long("exclude-instr")
			.takes_value(true)
			.conflicts_with("only-instr")
			.help("A comma-separated list of instructions that will not be generated."))
		.arg(clap::Arg::with_name("no-db")
			.long("no-db")
			.help("Disable delayed branching."))
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
	let no_db = matches.is_present("no-db");
	let tmp_dir = matches.value_of_os("tmp-dir").unwrap();
	let mars_path = matches.value_of_os("mars-path").unwrap();
	let subject_path = matches.value_of_os("subject-path").unwrap();
	let ops = if let Some(only_instr) = matches.value_of("only-instr") {
		only_instr.split(',').map(|s| {
			Op::from_str(s).unwrap_or_else(|_| {
				println!("Error: unsupported instruction: {}", s);
				std::process::exit(1);
			})
		}).collect::<Vec<_>>()
	} else {
		let excluded = matches.value_of("exclude-instr")
			.unwrap_or("")
			.split(',')
			.collect::<HashSet<_>>();
		Op::iter().filter(|op| {
			!excluded.contains(op.as_static())
		}).collect::<Vec<_>>()
	};
	for op in &ops {
		for dep in &op.dependencies() {
			if !ops.contains(dep) {
				println!("Error: instruction {} is required by {}.", dep, op);
				std::process::exit(1);
			}
		}
	}
	let ops = Arc::new(ops);

	stream::iter(0..test_count).for_each_concurrent(thread_count, |_| async {
		let ops = Arc::clone(&ops);
		let asm_data = tokio::task::spawn_blocking(move || {
			let mut rng = rand::thread_rng();
			let op_dist = Uniform::new(0, ops.len());
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
				let op = ops[rng.sample(op_dist)];
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
		let mut mars_cmd = Command::new("java");
		mars_cmd.arg("-jar").arg(mars_path);
		if !no_db { mars_cmd.arg("db"); }
		let mars_res = mars_cmd
			.args(&[
				"nc", "mc", "CompactDataAtZero",
				"dump", ".text", "HexText", code_path.to_str().unwrap(),
				asm_path.to_str().unwrap(),
			])
			.stdin(Stdio::null())
			.output().await.unwrap();
		let vvp_res = Command::new("vvp")
			.arg(std::env::current_dir().unwrap().join(subject_path))
			.current_dir(dir_path)
			.stdin(Stdio::null()).stdout(Stdio::piped()).stderr(Stdio::inherit())
			.output().await.unwrap();
		File::create(&mars_log_path).await.unwrap().write_all(&mars_res.stdout).await.unwrap();
		File::create(&vvp_log_path).await.unwrap().write_all(&vvp_res.stdout).await.unwrap();
		let res = tokio::task::spawn_blocking(move || {
			std::panic::catch_unwind(|| {
				let mars_log = String::from_utf8_lossy(&mars_res.stdout);
				let vvp_log = String::from_utf8_lossy(&vvp_res.stdout);
				assert!(mars_res.status.success(),
					"Failed to run MARS.\nstdout:\n{}\nsterr:\n{}",
					mars_log, String::from_utf8_lossy(&mars_res.stderr));
				assert!(vvp_res.status.success(),
					"Failed to run the test subject.\nstdout:\n{}\nstderr:\n{}",
					vvp_log, String::from_utf8_lossy(&vvp_res.stderr));
				let mut mars_reg_lines = Vec::new();
				let mut mars_mem_lines = Vec::new();
				for line in mars_log.split('\n') {
					if !line.starts_with('@') { continue; }
					if &line[11..12] == "$" {
						if &line[12..14] == " 0" { continue; }
						mars_reg_lines.push(line);
					} else {
						mars_mem_lines.push(line);
					}
				}
				let mut reg_id = 0;
				let mut mem_id = 0;
				for (i, vvp_line) in vvp_log.split('\n').enumerate() {
					let pos = if let Some(pos) = vvp_line.find('@') { pos } else { continue; };
					let vvp_line = &vvp_line[pos..vvp_line.len()];
					let mars_line;
					if &vvp_line[11..12] == "$" {
						if &vvp_line[12..14] == " 0" { continue; }
						mars_line = mars_reg_lines.get(reg_id);
						reg_id += 1;
					} else {
						mars_line = mars_mem_lines.get(mem_id);
						mem_id += 1;
					}
					assert!(mars_line.is_some(), "Got \"{}\" at line {}, but MARS output has ended.", vvp_line, i + 1);
					assert_eq!(*mars_line.unwrap(), vvp_line, "Unexpected output at line {}.", i + 1);
				}
				assert_eq!(mars_reg_lines.len(), reg_id,
					"Too few register writes, the next expected line is \"{}\".",
					mars_reg_lines[reg_id]);
				assert_eq!(mars_mem_lines.len(), mem_id,
					"Too few memory writes, the next expected line is \"{}\".",
					mars_mem_lines[mem_id]);
			})
		}).await.unwrap();
		if res.is_err() {
			println!("Test failed. Relevant files are in {}", dir_path.to_string_lossy());
			std::process::exit(1);
		}
	}).await;
}
