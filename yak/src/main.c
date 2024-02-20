#include "utils.h"
#include "kalloc.h"
#include "kvm.h"

void _start() {
    kinit();
    void* frame = kalloc();
    memcpy(frame, "micronoyau", 10);
    kfree(frame);
    kvminit();
    while(1) { }
}
