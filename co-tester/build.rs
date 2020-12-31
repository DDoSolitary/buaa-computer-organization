use std::{env, process, str};
use std::path::Path;
use std::process::Command;

fn main() {
	let asm_path = Path::new("src").join("code_handler.asm");
	println!("cargo:rerun-if-changed={}", asm_path.to_string_lossy());
	println!("cargo:rerun-if-env-changed=MARS_JAR");
	let mut cmd;
	if let Some(jar_path) = env::var_os("MARS_JAR") {
		cmd = Command::new("java");
		cmd.arg("-jar").arg(jar_path);
	} else {
		cmd = Command::new("mars-mips");
	}
	let output = cmd
		.args(&[
			"a", "nc", "db",
			"mc", "CompactDataAtZero",
			"dump", "0x4180-0x5000", "HexText",
		])
		.arg(Path::new(&env::var_os("OUT_DIR").unwrap()).join("code_handler.txt"))
		.arg(asm_path)
		.output().unwrap();
	assert!(output.status.success());
	if !output.stdout.is_empty() {
		eprintln!("MARS failed to assemble code_handler.asm:\n{}", str::from_utf8(&output.stdout).unwrap());
		process::exit(1);
	}
}
