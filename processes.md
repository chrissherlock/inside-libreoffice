# Processes

When running a computer program, every operating system uses the concept of a [_process_](https://en.wikipedia.org/wiki/Process_(computing)\). An operating system process encapsulates the program code and any state that it must maintain to successfully perform the task the programmer wishes to accomplish. Each process runs one or more [_threads of execution_](https://en.wikipedia.org/wiki/Thread_(computing)\), which is a sequence of instructions run by a process and managed by a [scheduler](https://en.wikipedia.org/wiki/Scheduling_(computing)\), which can either run multiple threads simultaneously, or switch between them as needed.

Whilst all operating systems supported by LibreOffice use processes to execute code, there are really only two process models that LibreOffice implements in the OSL - the Windows process model, and the Unix POSIX process model. Whilst many process concepts are the same between these two operating systems, there are some significant differences that the OSL attempts to unify in a common abstraction.

## Common functionality

Both Unix and Windows load a process from a stored image, which contains the program instructions associated with the program. [Common features](https://en.wikipedia.org/wiki/Process_%28computing%29#Representation) of processes under both operating systems are:

* memory handling via:
  * [virtual memory](https://en.wikipedia.org/wiki/Virtual_memory) which maps virtual addresses in a process to physical addresses in memory. 
  * mechanisms for gathering input and output between processes
  * a set of stack frames in the [_call stack_](https://en.wikipedia.org/wiki/Call_stack). Each stack frame holds:
    * a function's local variables
    * a frame pointer that holds the address of the calling function so that it can be returned control once the current function returns
    * the parameters passed to the function by the calling function
  * the _heap_ \(or sometimes called the _free store_\) which allows programs to dynamically allocate blocks of unused memory from a large pool of memory
* resource descriptors are allocated to a process by the operating system, for such things as files, synchronization primitives and shared memory - in Windows these are called [handles](https://blogs.technet.microsoft.com/markrussinovich/2009/09/29/pushing-the-limits-of-windows-handles/) and in Unix they are [file descriptors](https://en.wikipedia.org/wiki/File_descriptor)
* the ability to hold processor state, also known as the process' [_context_](https://en.wikipedia.org/wiki/Context_(computing))
* security attributes, such as the process owner and the set of allowable operations the process has permission to run
* the ability to spawn child processes
* the ability to manage one or more threads within the process
* [_environment variables_](https://en.wikipedia.org/wiki/Environment_variable), which are inherited from their parent processes

A process can exist within a number of states, the main ones being:

* The initial state is the _created_ state, where the program has been loaded into main memory but has not been processed by the operating system scheduler
* From the created state, the process switches to a _waiting_ state, where it waits for the scheduler to make it run via what is known as a [_context switch_](https://en.wikipedia.org/wiki/Context_switch)
* Once the scheduler does a context switch successfully the process will start executing, which is a state more commonly known as _running_
* Another valid state is for a process to be waiting on another process to finish it's exclusive control of a resource that it needs. When a process is prevent from running in these circumstances, the processes is said to be _blocked_. 
<span style="align: center">
![Process states](/assets/900px-Process_states.svg.png)<br>**Figure: Process States** <br>Source: [Wikipedia](https://en.wikipedia.org/wiki/Process_%28computing%29#/media/File:Process_states.svg), License: Public Domain</span>

## Differences between Win32 and POSIX process models

The areas of difference between Win32 and POSIX process models are process pipes, interprocess communication, process termination and a different security model.

### Process pipes

On POSIX systems, a file descriptor is used to communicate between processes. Instead of just anonymous pipes for standard input, standard output and standard error, POSIX based systems allow the connect two processes through any file descriptor.

On Win32 systems, the [`STARTUPINFO`](https://msdn.microsoft.com/en-us/library/windows/desktop/ms686331%28v=vs.85%29.aspx) structure references Windows handles (the `HANDLE` macro) that point to standard input, standard output and standard error pipes. When a new process is created via the [`CreateProcess()`](https://msdn.microsoft.com/en-us/library/windows/desktop/ms682425%28v=vs.85%29.aspx) function, you setup the `STARTUPINFO` structure and use the [`CreatePipe()`](https://msdn.microsoft.com/en-us/library/windows/desktop/aa365152%28v=vs%2e85%29.aspx) function to create an anonymous pipe to connect the read end of the pipe to the write end of the pipe - each process then associates the pipe to the `hStdInput`, `hStdOutput` and/or `hStdError` structure fields. However, as the `STARTUPINFO` structure on allows standard input, standard output and standard error you cannot setup extra channels like you can in POSIX. It is also important to note that named pipes must be used for asynchronous IO as anonymous pipes are unable to use asynchronous IO.

### Interprocess communication
### Process termination



