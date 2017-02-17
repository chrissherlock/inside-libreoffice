# Processes

When running a computer program, every operating system uses the concept of a [_process_](https://en.wikipedia.org/wiki/Process_(computing)). An operating system process encapsulates the program code and any state that it must maintain to successfully perform the task the programmer wishes to accomplish. Each process runs one or more [_threads of execution_](https://en.wikipedia.org/wiki/Thread_(computing)), which is a sequence of instructions run by a process and managed by a [scheduler](https://en.wikipedia.org/wiki/Scheduling_(computing)), which can either run multiple threads simultaneously, or switch between them as needed. 

Whilst all operating systems supported by LibreOffice use processes to execute code, there are really only two process models that LibreOffice implements in the OSL - the Windows process model, and the Unix process model. Whilst many process concepts are the same between these two operating systems, there are some significant differences that the OSL attempts to unify in a common abstraction. 

## Common functionality

Both Unix and Windows load a process from a stored image, which contains the program instructions associated with the program. [Common features](https://en.wikipedia.org/wiki/Process_(computing)#Representation) of processes under both operating systems are:

* memory handling via:
  * [virtual memory](https://en.wikipedia.org/wiki/Virtual_memory) which maps virtual addresses in a process to physical addresses in memory. 
  * mechanisms for gathering input and output between processes
  * a set of stack frames in the [_call stack_](https://en.wikipedia.org/wiki/Call_stack). Each stack frame holds:
    * a function's local variables
    * a frame pointer that holds the address of the calling function so that it can be returned control once the current function returns
    * the parameters passed to the function by the calling function
  * the _heap_ \(or sometimes called the _free store_\) which allows programs to dynamically allocate blocks of unused memory from a large pool of memory
* resource descriptors are allocated to a process by the operating system, for such things as files, synchronization primitives and shared memory - in Windows these are called [handles](https://blogs.technet.microsoft.com/markrussinovich/2009/09/29/pushing-the-limits-of-windows-handles/) and in Unix they are [file descriptors](https://en.wikipedia.org/wiki/File_descriptor)
* security attributes, such as the process owner and the set of allowable operations the process has permission to run



