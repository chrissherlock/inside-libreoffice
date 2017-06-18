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

The wrinkle, as seems to often be the case, is Java. The issue is that Java intercepts SIGSEGV, but then so does LibreOffice as it also processes SIGSEGV for a "crashguard". So as part of an incredible hack, OSL checks the process name to see if it starts with "soffice", and if it does then it special-cases this process by setting the SEGV, WINCH and ILL handlers to process as normal, and Java can then override these when it starts up. 

Interestingly, before the year 2000 it appears there was a Tomcat server in use called `stomcatd` - the code [originally looked for either `stomcatd` or `soffice`](https://cgit.freedesktop.org/libreoffice/core/plain/sal/osl/unx/signal.c?id=9399c662f36c385b0c705eb34e636a9aec450282) which was a "Portal Demo HACK", but this was [later removed](https://cgit.freedesktop.org/libreoffice/core/commit/sal/osl/unx/signal.c?id=0a1cc7826beade023be930ac966a465c11819d55) as it was entirely unclear what this was all about. 

So... we are left with the following:

```cpp
bool onInitSignal()
{
    if (is_soffice_Impl())
    {
        bSetSEGVHandler = true;
        bSetWINCHHandler = true;
        bSetILLHandler = true;
    }

#ifdef DBG_UTIL
    bSetSEGVHandler = bSetWINCHHandler = bSetILLHandler = false;
#endif

    struct sigaction act;
    act.sa_sigaction = signalHandlerFunction;
    act.sa_flags = SA_RESTART | SA_SIGINFO;

    sigfillset(&(act.sa_mask));

    /* Initialize the rest of the signals */
    for (SignalAction & rSignal : Signals)
    {
#if defined HAVE_VALGRIND_HEADERS
        if (rSignal.Signal == SIGUSR2 && RUNNING_ON_VALGRIND)
            rSignal.Action = ACT_IGNORE;
#endif

        /* hack: stomcatd is attaching JavaVM which does not work with an sigaction(SEGV) */
        if ((bSetSEGVHandler || rSignal.Signal != SIGSEGV)
        && (bSetWINCHHandler || rSignal.Signal != SIGWINCH)
        && (bSetILLHandler   || rSignal.Signal != SIGILL))
        {
```

It sort of appears that in fact none of this is necessary now...

```cpp
            if (rSignal.Action != ACT_SYSTEM)
            {
                if (rSignal.Action == ACT_HIDE)
                {
                    struct sigaction ign;

                    ign.sa_handler = SIG_IGN;
                    ign.sa_flags   = 0;
                    sigemptyset(&ign.sa_mask);

                    struct sigaction oact;
                    if (sigaction(rSignal.Signal, &ign, &oact) == 0) {
                        rSignal.siginfo = (oact.sa_flags & SA_SIGINFO) != 0;
                        if (rSignal.siginfo) {
                            rSignal.Handler = reinterpret_cast<Handler1>(
                                oact.sa_sigaction);
                        } else {
                            rSignal.Handler = oact.sa_handler;
                        }
                    } else {
                        rSignal.Handler = SIG_DFL;
                        rSignal.siginfo = false;
                    }
                }
                else
                {
                    struct sigaction oact;
                    if (sigaction(rSignal.Signal, &act, &oact) == 0) {
                        rSignal.siginfo = (oact.sa_flags & SA_SIGINFO) != 0;
                        if (rSignal.siginfo) {
                            rSignal.Handler = reinterpret_cast<Handler1>(
                                oact.sa_sigaction);
                        } else {
                            rSignal.Handler = oact.sa_handler;
                        }
                    } else {
                        rSignal.Handler = SIG_DFL;
                        rSignal.siginfo = false;
                    }
                }
            }
```

... and it appears that the above could probably be refactored also.

```cpp
        }
    }

    /* Clear signal mask inherited from parent process (on Mac OS X, upon a
       crash soffice re-execs itself from within the signal handler, so the
       second soffice would have the guilty signal blocked and would freeze upon
       encountering a similar crash again): */
    sigset_t unset;
    if (sigemptyset(&unset) < 0 ||
        pthread_sigmask(SIG_SETMASK, &unset, nullptr) < 0)
    {
        SAL_WARN("sal.osl", "sigemptyset or pthread_sigmask failed");
    }

    return true;
}
```

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

## Memory-mapped files

## Pipes

## Sockets
  