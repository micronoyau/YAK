#include "memlayout.h"

void memcpy(void* dst_, void* src_, long sz) {
    // 64 bit machine : can copy 8 by 8
    long* src = (long*) src_;
    long* dst = (long*) dst_;
    long i;
    for (i=0; i<sz>>3; i++) {
        *(dst+i) = *(src+i);
    }
    i*=8;

    // Remaining bytes : copy byte per byte
    char* src2 = (char*) src;
    char* dst2 = (char*) dst;
    for (int j=0; j<sz%8; j++) {
        *(dst2+i+j) = *(src2+i+j);
    }
}

int is_aligned(void* addr) {
    return ((long)addr % FRAME_SIZE == 0);
}
