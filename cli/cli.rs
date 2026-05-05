// SPDX-License-Identifier: MIT

/*
 * edu-cli utility
 *
 * Author:  Giovanni Santini
 * Mail:    giovanni.santini@proton.me
 * Github:  @San7o
 */

/* Imports */
use std::error::Error;
use std::ffi::{c_int, c_ulong, c_char, CString};
use std::env;
use std::process;

/* C FFI */
#[allow(non_camel_case_types)]
type c_size_t = usize;
const O_RDONLY: c_int = 0;
extern "C" {
    pub fn open(pathname: *const c_char, flags: c_int, ...) -> c_int;
    pub fn close(fd: c_int) -> c_int;
    pub fn read(fd: c_int, buf: *const c_char, count: c_size_t) -> c_size_t;
    pub fn ioctl(fd: c_int, op: c_ulong, ...) -> c_int;
}

/*
 * Edu
 */

const EDU_DRIVER_FILE: &str = "/dev/edu_driver";

#[repr(u64)]
#[derive(Debug)]
enum Command {
    Check    = 0x01,
    Id       = 0x02,
    Int      = 0x03,
    Fact     = 0x04,
    DmaRead  = 0x05,
    DmaWrite = 0x06,
}

struct Args {
    command: Command,
    val: Option<String>,
}

impl Args {
    fn parse() -> Result<Self, Box<dyn Error>> {
        let args: Vec<String> = env::args().collect();
        let name: &str = args.get(0).unwrap();
        
        if args.len() < 2 {
            print_usage(name);
            return Err("Wrong usage".into());
        }
        
        let command = match args[1].as_str() {
            "check" => Command::Check,
            "id"    => Command::Id,
            "int"   => Command::Int,
            "fact"  => Command::Fact,
            "write" => Command::DmaWrite,
            "read"  => Command::DmaRead,
            "help"  => { print_usage(name); process::exit(0); }
            _       => return Err(format!("Unknown command: {}", args[1]).into()),
        };
        
        Ok(Args {
            command,
            val: args.get(2).cloned(),
        })
    }
}

fn print_usage(name: &str) {
    println!("Usage: {} <command> [<arg>]", name);
    println!("");
    println!("Available commands:");
    println!("   check       check if device is ok");
    println!("   id          get the id of the device");
    println!("   int         trigger an interrupt request");
    println!("   fact x      compute the factorial of x");
    println!("   write str   performa DMA write");
    println!("   read        read DMA");
    println!("   help        show this message and exit");
}

fn main() {
    let args = Args::parse().unwrap_or_else(|err| {
        eprintln!("[error] {}", err);
        process::exit(1);
    });

    if let Err(e) = run(args) {
    eprintln!("[error] Application error: {}", e);
        process::exit(1);
    }
    
    println!("[info] done");
}

fn run(args: Args) -> Result<(), Box<dyn Error>> {
    println!("[info] Command {:?}, val {:?}", args.command, args.val);
    
    let filename = CString::new(EDU_DRIVER_FILE).unwrap();
    unsafe {
        let fd = open(filename.as_ptr(), O_RDONLY);
        if fd < 0 {
            return Err("Failed to open file".into());
        }
        ioctl(fd, args.command as u64);
        close(fd);
    }
    
    Ok(())
}
