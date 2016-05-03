# System Abstraction Layer
## Headers (include/sal)
### macro.h
A number of primitive macros are defined:

| Name                 | Description                                            |
|----------------------|--------------------------------------------------------|
| ```SAL_N_ELEMENTS``` | Gets the number of elements in an array                |
| ```SAL_BOUND```      | Checks to see if the value is between two other values |
| ```SAL_ABS```        | Gets the absolute value of the number                  |
| ```SAL_STRINGIFY```  | Takes a token and turns it into an escaped string      |

### types.h
A number of types are defined for portability reasons:

| Name              | Equivalent C type               | Size (bytes) | Format specifier       |
|-------------------|---------------------------------|-------------:|------------------------|
| ```sal_Bool```    | unsigned char †                 |            1 | %c or %hhu             |
| ```sal_Int8```    | signed char                     |            1 | %c or %hhi             |
| ```sal_uInt8```   | unsigned char                   |            1 | %c or %hhu             |
| ```sal_Int16```   | signed short                    |            2 | %hi                    |
| ```sal_uInt16```  | unsigned short                  |            2 | %hu                    |
| ```sal_Int32```   | signed long /                   |            4 | ```SAL_PRIdINT32```    |
|                   | signed int ††                   |              |                        |
| ```sal_uInt32```  | unsigned long /                 |            4 | ```SAL_PRIuUINT32```   |
|                   | unsigned int ††                 |              | ```SAL_PRIxUINT32```   |
|                   |                                 |              | ```SAL_PRIXUNIT32```   |
| ```sal_Int64```   | \_\_int64 (Windows)             |            8 | ```SAL_PRIdINT64```    |
|                   | signed long int /               |              | ```SAL_CONST_INT64```  |
|                   | signed long long (GNU C) †††    |              |                        |
| ```sal_uInt64```  | unsigned \_\_int64 (Windows)    |            8 | ```SAL_PRIuUNIT64```   |
|                   | unsigned long int /             |              | ```SAL_PRIxUNIT64```   |
|                   | unsigned long long (GNU C) †††  |              | ```SAL_PRIXUNIT64```   |
|                   |                                 |              | ```SAL_CONST_UINT64``` |
| ```sal_Unicode``` | wchar_t (Windows) ††††          |            2 | Depends on platform... |
|                   | sal_uInt16 (non-Windows) †††††  |              |                        |
| ```sal_Handle```  | void *                          |      size of | n/a                    |
|                   |                                 |      pointer |                        |
| ```sal_Size```    | sal_uInt32 / sal_uInt64         | native width | SAL_PRI_SIZET          |
| ```sal_sSize```   | sal_Int32 / sal_Int64           | native width | SAL_PRI_SIZET          |
| ```sal_PtrDiff``` | result of pointer subtraction   | native width | SAL_PRI_PTRDIFFT       |
| ```sal_IntPtr```  | native width of integers        |      size of | SAL_PRIdINTPTR         |
|                   |                                 |      pointer |                        |
| ```sal_uIntPtr``` | native width of integers        |      size of | SAL_PRIuUINTPTR        |
|                   |                                 |      pointer | SAL_PRIxUNITPTR        |
|                   |                                 |              | SAL_PRIXUNITPTR        |

† ```sal_Bool``` is deprecated in favour of ```bool```, however it is still used in the UNO API so cannot be completely removed. All code other than the API should use bool
†† On 32-bit architectures ```int``` is 4 bytes wide, but on 64-bit architectures a ```long``` is 4 bytes wide (a ```long``` is also called a ```long int```)
††† On 32-bit architectures, a ```long int``` is 8 bytes wide, but as a ```long int``` is 4 bytes wide on a 64-bit architecture, a ```long long``` is needed for 8 byte wide longs
†††† on Windows, ```wchar_t``` is a typedef to ```unsigned int```, however MinGW has a native ```wchar_t``` which is the reason for this
††††† in internal code, ```sal_Unicode``` points to ```char16_t```

There are a few types that are now deprecated:

| Name             | Equivalent C type               |
|------------------|---------------------------------|
| ```sal_Char```   | char                            |
| ```sal_sChar```  | signed char                     |
| ```sal_uChar```  | unsigned char                   |

There are also a number of function attributes macros that have been defined, in order to be cross platform and utilize compiler features when they are available:

| Name                        | Function attribute                             | Compiler     | 
|-----------------------------|------------------------------------------------|--------------|
| ```SAL_DLLPUBLIC_EXPORT```  | \_\_declspec(dllexport)                        | Microsoft C  |
|                             |                                                | MinGW        |
|                             | \_\_attribute\_\_((visibility("hidden"))) †    | GNU C, Clang |
|                             | \_\_attribute\_\_((visibility("default"))) ††  |              |
| ```SAL_JNI_EXPORT```        | \_\_declspect(dllexport)                       | Microsoft C  |
|                             |                                                | MinGW        |
|                             | \_\_attribute\_\_((visibility("default")))     | GNU C, Clang | 
| ```SAL_DLLPUBLIC_IMPORT```  | \_\_declspec(dllimport)                        | Microsoft C  |
|                             |                                                | MinGW        |
|                             | \_\_attribute\_\_((visibility("hidden"))) †    | GNU C, Clang |
|                             | \_\_attribute\_\_((visibility("default"))) ††  |              |
| ```SAL_DLLPRIVATE```        | \_\_attribute\_\_((visibility("hidden")))      | GNU C, Clang |
| ```SAL_DLLPUBLIC_TEMPLATE```| \_\_attribute\_\_((visibility("hidden"))) †    | GNU C, Clang |
|                             | \_\_attribute\_\_((visibility("default"))) ††  | GNU C, Clang |
| ```SAL_DLLPUBLIC_RTTI```    | \_\_attribute\_\_((type_visibility("default")))| Clang        |
|                             | \_\_attribute\_\_((visibility("default")))     | GNU C        |
| ```SAL_CALL```              | \_\_cdecl                                      | Microsoft C  |
|                             |                                                | MinGW        |
| ```SAL_CALL_ELLIPSE```      | \_\_cdecl                                      | Microsoft C  |
|                             |                                                | MinGW        |
| ```SAL_WARN_UNUSED```       | \_\_attribute\_\_((warn_unused_result))        | GNU C >= 4.1 |
|                             |                                                | Clang        |
| ```SAL_NO_VTABLE```         | \_\_declspec(novtable)                         | Microsoft C  |

† if dynamic library loading is disabled
†† if dynamic library loading is enabled 

Function attributes for exception handling on GCC (but not MinGW) are:

| Name                                 | Function attribute                             |
|--------------------------------------|------------------------------------------------|
| ```SAL_EXCEPTION_DLLPUBLIC_EXPORT``` | \_\_attribute\_\_((visibility("default"))) †   |
|                                      | ```SAL_DLLPUBLIC_EXPORT``` ††                  |

† if dynamic library loading is disabled
†† if dynamic library loading is enabled 

### alloca.h 

The ```alloca()``` function allocates (as it's name suggests) temporary memory in the calling functions stack frame. As it is in the stack frame and not in the heap, it automatically gets freed when the function returns. However, it is a "dangerous" function in that if you allocate to much to the stack you can actually *run out* of stack space and your program will crash. 

alloca.h is included in the sal include directory because there are a variety of locations it is located - in Linux and Solaris, the function is stored in alloca.h; in OS X, BSD and iOS systems it is in sys/types.h and on Windows it is in malloc.h

*Note:* ```alloca()``` is considered dangerous because it returns a pointer to the beginning of the space that it allocates when it is called. If you pass this void＊ pointer to the calling function you may cause a stack overflow - in which case the behaviour is *undefined*. On Linux, there is also no indication if the stack frame cannot be extended. 






