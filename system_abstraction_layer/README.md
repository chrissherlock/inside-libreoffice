# System Abstraction Layer

The System Abstraction Layer (SAL) contains all the modules that contain code that is platform specific and necessary to run LibreOffice. There are really a number of modules that fall into this layer - the Runtime Library (RTL) and the Operating System Layer (OSL) are wholly included in the SAL, whilst the Visual Components Library has parts that fall into the SAL. However, it also includes a grabbag of other classes and code that don't easily fit into these modules, and includes a lightweight debug logging framework, a macro to allow for a cross-platform program entry point, some floating point support routines and macros, a cross platform type system and a number of macros that provide a way in which to support a variety of compilers, including ones that only really support C++03.

![](<../assets/sal (1).svg>)

The header files for the SAL module are distributed amongst the following directories:

* [`include/sal`](https://opengrok.libreoffice.org/xref/core/include/sal/)
* [`include/rtl`](https://opengrok.libreoffice.org/xref/core/include/rtl/)
* [`include/osl`](https://opengrok.libreoffice.org/xref/core/include/osl/)

The headers in the `include/sal` directory handle a number of pieces of functionality, described here.

## Program entry point

The `main()` entry point into LibreOffice is located in `main.h`, and is designed as a bunch of macros. As LibreOffice is a cross-platform application that runs on both Unix-based and Windows operaing systems, it must have a flexible way of starting up the program. It does this by using the C preprocessor.

The macros [`SAL_MAIN_WITH_ARGS_IMPL`](https://opengrok.libreoffice.org/xref/core/include/sal/main.h#SAL\_MAIN\_WITH\_ARGS\_IMPL) and [`SAL_MAIN_IMPL`](https://opengrok.libreoffice.org/xref/core/include/sal/main.h#SAL\_MAIN\_IMPL) both define the `main()` function of LibreOffice. The difference, as the name suggests, is that one takes arguments from the command line, and the other does not. We shall focus on `SAL_MAIN_WITH_ARGS_IMPL`as they are both exactly the same except for one function call. The macro is defined as:

```cpp
#define SAL_MAIN_WITH_ARGS_IMPL \
int SAL_DLLPUBLIC_EXPORT SAL_CALL main(int argc, char ** argv) \
{ \
    int ret; \
    sal_detail_initialize(argc, argv);   \
    ret = sal_main_with_args(argc, argv); \
    sal_detail_deinitialize(); \
    return ret; \
}
```

`SAL_MAIN_IMPL` is exactly the same, only it calls on `sal_main()` instead of `sal_main_with_args()`. These macros do the following:

1. Initializes LibreOffice through `sal_detail_initialize()`. This init function ensures that OS X closes all its file descriptors because non-sandboxed versions of LibreOffice can restart themselves (normally when [updating extensions](https://bugs.documentfoundation.org/show\_bug.cgi?id=50603)), but not close all their descriptors. It initializes the global timer, and on systems that have syslog sets this up for logging. It then prepares the command line arguments.&#x20;
2. Runs `sal_main_with_args()` which runs the main LibreOffice program logic
3. When `sal_main_with_args()` ends, it calls on `sal_detail_deinitialize()`
4. Returns an exit code and closes the application

This works across Windows and other platforms because the implementation macro calls `SAL_MAIN_WITH_ARGS_IMPL` and `SAL_MAIN_IMPL` ensure that `WinMain()` is defined on Windows systems, and expands to nothing on non-Windows systems. `WinMain()` on Windows systems is the default entry-point of the Windows C Runtime Library (Windows CRT) - LibreOffice does all the heavy lifting in `sal_main()`, which you define using the `SAL_MAIN_WITH_ARGS_IMPL` and `SAL_MAIN_IMPL` macros like this:

```cpp
#include <sal/main.h>
SAL_IMPLEMENT_MAIN()
{
    DoSomething();
    return 0;
}

SAL_IMPLEMENT_MAIN_WITH_ARGS(argc, argv)
{
    DoSomethingWithArgs(argc, argv);
    return 0;
}
```

## macro.h

A number of primitive macros are defined:

| Name             | Description                                            |
| ---------------- | ------------------------------------------------------ |
| `SAL_N_ELEMENTS` | Gets the number of elements in an array                |
| `SAL_BOUND`      | Checks to see if the value is between two other values |
| `SAL_ABS`        | Gets the absolute value of the number                  |
| `SAL_STRINGIFY`  | Takes a token and turns it into an escaped string      |

## Type system

The `include/sal/types.h` header contains a number of macros, typedefs and namespace aliases that allow LibreOffice to be cross-platform - and even build under different compilers. The compilers supported are:

* gcc
* clang
* MinGW
* Microsoft Visual C/C++

A particularly useful shortcut was added by Michael Meeks in v4.0 - it aliases the namespace com.sun.star to css. You will find yourself using this frequently as you interact with UNO and the API.

A number of types are defined for portability reasons:

| Name          | Equivalent C type                                                                     |    Size (bytes) | Format specifier       |
| ------------- | ------------------------------------------------------------------------------------- | --------------: | ---------------------- |
| `sal_Bool`    | `unsigned char` †                                                                     |               1 | %c or %hhu             |
| `sal_Int8`    | `signed char`                                                                         |               1 | %c or %hhi             |
| `sal_uInt8`   | `unsigned char`                                                                       |               1 | %c or %hhu             |
| `sal_Int16`   | `signed short`                                                                        |               2 | %hi                    |
| `sal_uInt16`  | `unsigned short`                                                                      |               2 | %hu                    |
| `sal_Int32`   | `signed long`   `signed int` ††                                                       |               4 | `SAL_PRIdINT32`        |
| `sal_uInt32`  | `unsigned long`   `unsigned int` ††                                                   |               4 | `SAL_PRIuUINT32`       |
| `sal_Int64`   | `__int64` (Windows)                                                                   |               8 | `SAL_PRIdINT64`        |
| `sal_Int64`   | `signed long int`   `signed long long` (GNU C) †††                                    |                 | `SAL_CONST_INT64`      |
| `sal_uInt64`  | `unsigned __int64` (Windows)   `unsigned long int`   `unsigned long long` (GNU C) ††† |               8 | `SAL_PRIuUNIT64`       |
| `sal_Unicode` | `wchar_t` (Windows) ††††   `sal_uInt16` (non-Windows) †††††                           |               2 | Depends on platform... |
| `sal_Handle`  | `void *`                                                                              | size of pointer | n/a                    |
| `sal_Size`    | `sal_uInt32`   `sal_uInt64`                                                           |    native width | `SAL_PRI_SIZET`        |
| `sal_sSize`   | `sal_Int32`   `sal_Int64`                                                             |    native width | `SAL_PRI_SIZET`        |
| `sal_PtrDiff` | result of pointer subtraction                                                         |    native width | `SAL_PRI_PTRDIFFT`     |
| `sal_IntPtr`  | native width of integers                                                              | size of pointer | `SAL_PRIdINTPTR`       |
| `sal_uIntPtr` | native width of integers                                                              | size of pointer | `SAL_PRIuUINTPTR`      |

† `sal_Bool` is deprecated in favour of `bool`, however it is still used in the UNO API so cannot be completely removed. All code other than the API should use bool

†† on 32-bit architectures `int` is 4 bytes wide, but on 64-bit architectures a `long` is 4 bytes wide (a `long` is also called a `long int`)

††† on 32-bit architectures, a `long int` is 8 bytes wide, but as a `long int` is 4 bytes wide on a 64-bit architecture, a `long long` is needed for 8 byte wide longs

†††† on Windows, `wchar_t` is a typedef to `unsigned int`, however MinGW has a native `wchar_t` which is the reason for this

††††† in internal code, `sal_Unicode` points to `char16_t`

There are a few types that are now deprecated:

| Name        | Equivalent C type |
| ----------- | ----------------- |
| `sal_Char`  | `char`            |
| `sal_sChar` | `signed char`     |
| `sal_uChar` | `unsigned char`   |

A number of macros have also been defined to get the maximum values of int types. The macros have the form `SAL_MIN_[U]INT*<bit-width>*` and `SAL_MAX_[U]INT*<bit-width>*`. The macros assume that the `sal_Int\*` types use two's complement to represent the numbers.

There are also a number of function attributes macros that have been defined, in order to be cross platform and utilize compiler features when they are available:

| Name                     | Function attribute                                                                      | Compiler             |
| ------------------------ | --------------------------------------------------------------------------------------- | -------------------- |
| `SAL_DLLPUBLIC_EXPORT`   | `__declspec(dllexport)`                                                                 | Microsoft C          |
| `SAL_DLLPUBLIC_EXPORT`   | `__attribute__((visibility("hidden")))` †   `__attribute__((visibility("default")))` †† | GNU C   Clang        |
|                          |                                                                                         |                      |
| `SAL_JNI_EXPORT`         | `__declspec(dllexport)`                                                                 | Microsoft C          |
| `SAL_JNI_EXPORT`         | `__attribute__((visibility("default")))`                                                | GNU C   Clang        |
| `SAL_DLLPUBLIC_IMPORT`   | `__declspec(dllimport)`                                                                 | Microsoft C          |
| `SAL_DLLPUBLIC_IMPORT`   | `__attribute__((visibility("hidden")))` †   `__attribute__((visibility("default")))` †† | GNU C   Clang        |
| `SAL_DLLPRIVATE`         | `__attribute__((visibility("hidden")))`                                                 | GNU C   Clang        |
| `SAL_DLLPUBLIC_TEMPLATE` | `__attribute__((visibility("hidden")))` †   `__attribute__((visibility("default")))` †† | GNU C   Clang        |
| `SAL_DLLPUBLIC_RTTI`     | `__attribute__((type_visibility("default")))`                                           | Clang                |
| `SAL_DLLPUBLIC_RTTI`     | `__attribute__((visibility("default)))`                                                 | GNU C                |
| `SAL_CALL`               | `__cdecl`                                                                               | Microsoft C          |
| `SAL_CALL_ELLIPSE`       | `__cdecl`                                                                               | Microsoft C          |
| `SAL_WARN_UNUSED`        | `__attribute__((warn_unused_result))`                                                   | GNU C >= 4.1   Clang |
| `SAL_NO_VTABLE`          | `__declspec(novtable)`                                                                  | Microsoft C          |

† if dynamic library loading is disabled

†† if dynamic library loading is enabled

Function attributes for exception handling on GCC (but not MinGW) are:

| Name                             | Function attribute                                                     |
| -------------------------------- | ---------------------------------------------------------------------- |
| `SAL_EXCEPTION_DLLPUBLIC_EXPORT` | `__attribute__((visibility("default")))` †   `SAL_DLLPUBLIC_EXPORT` †† |

† if dynamic library loading is disabled

†† if dynamic library loading is enabled

## `alloca()`

The `alloca()` function allocates (as its name suggests) temporary memory in the calling functions stack frame. As it is in the stack frame and not in the heap, it automatically gets freed when the function returns. However, it is a "dangerous" function in that if you allocate too much to the stack you can actually _run out_ of stack space and your program will crash.

The `alloca()` function, however, resides in a variety of locations on different operating systems - on Linux and Solaris, the function is stored in `alloca.h`; in OS X, BSD and iOS systems it is in `sys/types.h` and on Windows it is in `malloc.h`. Due to this quirk, LibreOffice defines its own `alloca.h` in `include/sal/alloca.h`

_Note:_ `alloca()` is considered dangerous because it returns a pointer to the beginning of the space that it allocates when it is called. If you pass this `void*` pointer to the calling function you may cause a stack overflow - in which case the behaviour is _undefined_. On Linux, there is also no indication if the stack frame cannot be extended.

## Seeing it in action

I have written some programs you can take from the branch `private/tbsdy/workbench`. To get them, do the following:

`git checkout private/tbsdy/workbench`

From the `core` directory, you can run each of the programs via `bin/run <programname>`.

| Program     | Description                            | Source files                  | How to invoke         |
| ----------- | -------------------------------------- | ----------------------------- | --------------------- |
| salmain     | Cross platform `main()`                | `sal/workben/salmain.cxx`     | `bin/run salmain`     |
| salmainargs | Cross platform `main()` with arguments | `sal/workben/salmainargs.cxx` | `bin/run salmainargs` |
| config      | Shows platform specific quirks         | `sal/workben/config.cxx`      | `bin/run config`      |
| macro       | A variety of useful sal macros         | `sal/workben/macro.cxx`       | `bin/run macro`       |
| alloca      | Show how `alloca()` function works     | `sal/workben/alloca.cxx`      | `bin/run alloca`      |
