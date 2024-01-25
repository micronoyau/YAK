#![no_std] // Disable std library (kernel code)
#![no_main]

mod other;
use crate::other::other::a;

use core::panic::PanicInfo;

const L: [i32;5] =[0,60,0x34,0x34,0x64];

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
    for _ in L {
        a();
    }
    loop {}
}
