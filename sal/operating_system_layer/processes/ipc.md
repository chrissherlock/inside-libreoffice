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
        pHandler->pData   = pData;

        osl_acquireMutex(SignalListMutex);

        pHandler->pNext = SignalList;
        SignalList      = pHandler;

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

  

## Pipes

## Sockets
  