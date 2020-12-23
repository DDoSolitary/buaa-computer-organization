use std::error::Error;
use std::fmt::{self, Display, Formatter};
use std::num::ParseIntError;
use std::str::FromStr;

use regex::Regex;

#[derive(Debug, Eq, PartialEq, Clone)]
pub struct GrfLogEntry {
	pc: u32,
	addr: u8,
	data: u32,
}

impl Display for GrfLogEntry {
	fn fmt(&self, f: &mut Formatter<'_>) -> fmt::Result {
		write!(f, "@{:08x}: ${:2} <= {:08x}", self.pc, self.addr, self.data)
	}
}

impl GrfLogEntry {
	pub fn new(pc: u32, addr: u8, data: u32) -> Self {
		Self { pc, addr, data }
	}

	pub fn pc(&self) -> u32 { self.pc }
	pub fn addr(&self) -> u8 { self.addr }
	pub fn data(&self) -> u32 { self.data }
}

#[derive(Debug, Eq, PartialEq, Clone)]
pub struct MemLogEntry {
	pc: u32,
	addr: u32,
	data: u32,
}

impl Display for MemLogEntry {
	fn fmt(&self, f: &mut Formatter<'_>) -> fmt::Result {
		write!(f, "@{:08x}: *{:08x} <= {:08x}", self.pc, self.addr, self.data)
	}
}

impl MemLogEntry {
	pub fn new(pc: u32, addr: u32, data: u32) -> Self {
		Self { pc, addr, data }
	}

	pub fn addr(&self) -> u32 { self.addr }
}

#[derive(Debug)]
pub struct ParseLogError {
	source: Option<ParseIntError>,
}

impl Display for ParseLogError {
	fn fmt(&self, f: &mut Formatter<'_>) -> fmt::Result {
		write!(f, "invalid log line")?;
		if let Some(source) = &self.source {
			write!(f, ", source: {}", source)?;
		}
		Ok(())
	}
}

impl Error for ParseLogError {
	fn source(&self) -> Option<&(dyn Error + 'static)> {
		match self.source.as_ref() {
			Some(source) => Some(source),
			None => None,
		}
	}
}

impl From<ParseIntError> for ParseLogError {
	fn from(e: ParseIntError) -> Self {
		Self { source: Some(e) }
	}
}

#[derive(Debug, Eq, PartialEq, Clone)]
pub enum LogEntry {
	Grf(GrfLogEntry),
	Mem(MemLogEntry),
}

impl Display for LogEntry {
	fn fmt(&self, f: &mut Formatter<'_>) -> fmt::Result {
		match self {
			Self::Grf(log) => write!(f, "{}", log),
			Self::Mem(log) => write!(f, "{}", log),
		}
	}
}

impl FromStr for LogEntry {
	type Err = ParseLogError;

	fn from_str(s: &str) -> Result<Self, Self::Err> {
		lazy_static! {
			static ref RE: Regex = Regex::new("^ *[0-9]*@(?P<pc>[0-9a-fA-F]{8}): (?:\\$ *(?P<grf_addr>[0-9]+)|\\*(?P<mem_addr>[0-9a-fA-F]{8})) <= (?P<data>[0-9a-fA-F]{8})$").unwrap();
		}
		let captures = RE.captures(s).ok_or(ParseLogError { source: None })?;
		let pc = u32::from_str_radix(&captures["pc"], 16)?;
		let data = u32::from_str_radix(&captures["data"], 16)?;
		if let Some(grf_addr) = captures.name("grf_addr") {
			Ok(Self::Grf(GrfLogEntry::new(pc, grf_addr.as_str().parse()?, data)))
		} else {
			let mem_addr = u32::from_str_radix(&captures["mem_addr"], 16)?;
			Ok(Self::Mem(MemLogEntry::new(pc, mem_addr, data)))
		}
	}
}
