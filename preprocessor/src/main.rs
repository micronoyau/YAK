use elf::abi::PT_LOAD;
use elf::endian::AnyEndian;
use elf::ElfBytes;
use elf::segment::ProgramHeader;
use std::env;

fn main() {
    let args: Vec<String> = env::args().collect();
    let path = std::path::PathBuf::from(&args[1]);
    let file_data = std::fs::read(path).unwrap();

    let slice = file_data.as_slice();
    let file = ElfBytes::<AnyEndian>::minimal_parse(slice).unwrap();
    println!("{:?}", file.segments().unwrap());
// Get all the common ELF sections (if any). We have a lot of ELF work to do!
let common_sections = file.find_common_data().unwrap();
// ... do some stuff with the symtab, dynsyms etc

// It can also yield iterators on which we can do normal iterator things, like filtering
// for all the segments of a specific type. Parsing is done on each iter.next() call, so
// if you end iteration early, it won't parse the rest of the table.
let first_load_phdr: Option<ProgramHeader> = file.segments().unwrap()
    .iter()
    .find(|phdr|{phdr.p_type == PT_LOAD});
println!("First load segment is at: {}", first_load_phdr.unwrap().p_vaddr);

// Or if you do things like this to get a vec of only the PT_LOAD segments.
let all_load_phdrs: Vec<ProgramHeader> = file.segments().unwrap()
    .iter()
    .filter(|phdr|{phdr.p_type == PT_LOAD})
    .collect();
println!("There are {} PT_LOAD segments", all_load_phdrs.len());
println!("{:?}", all_load_phdrs);
all_load_phdrs.iter().for_each(|ph| {
    println!("{}/{}", ph.p_offset, ph.p_filesz);
    let seg_data = file.segment_data(ph).unwrap();
    println!("DTATATATTATATATA {:?} {}", seg_data, seg_data.len());
    println!("\n\n");
})
}
