#![no_std] // Disable std library (kernel code)
#![no_main]

use core::panic::PanicInfo;

// Custom panic handler
#[panic_handler]
fn panic(_panic_info: &PanicInfo) -> ! {
    loop {}
}

// extern "C" means : use cdecl calling convention
// [no_mangle] tells Rust to disable name mangling, so that we can effectively
// have a "_start" symbol that the bootloader can find
#[no_mangle]
pub extern "C" fn _start() -> ! {
    loop {}
}
