# Inter-Process Communication (IPC)

Most modern operating systems have designed processes such that they are protected from other operating system processes, a concept called _process isolation_. This is done for stability and security reasons, however it may be necessary for one process to communicate with another process, and a variety of mechanisms have been developed to allow for this. The concept of processes communicating with each other is referred to as _Inter-Process Communication_, or more commonly abbreviated to _IPC_.

Most operating systems implement IPC, albeit with subtle differences, via signals, sockets, message queues, pipes (named and anonymous), shared memory and memory-mapped files. As a cross-platform product, LibreOffice attempts to unify each operating system's IPC functionality via the OSL API.

## Signals

A signal sends an asynchronous notification to a process to notify it that an event has occurred. Under Unix and Unix-like systems a process registers a signal handler to process the signal via the `signal()` or `sigaction()` system call. Usage of `signal()` is not encouraged, instead it is recommended that `sigaction()` be used. If a signal is not register, the default handler processes the signal. Processes can handle signals without creating a specific signal handler by either ignoring the signal (`SIG_IGN`) or by passing it to the default signal handler (`SIG_DFL`). The only signals that cannot be intercepted and handled are `SIGKILL` and `SIGSTOP`. Signals can be blocked via `sigprocmask()`, which means that these signals are not delivered to the process until they are unblocked.

The OSL uses Windows structured exception handling as a means to emulate signals. Exceptions in Windows are much the same as signals are in Unix - and can be initiated by hardware or software. In Windows, however, exceptions can be classified as _continuable_ or _noncontinuable_ where it makes sense - a noncontinuable exception will terminate the application. Windows also allows for nested exceptions, which are exceptions held in a linked-list.

The OSL uses frame-based exception handling. Each process has what is known as a call stack, which consists of (as the name suggests) a _stack_ of _frames_. A _frame_ is a set of data that is pushed onto the stack, the data being varied but always consists of a return address. When a subroutine is called, it _pushes_ a frame onto the stack - the frame holding the return address of the routine that pushed the frame. When the new subroutine finishes, it _pops_ its frame from the stack and returns execution to the return address of the calling routine. In Windows, each stack frame stores an exception handler. When an exception is thrown, Windows examines each stack frame until it finds a suitable exception handler. If no exception handler can be found, then it looks for a top level exception handler, which is registered via `SetUnhandledExceptionFilter()` - this can be considered the equivalent of a default signal handler in Unix. 

To add a signal handler in OSL, you call on the `osl_addSignalHandler()` function. The function works across all platforms (it is located in [`core/sal/osl/all/signalshared.cxx`](http://opengrok.libreoffice.org/xref/core/sal/osl/all/signalshared.cxx#osl_addSignalHandler)), and calls on the platform specific `onInitSignal()` function. Once the signal has been initialized, it sets up the signal handler by allocating the `oslSignalHandlerFunction` function pointer and associated signal handling data to a `oslSignalHandler` function, which it safely appends onto the end of a linked list of signal handlers (safely, because it acquires a mutex during this operation).

```cpp
oslSignalHandler SAL_CALL osl_addSignalHandler(oslSignalHandlerFunction handler, void* pData)
{
    if (!handler)
        return nullptr;

    if (!bInitSignal)
        bInitSignal = initSignal();

    oslSignalHandlerImpl* pHandler = static_cast<oslSignalHandlerImpl*>(calloc(1, sizeof(oslSignalHandlerImpl)));

    if (pHandler)
    {
        pHandler->Handler = handler;
        pHandler->pData = pData;

        osl_acquireMutex(SignalListMutex);

        pHandler->pNext = SignalList;
        SignalList = pHandler;

        osl_releaseMutex(SignalListMutex);

        return pHandler;
    }

    return nullptr;
}

bool initSignal()
{
    SignalListMutex = osl_createMutex();

    return onInitSignal();
}
```

So far, so easy... but the platform specific implementations are where the warts start to show, especially the Unix version.

The wrinkle, as seems to often be the case, is Java. The issue is that Java intercepts SIGSEGV, but then so does LibreOffice as it also processes SIGSEGV for a "crashguard". So as part of an incredible hack, OSL checks the process name to see if it starts with "soffice", and if it does then it special-cases this process by setting the SIGSEGV, SIGWINCH and SIGILL handlers to process as normal, and Java can then override these when it starts up - otherwise it ignores these signals.

Interestingly, before the year 2000 it appears there was a Tomcat server in use called `stomcatd` - the code [originally looked for either `stomcatd` or `soffice`](https://cgit.freedesktop.org/libreoffice/core/plain/sal/osl/unx/signal.c?id=9399c662f36c385b0c705eb34e636a9aec450282) which was a "Portal Demo HACK", but this was [later removed](https://cgit.freedesktop.org/libreoffice/core/commit/sal/osl/unx/signal.c?id=0a1cc7826beade023be930ac966a465c11819d55) as it was entirely unclear what this was all about.

The Unix `onInitSignal()` currently checks if the process is `soffice`, if it is then it sets up the crash handler signals, hooking into the segmentation fault (SIGSEGV), window change (SIGWINCH) and illegal instruction (SIGILL) instructions. This is because if a JVM is loaded, then it needs to intercept these signals and it shouldn't be overridden in any other situation. Ideally, this should be moved into soffice specific code.

The Windows `onInitSignal()` sets the unhandled exception filter handler to `signalHandlerFunction()`. Then it excludes the application from error reporting. Except that `AddERExcludedApplicationW()` is now deprecated, and needs to be changed to `WerAddExcludedApplication()`, as part of the Windows Error Reporting module (WER).

```cpp
bool onInitSignal()
{
    pPreviousHandler = SetUnhandledExceptionFilter(signalHandlerFunction);

    HMODULE hFaultRep = LoadLibrary( "faultrep.dll" );
    if ( hFaultRep )
    {
        pfn_ADDEREXCLUDEDAPPLICATIONW pfn = reinterpret_cast<pfn_ADDEREXCLUDEDAPPLICATIONW>(GetProcAddress( hFaultRep, "AddERExcludedApplicationW" ));
        if ( pfn )
            pfn( L"SOFFICE.EXE" );
        FreeLibrary( hFaultRep );
    }

    return true;
}
```

When done with the signal handler, you should remove the signal handler via the function `osl_removeSignalHandler()`. This acquires a mutex on the signal handler, removes the handler from the linked list, frees the memory taken by the handler and then releases the signal handler mutex.

To raise a signal, call on `osl_raiseSignal()`.

## Memory-mapped files

Memory mapped files allow a file to be mapped into a process's virtual address space, and thus be manipulated and read as if reading memory. The benefits of such an approach are mainly that they allow large files to be processed more efficiently - instead of loading the entire file into memory, the file is loaded via the operating system's Virtual Memory Manager (VMM) - which means that the entire file does not need to be loaded into memory, but large portions of the file that are mapped to the virtual address space can be paged to disk. In terms of IPC, however, it also means that multiple processes can map independent portions of the file to a common region in the system's pagefile via the VMM, and thus share data between process boundaries.

### Windows implementation
On Windows, a file is mapped through the following process:

1. First create a file mapping object via `CreateFileMapping()`. This returns a handle to the object, which you use to map the file.
2. A mapping _view_ can then be established, which maps the view to the process' address space. This is done via the function `MapViewOfFile()`
3. When done with the file mapping, use `CloseHandle()`.

Thus, the function to map the file on Windows is as follows:

```cpp
oslFileError SAL_CALL osl_mapFile(
    oslFileHandle Handle,
    void** ppAddr,
    sal_uInt64 uLength,
    sal_uInt64 uOffset,
    sal_uInt32 uFlags)
{
```

An internal file mapping structure is used as an RAII object. RAII stands for "Resource acquisition is initialization", or in other words once you create the object ("acquire" the object via the constructor) then the object is initialized, and similarly when the object is deleted it releases all its resources. In this case, the FileMapping struct assigns a handle in the constructor and when the FileMapping instance is finished with it closes the handle in the destructor.

```cpp
    struct FileMapping
    {
        HANDLE m_handle;

        explicit FileMapping (HANDLE hMap)
        : m_handle (hMap)
        {}

        ~FileMapping()
        {
            (void)::CloseHandle(m_handle);
        }
    };
```

The function passes the file handle to the function, which then casts it to a Windows-specific FileHandle_Impl instance.

```cpp
    FileHandle_Impl * pImpl = static_cast<FileHandle_Impl*>(Handle);
    if ((pImpl) || !IsValidHandle(pImpl->m_hFile) || (ppAddr))
        return osl_File_E_INVAL;
```

The `ppAddr` parameter holds the mapped address in memory, and is initialized to a nullptr.

```cpp
    *ppAddr = nullptr;
```

The mapping length is checked to ensure that it isn't larger than the maximum size allowed.

```cpp
    static SIZE_T const nLimit = std::numeric_limits< SIZE_T >::max();
    if (uLength > nLimit)
        return osl_File_E_OVERFLOW;
    SIZE_T const nLength = sal::static_int_cast< SIZE_T >(uLength);
```

Now comes the file mapping, by instantiating a FileMapping instance. Here you can see the RAII pattern at work - `CreateFileMapping(pImpl->m_hFile, nullptr, SEC_COMMIT | PAGE_READONLY, 0, 0, nullptr)` is used:

* `pImpl->m_hFile`: pImpl holds the file `HANDLE` in `m_hFile`
* `nullptr`: this means that the file handle cannot be inherited, and uses a default security descriptor
* `SEC_COMMIT` and `PAGE_READONLY` - the page allocated allows read and copy-on-write access, and does not allow writing to a region of the file mapping. Furthermore, when the file is mapped into the process's address space, all the pages in the range are committed rather than just reserved.
* the fourth and fifth parameters are set to zero, which means that the maximum size of the file mapping is the equal to the size of the file being mapped
* the last parameter, which specifies the mapping name, is set to nullptr - this is an optional parameter, and makes an anonymous file mapping

```cpp
    FileMapping aMap( ::CreateFileMapping (pImpl->m_hFile, nullptr, SEC_COMMIT | PAGE_READONLY, 0, 0, nullptr) );
    if (!IsValidHandle(aMap.m_handle))
        return oslTranslateFileError( GetLastError() );
```

The file's view is then mapped to the process address space via the `MapViewOfFile()` function. This function takes the following parameters:

* `aMap.m_Handle`: `aMap` holds the handle, which is `m_Handle`
* `FILE_MAP_READ`: the mapped file is set to read-only, if a write access was to occur then an access violation would occur.
* To get the file offset, a HIWORD and a LOWORD are used to form a 64-bit address. Thus the hiword takes the address of `uOffset` and right shifts it 32 bits, then casts it to a 32-bit integer; to get the loword it takes the 64-bit address `uOffset` and masks out the upper 32 bits to give the lower 32 bit value, then casts this value to a 32-bit int.
* The length to map the file from the offset is set via `nLength`

```cpp
    DWORD const dwOffsetHi = sal::static_int_cast<DWORD>(uOffset >> 32);
    DWORD const dwOffsetLo = sal::static_int_cast<DWORD>(uOffset & 0xFFFFFFFF);

    *ppAddr = ::MapViewOfFile(aMap.m_handle, FILE_MAP_READ, dwOffsetHi, dwOffsetLo, nLength);
    if (nullptr == *ppAddr)
        return oslTranslateFileError( GetLastError() );
```
The final piece of the puzzle is to check if the file mapping will be access in a random access fashion. If so, then because the file mapping specified `SEC_COMMIT`, if you read just the first byte of the page then it will commit the entire page to memory rather than just reserve the memory and commit it later. Note that to stop the compiler from optimizing away the loop, they have had to set the `c` `BYTE` variable to volatile.

A note about why the `volatile` works: it works because on each loop, a new volatile BYTE is created. The [rules for volatile variables](http://en.cppreference.com/w/cpp/language/cv) are that "volatile accesses cannot be optimized out or reordered with another visible side effect that is sequenced-before or sequenced-after the volatile access." Thus the loop cannot be optimized away by the compiler.

```
    if (uFlags & osl_File_MapFlag_RandomAccess)
    {
        // Determine memory pagesize.
        SYSTEM_INFO info;
        ::GetSystemInfo( &info );
        DWORD const dwPageSize = info.dwPageSize;

        /*
         * Pagein, touching first byte of each memory page.
         * Note: volatile disables optimizing the loop away.
         */
        BYTE * pData (static_cast<BYTE*>(*ppAddr));
        SIZE_T nSize (nLength);

        volatile BYTE c = 0;
        while (nSize > dwPageSize)
        {
            c ^= pData[0];
            pData += dwPageSize;
            nSize -= dwPageSize;
        }
        if (nSize > 0)
        {
            c ^= pData[0];
        }
    }
    return osl_File_E_None;
}
```

To unmap the file on Windows, it is quite simple - you just call on `UnmapViewOfFile()`:

```cpp
oslFileError SAL_CALL osl_unmapFile(void* pAddr, sal_uInt64 /* uLength */)
{
    if (!pAddr)
        return osl_File_E_INVAL;

    if (!::UnmapViewOfFile(pAddr))
        return oslTranslateFileError(GetLastError());

    return osl_File_E_None;
}
```

### Unix implementation

On Unix systems, a file is mapped in the virtual address space of the calling process via the `mmap()` function:

```c
void *mmap(void *addr, size_t length, int prot, int flags,
           int fd, off_t offset);
```

This function takes as the first parameter a hint to the address of where to place the mapping in memory - if this is NULL then the operating system automatically works out where to allocate the memory, otherwise it places it at the nearest page boundary to the address. The function's second paramter takes the size of the file to be mapped, and the third parameter determines the desired memory protection for the mapping  - basically it determines whether the mapping allows pages to be executed, read from or written to (`PROT_EXEC`, `PROT_READ` and `PROT_WRITE`, consecutively. `PROT_NONE` specifies that the page cannot be accessed at all). The function also determines via the fourth parameter if the mapping can be shared (`MAP_SHARED`), or if updates to the mapping are not exposed to other processes (`MAP_PRIVATE`). The file itself is specified by the `fd` parameter, with an offset into the file by the final parameter `offset`.

`mmap()` returns a pointer to the mapped area on success, and on failure it returns `MAP_FAILED` (`(void *) -1`) and sets `errno` to the error code.

To delete the file mappings, you call on the `munmap()` function:

```c
int munmap(void *addr, size_t length);
```

A region of memory is unmapped by the `addr` pointer - which must be a multiple of the page size - and the size of the area to unmap is specified by the `length` parameter. `munmap()` returns -1 and populates `errno` on failure, and 0 on success. 

Consequently, to 


## Pipes

## Sockets