# System Abstraction Layer
## Headers (include/sal)

### alloca.h 

The alloca function allocates (as it's name suggests) temporary memory in the calling functions stack frame. As it is in the stack frame and not in the heap, it automatically gets freed when the function returns. However, it is a "dangerous" function in that if you allocate to much to the stack you can actually *run out* of stack space and your program will crash. 






