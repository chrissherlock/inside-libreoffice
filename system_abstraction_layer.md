# System Abstraction Layer
## Headers (include/sal)

### alloca.h 

The ```alloca()``` function allocates (as it's name suggests) temporary memory in the calling functions stack frame. As it is in the stack frame and not in the heap, it automatically gets freed when the function returns. However, it is a "dangerous" function in that if you allocate to much to the stack you can actually *run out* of stack space and your program will crash. 

alloca.h is included in the sal include directory because there are a variety of locations it is located - in Linux and Solaris, the function is stored in alloca.h; in OS X, BSD and iOS systems it is in sys/types.h and on Windows it is in malloc.h

*Note:* ```alloca()``` is considered dangerous because it returns a pointer to the beginning of the space that it allocates when it is called. If you pass this void＊ pointer to the calling function you may cause a stack overflow - in which case the behaviour is *undefined*. On Linux, there is also no indication if the stack frame cannot be extended. 






