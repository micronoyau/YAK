/*
 * Load segments into binary file to be concatenated with bootloader
 * Also outputs a dummy object file to be linked with assembly that only contains
 * the entrypoint address and the size of the kernel in bytes
 */

use elf::abi::PT_LOAD;
use elf::endian::AnyEndian;
use elf::ElfBytes;
use elf::segment::ProgramHeader;
use std::env;
use std::path::PathBuf;
use std::fs;
use std::io::Write;

fn main() {
    let args: Vec<String> = env::args().collect();

    if args.len() != 4 {
        panic!("Usage : {} [kernel file] [output loaded segments file] [output nasm macro file]\n", &args[0]);
    }

    // Loading kernel file
    let kernel_path = PathBuf::from(&args[1]);
    let kernel_data = fs::read(kernel_path).unwrap();
    let kernel_file = ElfBytes::<AnyEndian>::minimal_parse(kernel_data.as_slice()).unwrap();

    let mut output_segments_file = fs::File::create(&args[2]).unwrap();
    let mut output_nasm_file = fs::File::create(&args[3]).unwrap();

    // Focus on loadable segments
    let load_segments: Vec<ProgramHeader> = kernel_file.segments().unwrap()
        .iter()
        .filter(|phdr|{phdr.p_type == PT_LOAD})
        .collect();
    println!("There are {} PT_LOAD segments", load_segments.len());
    println!("{:?}", load_segments);

    let mut offset: u64 = 0;

    // Write segments as if they were in memory but in file
    load_segments.iter().for_each(|ph| {
        println!("Writing a segment in file from {} to {}", offset, offset+ph.p_memsz);
        let seg_data = kernel_file.segment_data(ph).unwrap();
        output_segments_file.write_all(seg_data).unwrap();

        // Write entrypoint offset in output dummy ELF file
        if ph.p_vaddr < kernel_file.ehdr.e_entry && kernel_file.ehdr.e_entry < ph.p_vaddr + ph.p_memsz {
            let entrypoint_offset = kernel_file.ehdr.e_entry-ph.p_vaddr+offset;
            println!("Entrypoint is at offset {} in file", entrypoint_offset);
            output_nasm_file.write_all(format!("%define KERNEL_ENTRY_OFFSET {}\n", entrypoint_offset).as_bytes()).unwrap();
        }

        offset += ph.p_memsz;
    });

    // Specify the size of loaded segments
    output_nasm_file.write_all(format!("%define KERNEL_MEMSIZE {}\n", offset).as_bytes()).unwrap();
}
