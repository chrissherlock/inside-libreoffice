# Inter-Process Communication (IPC)

Most modern operating systems have designed processes such that they are protected from other operating system processes, a concept called _process isolation_. This is done for stability and security reasons, however it may be necessary for one process to communicate with another process, and a variety of mechanisms have been developed to allow for this. The concept of processes communicating with each other is referred to as _Inter-Process Communication_, or more commonly abbreviated to _IPC_.

Most operating systems implement IPC, albeit with subtle differences, via signals, sockets, message queues, pipes (named and anonymous), shared memory and memory-mapped files. As a cross-platform product, LibreOffice attempts to unify each operating system's IPC functionality via the OSL API. 

## Signals

A signal sends an asynchronous notification to a process to notify it that an event has occurred. Under Unix and Unix-like systems a process registers a signal handler to process the signal via the `signal()` or `sigaction()` system call. Usage of `signal()` is not encouraged, instead it is recommended that `sigaction()` be used. If a signal is not register, the default handler processes the signal. Processes can handle signals without creating a specific signal handler by either ignoring the signal (`SIG_IGN`) or by passing it to the default signal handler (`SIG_DFL`). The only signals that cannot be intercepted and handled are `SIGKILL` and `SIGSTOP`. Signals can be blocked via `sigprocmask()`, which means that these signals are not delivered to the process until they are unblocked.

The OSL uses Windows structured exception handling as a means to emulate signals. Exceptions in Windows are much the same as signals are in Unix - and can be initiated by hardware or software. In Windows, however, exceptions can be classified as _continuable_ or _noncontinuable_ where it makes sense - a noncontinuable exception will terminate the application. Windows also allows for nested exceptions, which are exceptions held in a linked-list.

The OSL uses frame-based exception handling. Each process has what is known as a call stack, which consists of (as the name suggests) a _stack_ of _frames_. A _frame_ is a set of data that is pushed onto the stack, the data being varied but always consists of a return address. When a subroutine is called, it _pushes_ a frame onto the stack - the frame holding the return address of the routine that pushed the frame. When the new subroutine finishes, it _pops_ its frame from the stack and returns execution to the return address of the calling routine. In Windows, each stack frame stores an exception handler. When an exception is thrown, Windows examines each stack frame until it finds a suitable exception handler. If no exception handler can be found, then it looks for a top level exception handler, which is registered via `SetUnhandledExceptionFilter()` - this can be considered the equivalent of a default signal handler in Unix. 

## Memory-mapped files

## Pipes

## Sockets
  