#define FRAME_SIZE 0x1000

void kinit();
void* kalloc();
int kfree(void* addr);
