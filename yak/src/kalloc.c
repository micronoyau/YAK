#include "memlayout.h"

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

