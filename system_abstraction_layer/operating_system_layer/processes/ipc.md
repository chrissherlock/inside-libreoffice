# IPC

Most modern operating systems have designed processes such that they are protected from other operating system processes, a concept called _process isolation_. This is done for stability and security reasons, however it may be necessary for one process to communicate with another process, and a variety of mechanisms have been developed to allow for this. The concept of processes communicating with each other is referred to as _Inter-Process Communication_, or more commonly abbreviated to _IPC_.

Most operating systems implement IPC, albeit with subtle differences, via signals, sockets, message queues, pipes \(named and anonymous\), shared memory and memory-mapped files. As a cross-platform product, LibreOffice attempts to unify each operating system's IPC functionality via the OSL API.

## Signals

A signal sends an asynchronous notification to a process to notify it that an event has occurred. Under Unix and Unix-like systems a process registers a signal handler to process the signal via the `signal()` or `sigaction()` system call. Usage of `signal()` is not encouraged, instead it is recommended that `sigaction()` be used. If a signal is not register, the default handler processes the signal. Processes can handle signals without creating a specific signal handler by either ignoring the signal \(`SIG_IGN`\) or by passing it to the default signal handler \(`SIG_DFL`\). The only signals that cannot be intercepted and handled are `SIGKILL` and `SIGSTOP`. Signals can be blocked via `sigprocmask()`, which means that these signals are not delivered to the process until they are unblocked.

The OSL uses Windows structured exception handling as a means to emulate signals. Exceptions in Windows are much the same as signals are in Unix - and can be initiated by hardware or software. In Windows, however, exceptions can be classified as _continuable_ or _noncontinuable_ where it makes sense - a noncontinuable exception will terminate the application. Windows also allows for nested exceptions, which are exceptions held in a linked-list.

The OSL uses frame-based exception handling. Each process has what is known as a call stack, which consists of \(as the name suggests\) a _stack_ of _frames_. A _frame_ is a set of data that is pushed onto the stack, the data being varied but always consists of a return address. When a subroutine is called, it _pushes_ a frame onto the stack - the frame holding the return address of the routine that pushed the frame. When the new subroutine finishes, it _pops_ its frame from the stack and returns execution to the return address of the calling routine. In Windows, each stack frame stores an exception handler. When an exception is thrown, Windows examines each stack frame until it finds a suitable exception handler. If no exception handler can be found, then it looks for a top level exception handler, which is registered via `SetUnhandledExceptionFilter()` - this can be considered the equivalent of a default signal handler in Unix.

To add a signal handler in OSL, you call on the `osl_addSignalHandler()` function. The function works across all platforms \(it is located in [`core/sal/osl/all/signalshared.cxx`](http://opengrok.libreoffice.org/xref/core/sal/osl/all/signalshared.cxx#osl_addSignalHandler)\), and calls on the platform specific `onInitSignal()` function. Once the signal has been initialized, it sets up the signal handler by allocating the `oslSignalHandlerFunction` function pointer and associated signal handling data to a `oslSignalHandler` function, which it safely appends onto the end of a linked list of signal handlers \(safely, because it acquires a mutex during this operation\).

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

The Unix `onInitSignal()` currently checks if the process is `soffice`, if it is then it sets up the crash handler signals, hooking into the segmentation fault \(SIGSEGV\), window change \(SIGWINCH\) and illegal instruction \(SIGILL\) instructions. This is because if a JVM is loaded, then it needs to intercept these signals and it shouldn't be overridden in any other situation. Ideally, this should be moved into soffice specific code.

The Windows `onInitSignal()` sets the unhandled exception filter handler to `signalHandlerFunction()`. Then it excludes the application from error reporting. Except that `AddERExcludedApplicationW()` is now deprecated, and needs to be changed to `WerAddExcludedApplication()`, as part of the Windows Error Reporting module \(WER\).

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

### Example

```cpp
#include <sal/main.h>
#include <osl/signal.h>

#include <cstdio>

#define OSL_SIGNAL_USER_TEST1   (OSL_SIGNAL_USER_RESERVED - 64)

typedef struct
{
    sal_uInt32 nData;
} SignalData;

oslSignalAction SignalHandlerFunc1(void *pData, oslSignalInfo* pInfo);
oslSignalAction SignalHandlerFunc2(void *pData, oslSignalInfo* pInfo);

SAL_IMPLEMENT_MAIN()
{
    fprintf(stdout, "Signal handling example.\n");
    fprintf(stdout, "    Before the signal nData == 0, after the signal nData == 1\n");

    oslSignalHandler hHandler1, hHandler2;
    SignalData aSigData;
    aSigData.nData = 0;

    fprintf(stdout, "        Adding signal handler 1\n");
    hHandler1 = osl_addSignalHandler(SignalHandlerFunc1, &aSigData);

    fprintf(stdout, "        Signal data set to %d.\n", aSigData.nData);

    SignalData aSetSigData;
    aSetSigData.nData = 1;
    osl_raiseSignal(OSL_SIGNAL_USER_TEST1, &aSetSigData);

    fprintf(stdout, "    Before the signal nData == 0, after the signal nData == 2\n");
    fprintf(stdout, "        Signal data set to %d.\n", aSigData.nData);

    // add a second signal handler that increments the counter...
    fprintf(stdout, "        Adding signal handler 2\n");
    hHandler2 = osl_addSignalHandler(SignalHandlerFunc2, &aSigData);

    aSigData.nData = 0;
    fprintf(stdout, "        Signal data set to %d.\n", aSigData.nData);

    osl_raiseSignal(OSL_SIGNAL_USER_TEST1, &aSetSigData);

    fprintf(stdout, "        Signal data set to %d.\n", aSigData.nData);

    fprintf(stdout, "    Remove signal handlers.\n");
    osl_removeSignalHandler(hHandler1);
    osl_removeSignalHandler(hHandler2);

    return 0;
}

oslSignalAction SignalHandlerFunc1(void *pData, oslSignalInfo* pInfo)
{
    SignalData *pSignalData = reinterpret_cast< SignalData* >(pData);
    SignalData *pPassedData = reinterpret_cast< SignalData* >(pInfo->UserData);

    if (pInfo->Signal == osl_Signal_User)
    {
       switch (pInfo->UserSignal)
       {
           case OSL_SIGNAL_USER_TEST1:
               fprintf(stdout, "        Signal handler 1 called...\n");
               pSignalData->nData = pPassedData->nData;
               break;
       }
    }

    return osl_Signal_ActCallNextHdl;
}

oslSignalAction SignalHandlerFunc2(void* /* pData */, oslSignalInfo* pInfo)
{
    SignalData *pSignalData = reinterpret_cast< SignalData* >(pInfo->UserData);

    if (pInfo->Signal == osl_Signal_User)
    {
       switch (pInfo->UserSignal)
       {
           case OSL_SIGNAL_USER_TEST1:
               fprintf(stdout, "        Signal handler 2 called...\n");
               pSignalData->nData++;
               break;
       }
    }

    return osl_Signal_ActCallNextHdl;
}
```

## Memory-mapped files

Memory mapped files allow a file to be mapped into a process's virtual address space, and thus be manipulated and read as if reading memory. The benefits of such an approach are mainly that they allow large files to be processed more efficiently - instead of loading the entire file into memory, the file is loaded via the operating system's Virtual Memory Manager \(VMM\) - which means that the entire file does not need to be loaded into memory, but large portions of the file that are mapped to the virtual address space can be paged to disk. In terms of IPC, however, it also means that multiple processes can map independent portions of the file to a common region in the system's pagefile via the VMM, and thus share data between process boundaries.

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

An internal file mapping structure is used as an RAII object. RAII stands for "Resource acquisition is initialization", or in other words once you create the object \("acquire" the object via the constructor\) then the object is initialized, and similarly when the object is deleted it releases all its resources. In this case, the FileMapping struct assigns a handle in the constructor and when the FileMapping instance is finished with it closes the handle in the destructor.

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

The function passes the file handle to the function, which then casts it to a Windows-specific FileHandle\_Impl instance.

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

```cpp
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

This function takes as the first parameter a hint to the address of where to place the mapping in memory - if this is NULL then the operating system automatically works out where to allocate the memory, otherwise it places it at the nearest page boundary to the address. The function's second paramter takes the size of the file to be mapped, and the third parameter determines the desired memory protection for the mapping - basically it determines whether the mapping allows pages to be executed, read from or written to \(`PROT_EXEC`, `PROT_READ` and `PROT_WRITE`, consecutively. `PROT_NONE` specifies that the page cannot be accessed at all\). The function also determines via the fourth parameter if the mapping can be shared \(`MAP_SHARED`\), or if updates to the mapping are not exposed to other processes \(`MAP_PRIVATE`\). The file itself is specified by the `fd` parameter, with an offset into the file by the final parameter `offset`.

`mmap()` returns a pointer to the mapped area on success, and on failure it returns `MAP_FAILED` \(`(void *) -1`\) and sets `errno` to the error code.

To delete the file mappings, you call on the `munmap()` function:

```c
int munmap(void *addr, size_t length);
```

A region of memory is unmapped by the `addr` pointer - which must be a multiple of the page size - and the size of the area to unmap is specified by the `length` parameter. `munmap()` returns -1 and populates `errno` on failure, and 0 on success.

The OSL maps the file through the implementation of `osl_mapFile`. The function first checks the parameters to ensure that the handle, file descriptor, address and length are valid parameters:

```cpp
oslFileError SAL_CALL osl_mapFile (
    oslFileHandle Handle,
    void**        ppAddr,
    sal_uInt64    uLength,
    sal_uInt64    uOffset,
    sal_uInt32    uFlags
)
{
    FileHandle_Impl* pImpl = static_cast<FileHandle_Impl*>(Handle);

    if ((pImpl == nullptr) || ((pImpl->m_kind == FileHandle_Impl::KIND_FD) && (pImpl->m_fd == -1)) || (ppAddr == nullptr))
        return osl_File_E_INVAL;
    *ppAddr = nullptr;

    if (uLength > SAL_MAX_SIZE)
        return osl_File_E_OVERFLOW;
    size_t const nLength = sal::static_int_cast< size_t >(uLength);

    sal_uInt64 const limit_off_t = MAX_OFF_T;
    if (uOffset > limit_off_t)
        return osl_File_E_OVERFLOW;
```

Next, it takes the file handle, checks if the file is pure memory, and if so then it specifies the address of the mapping to be an offset from the file descriptor's currently buffer address and returns of the function \(e.g. if the file is part of a tmpfs, then it is in memory already and thus doesn't need to be mapped\).

```cpp
    if (pImpl->m_kind == FileHandle_Impl::KIND_MEM)
    {
        *ppAddr = pImpl->m_buffer + uOffset;
        return osl_File_E_None;
    }
```

If the file is not an in-memory file, then is then mmap'ed as a shared, read-only mapping.

```cpp
    off_t const nOffset = sal::static_int_cast< off_t >(uOffset);

    void* p = mmap(nullptr, nLength, PROT_READ, MAP_SHARED, pImpl->m_fd, nOffset);
    if (MAP_FAILED == p)
        return oslTranslateFileError(OSL_FET_ERROR, errno);
    *ppAddr = p;
```

As in the Windows file mapping code, the function checks if the file mapping will be access in a random access fashion. It then reads just the first byte of every page in the mapped region, which commits the entire page to memory. Note that for the same reason as in the Windows implementation, to stop the compiler from optimizing away the loop, they have had to set the `c` `sal_uInt8` variable to volatile.

```cpp
    if (uFlags & osl_File_MapFlag_RandomAccess)
    {
        // Determine memory pagesize.
        size_t const nPageSize = FileHandle_Impl::getpagesize();
        if (nPageSize != size_t(-1))
        {
            /*
             * Pagein, touching first byte of every memory page.
             * Note: volatile disables optimizing the loop away.
             */
            sal_uInt8 * pData (static_cast<sal_uInt8*>(*ppAddr));
            size_t      nSize (nLength);

            volatile sal_uInt8 c = 0;
            while (nSize > nPageSize)
            {
                c ^= pData[0];
                pData += nPageSize;
                nSize -= nPageSize;
            }
            if (nSize > 0)
            {
                c^= pData[0];
            }
        }
    }
```

A further consideration in Unix systems, however, is that the operating system can be given guidance as to how memory is intended to be used via the `madvise()` function. `MADV_WILLNEED` tells the operating system that it wants the data to be paged in as soon as possible. However, this function does _not_ necessarily work in an asynchronous way, and so on Linux, `madvise(..., MADV_WILLNEED)` has the undesirable effect of not returning until the data has actually been paged in so that its net effect would typically be to slow down the process \(which could start processing at the beginning of the data while the OS simultaneously pages in the rest\). Other platforms other than Linux can use this, and Solaris and Sun operating systems do work more adventageously so on these Unix flavours `madvise` is called.

```cpp
    if (uFlags & osl_File_MapFlag_WillNeed)
    {
#if defined MACOSX || (defined(__sun) && (!defined(__XOPEN_OR_POSIX) || defined(_XPG6) || defined(__EXTENSIONS__)))
        int e = posix_madvise(p, nLength, POSIX_MADV_WILLNEED);
        if (e != 0)
        {
            SAL_INFO("sal.file", "posix_madvise(..., POSIX_MADV_WILLNEED) failed with " << e);
        }
#elif defined __sun
        if (madvise(static_cast< caddr_t >(p), nLength, MADV_WILLNEED) != 0)
        {
            SAL_INFO("sal.file", "madvise(..., MADV_WILLNEED) failed with " << strerror(errno));
        }
#endif
    }
    return osl_File_E_None;
}
```

## Pipes

A pipe is a means of communicating between processes whereby the output on each process feeds directly into the input of the next process. It really is the simplest form of IPC available, and pretty much works the same way on Unix and Windows. LibreOffice implements named pipes on Unix via Unix domain sockets, which are almost no different to named pipes \(FIFOs\). On Windows, pipes are named pipes using a native operating system mechanism.

To use a pipe, you do the following:

1. Call on `osl_createPipe("pipename", osl_Pipe_CREATE, NULL)` \(or if the pipe has already been created, then call on `osl_createPipe("pipename", osl_Pipe_OPEN, NULL)`\)
2. You can either call on `osl_readPipe()` \(which is actually a thin wrapper over `osl_receivePipe()`\) to read data coming from the other side of the pipe; alternatively you call on `osl_writePipe()` \(which is actually also a thin wrapper over `osl_sendPipe()`\) to send data to other end of the pipe. 
3. When done, call on `osl_closePipe()`

### Unix implementation

On Unix the `osl_createPipe()` function is implemented as:

```cpp
oslPipe SAL_CALL osl_createPipe(rtl_uString *ustrPipeName, oslPipeOptions Options, oslSecurity Security)
{
    oslPipe pPipe = nullptr;
    rtl_String* strPipeName = nullptr;

    if (ustrPipeName)
    {
        rtl_uString2String(&strPipeName,
                           rtl_uString_getStr(ustrPipeName),
                           rtl_uString_getLength(ustrPipeName),
                           osl_getThreadTextEncoding(),
                           OUSTRING_TO_OSTRING_CVTFLAGS);
        sal_Char* pszPipeName = rtl_string_getStr(strPipeName);
        pPipe = osl_psz_createPipe(pszPipeName, Options, Security);

        if (strPipeName)
            rtl_string_release(strPipeName);
    }

    return pPipe;

}
```

Really, what we need to look at is `osl_psz_createPipe()`... it works as follows:

**Step 1:** first check to ensure that you have write access to the pipe's path.

```cpp
oslPipe SAL_CALL osl_psz_createPipe(const sal_Char *pszPipeName, oslPipeOptions Options,
                                    oslSecurity Security)
{
    int Flags;
    size_t len;
    struct sockaddr_un addr;

    sal_Char name[PATH_MAX+1];
    size_t nNameLength = 0;
    bool bNameTooLong = false;
    oslPipe pPipe;

    if (access(PIPEDEFAULTPATH, W_OK) == 0)
        strncpy(name, PIPEDEFAULTPATH, sizeof(name));
    else if (access(PIPEALTERNATEPATH, W_OK) == 0)
        strncpy(name, PIPEALTERNATEPATH, sizeof(name));
    else if (!cpyBootstrapSocketPath (name, sizeof (name)))
        return nullptr
```

**Step 2:** create the name of the file to be used for the pipe. In this case, the pipe name will be either `OSL_<username>_pipename` \(if a secured pipe\) or `OSL_pipename`.

```cpp
    name[sizeof(name)-1] = '\0';  // ensure the string is NULL-terminated
    nNameLength = strlen(name);
    bNameTooLong = nNameLength > sizeof(name) - 2;

    if (!bNameTooLong)
    {
        size_t nRealLength = 0;

        strcat(name, "/");
        ++nNameLength;

        if (Security)
        {
            sal_Char Ident[256];

            Ident[0] = '\0';

            OSL_VERIFY(osl_psz_getUserIdent(Security, Ident, sizeof(Ident)));

            nRealLength = snprintf(&name[nNameLength], sizeof(name) - nNameLength, SECPIPENAMEMASK, Ident, pszPipeName);
        }
        else
        {
            nRealLength = snprintf(&name[nNameLength], sizeof(name) - nNameLength, PIPENAMEMASK, pszPipeName);
        }

        bNameTooLong = nRealLength > sizeof(name) - nNameLength - 1;
    }

    if (bNameTooLong)
    {
        SAL_WARN("sal.osl.pipe", "osl_createPipe: pipe name too long");
        return nullptr;
    }
```

**Step 3:** the pipe needs to be initialized, which is what `createPipeImpl()` does.

```cpp
    /* alloc memory */
    pPipe = createPipeImpl();

    if (!pPipe)
        return nullptr;
```

**Step 4:** now a Unix Domain socket is created. To ensure there are no resource leaks, close-on-exec is set on the socket's file descriptor. This ensures that if the process runs any of the `exec` family of functions then the socket will be closed.

```cpp
    /* create socket */
    pPipe->m_Socket = socket(AF_UNIX, SOCK_STREAM, 0);
    if (pPipe->m_Socket < 0)
    {
        SAL_WARN("sal.osl.pipe", "socket() failed: " << strerror(errno));
        destroyPipeImpl(pPipe);
        return nullptr;
    }

    /* set close-on-exec flag */
    if ((Flags = fcntl(pPipe->m_Socket, F_GETFD, 0)) != -1)
    {
        Flags |= FD_CLOEXEC;
        if (fcntl(pPipe->m_Socket, F_SETFD, Flags) == -1)
        {
            SAL_WARN("sal.osl.pipe", "fcntl() failed: " << strerror(errno));
        }
    }
```

**Step 5:** Now we setup the "address" of the socket - for a Unix Domain socket, this is the path of the file.

```cpp
    memset(&addr, 0, sizeof(addr));

    SAL_INFO("sal.osl.pipe", "new pipe on fd " << pPipe->m_Socket << " '" << name << "'");

    addr.sun_family = AF_UNIX;
    strncpy(addr.sun_path, name, sizeof(addr.sun_path) - 1);
#if defined(FREEBSD)
    len = SUN_LEN(&addr);
#else
    len = sizeof(addr);
#endif
```

**Step 6 \(pipe creation\):** if the function is instructed to create the pipe \(`Options` is set to `osl_Pipe_CREATE`\) then first check for an already orphaned socket or FIFO pipe exists \(`stat(name, &status)` fills in the status information about the file, and the macros `S_ISSOCK()` and `S_ISFIFO()` check if the file is a socket or a FIO pipe, respectively\). If there is an orphaned file, then it connects to the socket, closes the socket and deletes \(unlinks\) the file.

The socket is then bound to the AF\_UNIX address \(the filename\), starts listening for connections to the socket, and returns the pipe.

```cpp
    if (Options & osl_Pipe_CREATE)
    {
        struct stat status;

        /* check if there exists an orphan filesystem entry */
        if ((stat(name, &status) == 0) &&
            (S_ISSOCK(status.st_mode) || S_ISFIFO(status.st_mode)))
        {
            if (connect(pPipe->m_Socket, reinterpret_cast< sockaddr* >(&addr), len) >= 0)
            {
                close (pPipe->m_Socket);
                destroyPipeImpl(pPipe);
                return nullptr;
            }

            unlink(name);
        }

        /* ok, fs clean */
        if (bind(pPipe->m_Socket, reinterpret_cast< sockaddr* >(&addr), len) < 0)
        {
            SAL_WARN("sal.osl.pipe", "bind() failed: " << strerror(errno));
            close(pPipe->m_Socket);
            destroyPipeImpl(pPipe);
            return nullptr;
        }

        /*  Only give access to all if no security handle was specified, otherwise security
            depends on umask */

        if (!Security)
            chmod(name,S_IRWXU | S_IRWXG |S_IRWXO);

        strncpy(pPipe->m_Name, name, sizeof(pPipe->m_Name) - 1);

        if (listen(pPipe->m_Socket, 5) < 0)
        {
            SAL_WARN("sal.osl.pipe", "listen() failed: " << strerror(errno));
            // coverity[toctou] cid#1255391 warns about unlink(name) after
            // stat(name, &status) above, but the intervening call to bind makes
            // those two clearly unrelated, as it would fail if name existed at
            // that point in time:
            unlink(name);   /* remove filesystem entry */
            close(pPipe->m_Socket);
            destroyPipeImpl(pPipe);
            return nullptr;
        }

        return pPipe;
    }
```

**Step 6 \(opening pipe\):** if the option is not to create the pipe, but to open it then it merely checks that it can access the file representing the socket, connects to this socket and returns the pipe.

```cpp
    /* osl_pipe_OPEN */
    if (access(name, F_OK) != -1)
    {
        if (connect(pPipe->m_Socket, reinterpret_cast< sockaddr* >(&addr), len) >= 0)
            return pPipe;

        SAL_WARN("sal.osl.pipe", "connect() failed: " << strerror(errno));
    }

    close (pPipe->m_Socket);
    destroyPipeImpl(pPipe);
    return nullptr;
}
```

To receive data, the function is:

```cpp
sal_Int32 SAL_CALL osl_receivePipe(oslPipe pPipe,
                        void* pBuffer,
                        sal_Int32 BytesToRead)
{
    int nRet = 0;

    OSL_ASSERT(pPipe);

    if (!pPipe)
    {
        SAL_WARN("sal.osl.pipe", "osl_receivePipe: Invalid socket");
        errno=EINVAL;
        return -1;
    }

    nRet = recv(pPipe->m_Socket, pBuffer, BytesToRead, 0);

    if (nRet < 0)
        SAL_WARN("sal.osl.pipe", "recv() failed: " << strerror(errno));

    return nRet;
}
```

To send data, the function is:

```cpp
sal_Int32 SAL_CALL osl_sendPipe(oslPipe pPipe,
                       const void* pBuffer,
                       sal_Int32 BytesToSend)
{
    int nRet=0;

    OSL_ASSERT(pPipe);

    if (!pPipe)
    {
        SAL_WARN("sal.osl.pipe", "osl_sendPipe: Invalid socket");
        errno=EINVAL;
        return -1;
    }

    nRet = send(pPipe->m_Socket, pBuffer, BytesToSend, 0);

    if (nRet <= 0)
        SAL_WARN("sal.osl.pipe", "send() failed: " << strerror(errno));

     return nRet;
}
```

### Windows implementation

On Windows, a pipe is created via `osl_createPipe()`. This is implemented via the following:

**Step 1:** first create the pipe name. This is formed from the path \(`PIPESYSTEM`\) and name \(`PIPEPREFIX`\). If `Security` is set, then get the user identity and prepend it as `_username_`, otherwise if the pipe is being created then a NULL discretionary access control list is set on the security descriptor. What this means is that anyone can access the object associated with the security descriptor \(don't confuse this with an _empty_ security descriptor, which denies everyone access\).

```cpp
oslPipe SAL_CALL osl_createPipe(rtl_uString *strPipeName, oslPipeOptions Options,
                       oslSecurity Security)
{
    rtl_uString* name = nullptr;
    rtl_uString* path = nullptr;
    rtl_uString* temp = nullptr;
    oslPipe pPipe;

    PSECURITY_ATTRIBUTES pSecAttr = nullptr;

    rtl_uString_newFromAscii(&path, PIPESYSTEM);
    rtl_uString_newFromAscii(&name, PIPEPREFIX);

    if (Security)
    {
        rtl_uString *Ident = nullptr;
        rtl_uString *Delim = nullptr;

        OSL_VERIFY(osl_getUserIdent(Security, &Ident));
        rtl_uString_newFromAscii(&Delim, "_");

        rtl_uString_newConcat(&temp, name, Ident);
        rtl_uString_newConcat(&name, temp, Delim);

        rtl_uString_release(Ident);
        rtl_uString_release(Delim);
    }
    else
    {
        if (Options & osl_Pipe_CREATE)
        {
            PSECURITY_DESCRIPTOR pSecDesc;

            pSecDesc = static_cast< PSECURITY_DESCRIPTOR >(rtl_allocateMemory(SECURITY_DESCRIPTOR_MIN_LENGTH));

            /* add a NULL disc. ACL to the security descriptor */
            OSL_VERIFY(InitializeSecurityDescriptor(pSecDesc, SECURITY_DESCRIPTOR_REVISION));
            OSL_VERIFY(SetSecurityDescriptorDacl(pSecDesc, TRUE, nullptr, FALSE));

            pSecAttr = static_cast< PSECURITY_ATTRIBUTES >(rtl_allocateMemory(sizeof(SECURITY_ATTRIBUTES)));
            pSecAttr->nLength = sizeof(SECURITY_ATTRIBUTES);
            pSecAttr->lpSecurityDescriptor = pSecDesc;
            pSecAttr->bInheritHandle = TRUE;
        }
    }

    rtl_uString_assign(&temp, name);
    rtl_uString_newConcat(&name, temp, strPipeName);
```

**Step 2:** the pipe needs to be initialized, which is what `createPipeImpl()` does.

```cpp
    /* alloc memory */
    pPipe = osl_createPipeImpl();
    osl_atomic_increment(&(pPipe->m_Reference));
```

**Step 3:** finish building the system pipe name

```cpp
    /* build system pipe name */
    rtl_uString_assign(&temp, path);
    rtl_uString_newConcat(&path, temp, name);
    rtl_uString_release(temp);
    temp = nullptr;
```

**Step 4:** create the pipe. The pipe must be protected with a mutex, and the pipe security descriptor and name is set, after which the pipe is created.

This is done via the `CreateNamedPipeW()` API function. This takes the pipe name, sets the mode of the pipe to full-duplex \(can be read and written to on both ends of the pipe\) and switches on overlapped mode \(functions performing read, write, and connect operations that may take a significant time to be completed can return immediately, and enables the thread that started the operation to perform other operations while the time-consuming operation executes in the background\) via the flag `PIPE_ACCESS_DUPLEX | FILE_FLAG_OVERLAPPED`. It further sets the mode of the pipe to blocking message mode `PIPE_WAIT | PIPE_TYPE_MESSAGE | PIPE_READMODE_MESSAGE`. For our purposes we set the number of instances to unlimited \(`PIPE_UNLIMITED_INSTANCES`\), and we wait indefinitely for the pipe operations to complete \(`NMPWAIT_WAIT_FOREVER`\).

Once created, we return the pipe.

```cpp
    if (Options & osl_Pipe_CREATE)
    {
        SetLastError(ERROR_SUCCESS);

        pPipe->m_NamedObject = CreateMutexW(nullptr, FALSE, SAL_W(name->buffer));

        if (pPipe->m_NamedObject)
        {
            if (GetLastError() != ERROR_ALREADY_EXISTS)
            {
                pPipe->m_Security = pSecAttr;
                rtl_uString_assign(&pPipe->m_Name, name);

                /* try to open system pipe */
                pPipe->m_File = CreateNamedPipeW(
                    SAL_W(path->buffer),
                    PIPE_ACCESS_DUPLEX | FILE_FLAG_OVERLAPPED,
                    PIPE_WAIT | PIPE_TYPE_MESSAGE | PIPE_READMODE_MESSAGE,
                    PIPE_UNLIMITED_INSTANCES,
                    4096, 4096,
                    NMPWAIT_WAIT_FOREVER,
                    pPipe->m_Security);

                if (pPipe->m_File != INVALID_HANDLE_VALUE)
                {
                    rtl_uString_release( name );
                    rtl_uString_release( path );

                    return pPipe;
                }
            }
            else
            {
                CloseHandle(pPipe->m_NamedObject);
                pPipe->m_NamedObject = nullptr;
            }
        }
    }
```

**Step 5:** if we want to open the pipe, then need to wait for an instance to be free \(`WaitNamedPipeW()`\), then we create the file backing the pipe via `CreateFileW()`. Once created, we return the pipe.

```cpp
    else
    {
        BOOL bPipeAvailable;

        do
        {
            /* free instance should be available first */
            bPipeAvailable = WaitNamedPipeW(SAL_W(path->buffer), NMPWAIT_WAIT_FOREVER);

            /* first try to open system pipe */
            if (bPipeAvailable)
            {
                pPipe->m_File = CreateFileW(
                    SAL_W(path->buffer),
                    GENERIC_READ|GENERIC_WRITE,
                    FILE_SHARE_READ | FILE_SHARE_WRITE,
                    nullptr,
                    OPEN_EXISTING,
                    FILE_ATTRIBUTE_NORMAL | FILE_FLAG_OVERLAPPED,
                    nullptr);

                if (pPipe->m_File != INVALID_HANDLE_VALUE)
                {
                    // We got it !
                    rtl_uString_release(name);
                    rtl_uString_release(path);

                    return pPipe;
                }
                else
                {
                    // Pipe instance maybe caught by another client -> try again
                }
            }
        } while (bPipeAvailable);
    }
```

**Step 6:** If the pipe could not be created \(this really shouldn't ever occur\) the we destroy the pipe and return a `nullptr`.

```cpp
    /* if we reach here something went wrong */
    osl_destroyPipeImpl(pPipe);

    return nullptr;
}
```

To receive data, the function is `osl_recievePipe()`. This reads from the pipe, and returns the number of bytes that were read.

```cpp
sal_Int32 SAL_CALL osl_receivePipe(oslPipe pPipe,
                        void* pBuffer,
                        sal_Int32 BytesToRead)
{
    DWORD nBytes;
    OVERLAPPED os;

    memset(&os, 0, sizeof(OVERLAPPED));
    os.hEvent = pPipe->m_ReadEvent;

    ResetEvent(pPipe->m_ReadEvent);

    if (!ReadFile(pPipe->m_File, pBuffer, BytesToRead, &nBytes, &os) &&
        ((GetLastError() != ERROR_IO_PENDING) ||
         !GetOverlappedResult(pPipe->m_File, &os, &nBytes, TRUE)))
    {
        DWORD lastError = GetLastError();

        if (lastError == ERROR_MORE_DATA)
        {
            nBytes = BytesToRead;
        }
        else
        {
            if (lastError == ERROR_PIPE_NOT_CONNECTED)
                nBytes = 0;
            else
                nBytes = (DWORD) -1;

            pPipe->m_Error = osl_Pipe_E_ConnectionAbort;
        }
    }

    return nBytes;
}
```

To receive data, the function is `osl_recievePipe()`. This reads from the pipe, and returns the number of bytes that were sent.

```cpp
sal_Int32 SAL_CALL osl_sendPipe(oslPipe pPipe,
                       const void* pBuffer,
                       sal_Int32 BytesToSend)
{
    DWORD nBytes;
    OVERLAPPED os;

    OSL_ASSERT(pPipe);

    memset(&os, 0, sizeof(OVERLAPPED));
    os.hEvent = pPipe->m_WriteEvent;
    ResetEvent(pPipe->m_WriteEvent);

    if (!WriteFile(pPipe->m_File, pBuffer, BytesToSend, &nBytes, &os) &&
        ((GetLastError() != ERROR_IO_PENDING) ||
          !GetOverlappedResult(pPipe->m_File, &os, &nBytes, TRUE)))
    {
        if (GetLastError() == ERROR_PIPE_NOT_CONNECTED)
            nBytes = 0;
        else
            nBytes = (DWORD) -1;

         pPipe->m_Error = osl_Pipe_E_ConnectionAbort;
    }

    return nBytes;
}
```

