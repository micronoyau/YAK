#include "utils.h"
#include "kalloc.h"

void _start() {
    kinit();
    void* frame = kalloc();
    memcpy(frame, "micronoyau", 10);
    kfree(frame);
    while(1) { }
}
