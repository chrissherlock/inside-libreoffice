# System Abstraction Layer
## Headers (include/sal)

### macro.h
A number of primitive macros are defined
| Name           | Description                               |
| ---------------| ------------------------------------------|
| SAL_N_ELEMENTS | Gets the number of elements in an array   |
| SAL_BOUND      | Checks to see if the value is between two |
|                | other values                              |
| SAL_ABS        | Gets the absolute value of the number     |
| SAL_STRINGIFY  | Takes a token and turns it into an        |
|                | escaped string                            |

### types.h
A number of types are nailed down:
| Name       | Equiv C++ type | Size in bytes |
| --------  -| ---------------| --------------|
| sal_Bool   | bool           | 1             |
| sal_Int8   | unsigned char  | 1             |
| sal_uInt8  |


### alloca.h 

The ```alloca()``` function allocates (as it's name suggests) temporary memory in the calling functions stack frame. As it is in the stack frame and not in the heap, it automatically gets freed when the function returns. However, it is a "dangerous" function in that if you allocate to much to the stack you can actually *run out* of stack space and your program will crash. 

alloca.h is included in the sal include directory because there are a variety of locations it is located - in Linux and Solaris, the function is stored in alloca.h; in OS X, BSD and iOS systems it is in sys/types.h and on Windows it is in malloc.h

*Note:* ```alloca()``` is considered dangerous because it returns a pointer to the beginning of the space that it allocates when it is called. If you pass this void＊ pointer to the calling function you may cause a stack overflow - in which case the behaviour is *undefined*. On Linux, there is also no indication if the stack frame cannot be extended. 






