extern crate clap;
#[macro_use]
extern crate lazy_static;
extern crate futures;
extern crate num_cpus;
extern crate regex;
extern crate strum;
extern crate strum_macros;
extern crate tempfile;
extern crate tokio;
extern crate rand;
extern crate rand_distr;

mod gen;
mod log;
mod machine;

use std::cell::RefCell;
use std::collections::HashSet;
use std::error::Error;
use std::fmt::{self, Display, Formatter};
use std::process::Stdio;
use std::str::FromStr;
use std::sync::Arc;
use std::sync::atomic::{AtomicU32, Ordering};

use futures::prelude::*;
use tokio::prelude::*;
use futures::channel::oneshot;
use strum::{AsStaticRef, IntoEnumIterator, VariantNames};
use tokio::fs::File;
use tokio::process::Command;
#[cfg(unix)]
use tokio::signal::unix::{SignalKind, signal};

use gen::{InstructionType, InstructionGenerator};
use log::LogEntry;
use machine::MipsMachine;

const INSTR_COUNT: u32 = 1023;

#[derive(Debug)]
struct TestFailureError {
	reason: String,
}

impl Display for TestFailureError {
	fn fmt(&self, f: &mut Formatter<'_>) -> fmt::Result {
		write!(f, "Test failed: {}", self.reason)
	}
}

impl Error for TestFailureError {}

impl TestFailureError {
	fn new(reason: String) -> Self {
		Self { reason }
	}
}

#[tokio::main]
async fn main() {
	let about_str = format!("Supported instructions: {}", InstructionType::VARIANTS.join(", "));
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
		.arg(clap::Arg::with_name("fail-fast")
			.long("fail-fast")
			.help("Stop testing immediately if one test fails."))
		.arg(clap::Arg::with_name("tmp-dir")
			.short("d")
			.long("tmp-dir")
			.takes_value(true)
			.default_value_os(&sys_tmp_dir)
			.help("Path to the temporary directory used to store generated data."))
		.arg(clap::Arg::with_name("subject-path")
			.index(1)
			.value_name("TEST_SUBJECT")
			.required(true)
			.help("Path to the compiled output of iverilog to be tested."))
		.get_matches();
	let test_count = matches.value_of("count").unwrap().parse::<u32>().unwrap();
	let thread_count = matches.value_of("threads").unwrap().parse::<usize>().unwrap();
	let no_db = matches.is_present("no-db");
	let fail_fast = matches.is_present("fail-fast");
	let tmp_dir = matches.value_of_os("tmp-dir").unwrap();
	let subject_path = matches.value_of_os("subject-path").unwrap();
	let instr_set = if let Some(only_instr) = matches.value_of("only-instr") {
		only_instr.split(',').map(|s| {
			InstructionType::from_str(s).unwrap_or_else(|_| {
				println!("Error: unsupported instruction: {}", s);
				std::process::exit(1);
			})
		}).collect::<Vec<_>>()
	} else {
		let excluded = matches.value_of("exclude-instr")
			.unwrap_or("")
			.split(',')
			.collect::<HashSet<_>>();
		InstructionType::iter().filter(|instr| {
			!excluded.contains(instr.as_static())
		}).collect::<Vec<_>>()
	};
	let instr_set = Arc::new(instr_set);

	let success_count = AtomicU32::new(0);
	let failure_count = AtomicU32::new(0);

	let (cancel_tx, cancel_rx) = oneshot::channel();
	let cancel_tx = RefCell::new(Some(cancel_tx));

	let fut = stream::iter(0..test_count).for_each_concurrent(thread_count, |_| async {
		let instr_set = Arc::clone(&instr_set);
		let dir = tempfile::Builder::new().prefix("co-tester-").tempdir_in(tmp_dir).unwrap();
		let dir_path = dir.path();
		let (asm_data, code_data, grf_log_data, mem_log_data, machine) =
			tokio::task::spawn_blocking(move || {
				let mut asm_data = Vec::new();
				let mut code_data = Vec::new();
				let mut machine = MipsMachine::new(!no_db);
				for instr in InstructionGenerator::new(&mut machine, &instr_set, INSTR_COUNT) {
					asm_data.extend(format!("{}\n", instr).as_bytes());
					code_data.extend(format!("{:08x}\n", instr.to_machine_code()).as_bytes());
				}
				let mut grf_log_data = Vec::new();
				for log in machine.grf_log() {
					grf_log_data.extend(format!("{}\n", log).as_bytes());
				}
				let mut mem_log_data = Vec::new();
				for log in machine.mem_log() {
					mem_log_data.extend(format!("{}\n", log).as_bytes());
				}
				(asm_data, code_data, grf_log_data, mem_log_data, machine)
			}).await.unwrap();
		File::create(dir_path.join("test.asm")).await.unwrap().write_all(&asm_data).await.unwrap();
		File::create(dir_path.join("code.txt")).await.unwrap().write_all(&code_data).await.unwrap();
		File::create(dir_path.join("std-grf.log")).await.unwrap().write_all(&grf_log_data).await.unwrap();
		File::create(dir_path.join("std-mem.log")).await.unwrap().write_all(&mem_log_data).await.unwrap();
		let vvp_res = Command::new("vvp")
			.arg(std::env::current_dir().unwrap().join(subject_path))
			.current_dir(dir_path)
			.stdin(Stdio::null()).stdout(Stdio::piped()).stderr(Stdio::piped())
			.output().await.unwrap();
		File::create(dir_path.join("subject.log")).await.unwrap().write_all(&vvp_res.stdout).await.unwrap();
		let res = tokio::task::spawn_blocking(move || {
			let subject_log = String::from_utf8_lossy(&vvp_res.stdout);
			if !vvp_res.status.success() {
				return Err(TestFailureError::new(format!(
					"failed to run the test subject.\nstdout:\n{}\nstderr:\n{}",
					subject_log, String::from_utf8_lossy(&vvp_res.stderr),
				)));
			}
			let mut grf_id = 0;
			let mut mem_id = 0;
			for (i, subject_line) in subject_log.lines().enumerate() {
				match subject_line.parse::<LogEntry>() {
					Ok(LogEntry::Grf(grf_entry)) => {
						if let Some(std_entry) = machine.grf_log().get(grf_id) {
							if grf_entry != *std_entry {
								return Err(TestFailureError::new(format!(
									"got \"{}\" at line {}, but expected \"{}\"",
									grf_entry, i + 1, std_entry,
								)));
							}
							grf_id += 1;
						} else {
							return Err(TestFailureError::new(format!(
								"got \"{}\" at line {}, but standard output has ended.",
								grf_entry, i + 1,
							)));
						}
					}
					Ok(LogEntry::Mem(mem_entry)) => {
						if let Some(std_entry) = machine.mem_log().get(mem_id) {
							if mem_entry != *std_entry {
								return Err(TestFailureError::new(format!(
									"got \"{}\" at line {}, but expected \"{}\"",
									mem_entry, i + 1, std_entry,
								)));
							}
							mem_id += 1;
						} else {
							return Err(TestFailureError::new(format!(
								"got \"{}\" at line {}, but standard output has ended.",
								mem_entry, i + 1,
							)));
						}
					}
					Err(_) => (),
				}
			}
			if let Some(entry) = machine.grf_log().get(grf_id) {
				return Err(TestFailureError::new(format!(
					"too few register writes, the next expected line is \"{}\".",
					entry,
				)));
			}
			if let Some(entry) = machine.mem_log().get(mem_id) {
				return Err(TestFailureError::new(format!(
					"too few memory writes, the next expected line is \"{}\".",
					entry,
				)));
			}
			Ok(())
		}).await.unwrap();
		if let Err(e) = res {
			println!("{}", e);
			println!("Relevant files are in {}\n", dir.into_path().to_string_lossy());
			failure_count.fetch_add(1, Ordering::Relaxed);
			if fail_fast {
				if let Some(cancel_tx) = cancel_tx.borrow_mut().take() {
					cancel_tx.send(()).unwrap();
				}
			}
		} else {
			success_count.fetch_add(1, Ordering::Relaxed);
		}
	});
	#[cfg(unix)] let mut signals = [
		Box::new(signal(SignalKind::hangup()).unwrap()) as Box<dyn Stream<Item = ()> + Unpin>,
		Box::new(signal(SignalKind::interrupt()).unwrap()),
		Box::new(signal(SignalKind::terminate()).unwrap()),
	];
	#[cfg(windows)] let mut signals = [
		Box::new(tokio::signal::windows::ctrl_c().unwrap()) as Box<dyn Stream<Item = ()> + Unpin>,
		Box::new(tokio::signal::windows::ctrl_break().unwrap()),
	];
	let sig_fut = future::select_all(signals.iter_mut().map(|sig| sig.next()));
	future::select_all(vec![
		Box::new(fut) as Box<dyn Future<Output = ()> + Unpin>,
		Box::new(cancel_rx.map(|_| ())),
		Box::new(sig_fut.map(|_| ())),
	]).await;
	let success_count = success_count.load(Ordering::Relaxed);
	let failure_count = failure_count.load(Ordering::Relaxed);
	println!(
		"{} succeeded, {} failed, {} canceled",
		success_count,
		failure_count,
		test_count - success_count - failure_count,
	);
}
