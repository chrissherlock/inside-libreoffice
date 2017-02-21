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

On POSIX systems, a file descriptor is used to communicate between processes. Instead of just anonymous pipes for standard input, standard output and standard error, POSIX based systems allow two processes to connect through any file descriptor.

On Win32 systems, the [`STARTUPINFO`](https://msdn.microsoft.com/en-us/library/windows/desktop/ms686331%28v=vs.85%29.aspx) structure references Windows handles (the `HANDLE` macro) that point to standard input, standard output and standard error pipes. When a new process is created via the [`CreateProcess()`](https://msdn.microsoft.com/en-us/library/windows/desktop/ms682425%28v=vs.85%29.aspx) function, you setup the `STARTUPINFO` structure and use the [`CreatePipe()`](https://msdn.microsoft.com/en-us/library/windows/desktop/aa365152%28v=vs%2e85%29.aspx) function to create an anonymous pipe to [connect the read end of the pipe to the write end of the pipe](https://msdn.microsoft.com/en-us/library/windows/desktop/ms682499%28v=vs.85%29.aspx) - each process then associates the pipe to the `hStdInput`, `hStdOutput` and/or `hStdError` structure fields. However, as the `STARTUPINFO` structure on allows standard input, standard output and standard error you cannot setup extra channels like you can in POSIX. It is also important to note that named pipes must be used for asynchronous IO as anonymous pipes are unable to use asynchronous IO.

### Interprocess communication

Aside from anonymous pipes, processes on most operating systems can communicate with each other via shared memory and named pipes. However, POSIX compliant systems can also use Unix domain sockets. 

| IPC Method          | Description                                |
|---------------------|--------------------------------------------| 
| Shared Memory       | Shared memory works by allowing multiple processes access to a block of memory which is accessed by all the processes. A process will read and write to this memory to communicate between each process. As more than one process is accessing the same block of memory, synchonization primitives are necessary to mitigate race conditions and things such as dirty reads. |
| Named Pipes         | Allows processes to communicate via the filesystem, through a file that becomes a unidirectional data channel. On a Unix system, the named pipe remains till it is specifically removed, whereas on Windows systems when the last reference to the named pipe is closed the pipe is removed. |
| Unix Domain Sockets | Applies to POSIX compliant operating systems. Creates a socket, but uses filesystem inodes for addressing. These allow for bidirectional communication between more than two processes and supports passing file descriptors between processes. |

The OSL implements bi-directional "pipes", which are indeed named pipes on Windows; on Unix, however, it is implemented as a Unix Domain Socket so is not really a true Unix named pipe.
 
### Process termination

#### Windows process termination

Windows has a very different way of terminating processes to Unix systems. In Windows, a process terminates but does not terminate any child processes it has created. It deferences any kernel objects that it holds, but until all references are removed by all processes then that kernel object will not be destroyed. According to Microsoft, the following occurs:

> Terminating a process has the following results:
* Any remaining threads in the process are marked for termination.
* Any resources allocated by the process are freed.
* All kernel objects are closed.
* The process code is removed from memory.
* The process exit code is set.
* The process object is signaled.

> While open handles to kernel objects are closed automatically when a process terminates, the objects themselves exist until all open handles to them are closed. Therefore, an object will remain valid after a process that is using it terminates if another process has an open handle to it. 

\([Terminating a Process](https://msdn.microsoft.com/en-us/library/windows/desktop/ms686722%28v=vs.85%29.aspx "Terminating a Process"), MSDN article\) 

Processes on Windows will terminate under the following circumstances:

* When a thread calls on `ExitProcess()`
* When the last thread terminates
* Any thread calls on the `TerminateProcess()` with the handle of the process object
* When an end user logs of the system
* When the system is shutdown
* If a console process receives a CTRL+C or a CTRL+BREAK signal, the process calls on `ExitProcess()`

#### Unix/POSIX process termination

On Unix systems, however, it is a bit more complicated. A process will terminate when the process calls on `exit(n)` (or  `return n` in C and C++), and the value _n_ is passed to the process' parent process. However, the process will not fully remove the process from the kernel's process tables until the parent process collects the exit status, which is the exit code and the termination reason, which is normally contained in a 16-bit integer (the first byte containing the exit code, and the second byte containing a bit field with the termination reason). 

To collect a termination status from a child process, the parent process must call the `wait()` or `waitpid()` system call. The `wait()` system call waits for the child process to finish, and blocks the parent process until it gets the exit status of at least one of the child processes (which one exits first, it does not matter). The `waitpid()` system call, on the other hand, allows the PID to be specified as the first parameter, also also allows the system call to be non-blocking if the third option's parameter is set. 

> **Note:** if -1 is specified as the PID argument of `waitpid()`, then the process waits for the first child process to terminate, whilst a PID of 0 makes it wait for the first process in the process group to terminate. If the PID value is less than 0 then this indicates the process must wait for the first process of any whose process group ID is equal to the absolute value of PID) 

If a process' parent dies and the children processes remain alive, these processes will be reparented to process 1 (the init process). Any children processes that have terminated but have not yet been waited on are called _zombie_ processes until the parent process waits on it. If a zombie process' parent is killed, then it is reparented to PID 1 and this process periodically kills these processes via a mechanism called _process reaping_.

## OSL C API

The OSL uses a C API for managing the process lifecycle:

Process creation occurs by calling the osl_executeProcess()` function, which loads a program image into a new process. The function definition is:

```c
SAL_DLLPUBLIC oslProcessError SAL_CALL osl_executeProcess(
    rtl_uString* ustrImageName,
    rtl_uString* ustrArguments[],
    sal_uInt32  nArguments,
    oslProcessOption Options,
    oslSecurity Security,
    rtl_uString* ustrDirectory,
    rtl_uString* ustrEnvironments[],
    sal_uInt32 nEnvironmentVars,
    oslProcess* pProcess);
    
```

The parameters are:

* `ustrImageName` - the file URL of the executable to be started. This can be NULL, in which case the file URL of the executable must be the first element in `ustrArguments`.

* `ustrArguments` - an array of argument strings. Can be NULL if `strImageName` is not NULL. If, however, `strImageName` is NULL the function expects the first element of `ustrArguments` will contain the file URL of the executable to start.

* `nArguments` - the number of arguments provided. If this number is 0 strArguments will be ignored.

* `Options` - a combination of int-constants to describe the mode of execution.

* `Security` - the user and the user rights under which the process is started. This may be NULL, in which case the process will be started in the context of the current user.

* `ustrDirectory` - the file URL of the working directory of the new process. If the specified directory does not exist or is inaccessible the working directory of the newly created process is undefined. If this parameter is NULL or the caller provides an empty string the new process will have the same current working directory as the calling process.

* `ustrEnvironments` - an array of strings describing environment variables that should be merged into the environment of the new process. Each string has to be in the form "variable=value". This parameter can be NULL in which case the new process gets the same environment as the parent process.

* `nEnvironmentVars`the number of environment variables to set.

* `pProcess` - an output parameter, this variable is a pointer to an oslProcess variable, which receives the handle of the newly created process. This parameter must not be NULL.

On both Windows and Unix platforms, this is a wrapper to `osl_executeProcess_WithRedirectedIO()`. The function in Unix is as follows:

```cpp

oslProcessError SAL_CALL osl_executeProcess_WithRedirectedIO(
                                            rtl_uString *ustrImageName,
                                            rtl_uString *ustrArguments[],
                                            sal_uInt32   nArguments,
                                            oslProcessOption Options,
                                            oslSecurity Security,
                                            rtl_uString *ustrWorkDir,
                                            rtl_uString *ustrEnvironment[],
                                            sal_uInt32   nEnvironmentVars,
                                            oslProcess *pProcess,
                                            oslFileHandle   *pInputWrite,
                                            oslFileHandle   *pOutputRead,
                                            oslFileHandle   *pErrorRead
                                            )
{
    rtl::OUString image;
    if (ustrImageName == nullptr)
    {
        if (nArguments == 0)
        {
            return osl_Process_E_InvalidError;
        }
        image = rtl::OUString::unacquired(ustrArguments);
    }
    else
    {
        osl::FileBase::RC e = osl::FileBase::getSystemPathFromFileURL(
            rtl::OUString::unacquired(&ustrImageName), image);
        if (e != osl::FileBase::E_None)
        {
            SAL_INFO(
                "sal.osl",
                "getSystemPathFromFileURL("
                    << rtl::OUString::unacquired(&ustrImageName)
                    << ") failed with " << e);
            return osl_Process_E_Unknown;
        }
    }
```

The above gets the executable image name, checks that the directory exists if the first argument is NULL. 

```cpp

    if ((Options & osl_Process_SEARCHPATH) != 0)
    {
        rtl::OUString path;
        if (osl::detail::find_in_PATH(image, path))
        {
            image = path;
        }
    }
```

Searches for the image via the $PATH variable.

```cpp

    oslProcessError Error;
    sal_Char* pszWorkDir=nullptr;
    sal_Char** pArguments=nullptr;
    sal_Char** pEnvironment=nullptr;
    unsigned int idx;

    char szImagePath[PATH_MAX] = "";
    if (!image.isEmpty()
        && (UnicodeToText(
                szImagePath, SAL_N_ELEMENTS(szImagePath), image.getStr(),
                image.getLength())
            == 0))
    {
        int e = errno;
        SAL_INFO("sal.osl", "UnicodeToText(" << image << ") failed with " << e);
        return osl_Process_E_Unknown;
    }

    char szWorkDir[PATH_MAX] = "";
    if (ustrWorkDir != nullptr && ustrWorkDir->length)
    {
        oslFileError e = FileURLToPath(szWorkDir, PATH_MAX, ustrWorkDir);
        if (e != osl_File_E_None)
        {
            SAL_INFO(
                "sal.osl",
                "FileURLToPath(" << rtl::OUString::unacquired(&ustrWorkDir)
                    << ") failed with " << e);
            return osl_Process_E_Unknown;
        }
        pszWorkDir = szWorkDir;
    }
    ```

Gets the directory the executable resides in.
        
```cpp

    if ( pArguments == nullptr && nArguments > 0 )
    {
        pArguments = static_cast<sal_Char**>(malloc((nArguments + 2) * sizeof(sal_Char*)));
    }

    for ( idx = 0 ; idx < nArguments ; ++idx )
    {
        rtl_String* strArg =nullptr;

        rtl_uString2String(&strArg,
                           rtl_uString_getStr(ustrArguments[idx]),
                           rtl_uString_getLength(ustrArguments[idx]),
                           osl_getThreadTextEncoding(),
                           OUSTRING_TO_OSTRING_CVTFLAGS);

        pArguments[idx]=strdup(rtl_string_getStr(strArg));
        rtl_string_release(strArg);
        pArguments[idx+1]=nullptr;
    }
```

Processes the arguments. 
        
```cpp

    for ( idx = 0 ; idx < nEnvironmentVars ; ++idx )
    {
        rtl_String* strEnv=nullptr;

        if ( pEnvironment == nullptr )
        {
            pEnvironment = static_cast<sal_Char**>(malloc((nEnvironmentVars + 2) * sizeof(sal_Char*)));
        }

        rtl_uString2String( &strEnv,
                            rtl_uString_getStr(ustrEnvironment[idx]),
                            rtl_uString_getLength(ustrEnvironment[idx]),
                            osl_getThreadTextEncoding(),
                            OUSTRING_TO_OSTRING_CVTFLAGS);

        pEnvironment[idx]=strdup(rtl_string_getStr(strEnv));
        rtl_string_release(strEnv);
        pEnvironment[idx+1]=nullptr;
    }
```

Processes the environment variables. 
        
```cpp

    Error = osl_psz_executeProcess(szImagePath,
                                   pArguments,
                                   Options,
                                   Security,
                                   pszWorkDir,
                                   pEnvironment,
                                   pProcess,
                                   pInputWrite,
                                   pOutputRead,
                                   pErrorRead
                                   );
```

Load the image and execute it in a new process. 

```cpp
    if ( pArguments != nullptr )
    {
        for ( idx = 0 ; idx < nArguments ; ++idx )
        {
            if ( pArguments[idx] != nullptr )
            {
                free(pArguments[idx]);
            }
        }
        free(pArguments);
    }

    if ( pEnvironment != nullptr )
    {
        for ( idx = 0 ; idx < nEnvironmentVars ; ++idx )
        {
            if ( pEnvironment[idx] != nullptr )
            {
                free(pEnvironment[idx]);
            }
        }
        free(pEnvironment);
    }

    return Error;
}
```

Cleans up the process by freeing allocated memory structures.

It is also worthwhile looking at how Unix loads the image and executes it as a process:

```cpp
oslProcessError SAL_CALL osl_psz_executeProcess(sal_Char *pszImageName,
                                                sal_Char *pszArguments[],
                                                oslProcessOption Options,
                                                oslSecurity Security,
                                                sal_Char *pszDirectory,
                                                sal_Char *pszEnvironments[],
                                                oslProcess *pProcess,
                                                oslFileHandle   *pInputWrite,
                                                oslFileHandle   *pOutputRead,
                                                oslFileHandle   *pErrorRead
                                                )
{
    int i;
    ProcessData Data;
    oslThread hThread;

    memset(&Data,0,sizeof(ProcessData));
```

Zero-initializes the process data structure.

```cpp
    Data.m_pInputWrite = pInputWrite;
    Data.m_pOutputRead = pOutputRead;
    Data.m_pErrorRead = pErrorRead;
```

Initializes the process data structure's anonymous pipes.

```cpp
    OSL_ASSERT(pszImageName != nullptr);

    if ( pszImageName == nullptr )
    {
        return osl_Process_E_NotFound;
    }

    Data.m_pszArgs[0] = strdup(pszImageName);
    Data.m_pszArgs[1] = nullptr;

    if ( pszArguments != nullptr )
    {
        for (i = 0; ((i + 2) < MAX_ARGS) && (pszArguments[i] != nullptr); i++)
            Data.m_pszArgs[i+1] = strdup(pszArguments[i]);
        Data.m_pszArgs[i+2] = nullptr;
    }
    Data.m_options = Options;
    Data.m_pszDir  = (pszDirectory != nullptr) ? strdup(pszDirectory) : nullptr;
```

Sets up the process data structure's executable image name, arguments and working directory. 

```cpp
    if (pszEnvironments != nullptr)
    {
        for (i = 0; ((i + 1) < MAX_ENVS) &&  (pszEnvironments[i] != nullptr); i++)
            Data.m_pszEnv[i] = strdup(pszEnvironments[i]);
         Data.m_pszEnv[i+1] = nullptr;
    }
    else
    {
         Data.m_pszEnv[0] = nullptr;
    }
```

Sets up the environment variables. 

```cpp
    if (Security != nullptr)
    {
        Data.m_uid  = static_cast<oslSecurityImpl*>(Security)->m_pPasswd.pw_uid;
        Data.m_gid  = static_cast<oslSecurityImpl*>(Security)->m_pPasswd.pw_gid;
        Data.m_name = static_cast<oslSecurityImpl*>(Security)->m_pPasswd.pw_name;
    }
    else
    {
        Data.m_uid = (uid_t)-1;
    }
```

Sets up the security of the process - sets the Unix user ID (uid), group ID (gid) and the name of the process owner. 

```cpp

    Data.m_pProcImpl = static_cast<oslProcessImpl*>(malloc(sizeof(oslProcessImpl)));
    Data.m_pProcImpl->m_pid = 0;
    Data.m_pProcImpl->m_terminated = osl_createCondition();
    Data.m_pProcImpl->m_pnext = nullptr;
```

Initializes the process ID (PID) as 0, sets up a condition variable (for more details on this, see the threads chapter), and sets the next process in the linked list to NULL. 

```cpp
    if (ChildListMutex == nullptr)
        ChildListMutex = osl_createMutex();

    Data.m_started = osl_createCondition();

    hThread = osl_createThread(ChildStatusProc, &Data);

    if (hThread != nullptr)
    {
        osl_waitCondition(Data.m_started, nullptr);
    }
    osl_destroyCondition(Data.m_started);

    for (i = 0; Data.m_pszArgs[i] != nullptr; i++)
          free(const_cast<char *>(Data.m_pszArgs[i]));

    for (i = 0; Data.m_pszEnv[i] != nullptr; i++)
          free(Data.m_pszEnv[i]);

    if ( Data.m_pszDir != nullptr )
    {
        free(const_cast<char *>(Data.m_pszDir));
    }

    osl_destroyThread(hThread);

    if (Data.m_pProcImpl->m_pid != 0)
    {
         assert(hThread != nullptr);

        *pProcess = Data.m_pProcImpl;

         if (Options & osl_Process_WAIT)
            osl_joinProcess(*pProcess);

         return osl_Process_E_None;
    }

    osl_destroyCondition(Data.m_pProcImpl->m_terminated);
    free(Data.m_pProcImpl);

    return osl_Process_E_Unknown;
}
```