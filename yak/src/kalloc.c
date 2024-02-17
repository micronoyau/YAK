#include "memlayout.h"
#include "utils.h"

struct FreeFrame {
    struct FreeFrame* next;
};

struct FreeFrame* top = 0;

void kinit() {
    struct FreeFrame* next = 0;
    struct FreeFrame* frame;

    // 8-byte pointers so we need to step by FRAME_SIZE/8
    for(frame = (struct FreeFrame*) FREE_MEM_TOP-FRAME_SIZE;
        frame >= (struct FreeFrame*) FREE_MEM_BASE;
        frame -= (FRAME_SIZE>>3))
    {
        frame->next = next;
        next = frame;
    }

    top = next;
}

void* kalloc() {
    void* ret = (void*) top;
    top = top->next;
    return ret;
}

int kfree(void* addr) {
    if (!is_aligned(addr)) {
        return 1;
    }

    struct FreeFrame* new_top = (struct FreeFrame*) addr;
    new_top->next = top;
    top = new_top;

    return 0;
}
