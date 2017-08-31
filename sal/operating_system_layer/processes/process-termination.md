# OSL process termination

## Unix

Under Unix a process terminates normally either when it gets to the end of the `main()` function, or if it calls on the `exit()` function call, which in turn calls on exit handlers that are registered via `atexit()` and then run the system call `_exit()`. `exit()` provides its exit code via its return variable. When `_exit()` runs the kernel closes all open file descriptors held by the process, reparents any children processes to the init process \(PID 1\) and then sends the signal `SIGCHILD` to all its children processes. The child processes become known as _orphan_ processes.

If a child process exits before its parent process, not all of its resources will be freed until the parent process waits on the child process. The parent does this by calling on the `wait()` and `waitpid()` functions; once it finishes waiting for the child process to exit, only then can all its resources can be freed fully. Any child process that has exited but has not been waited on by its parent is called a _zombie_ process. The only way to fully terminate a zombie is by making the parent wait on the termination status of the process, or alternatively the parent must be terminated in order to change the process from a zombie to an orphan, which then reparents the process with PID 1 - once this reparenting occurs init waits on the process which then allows it to be terminated \(or _reaped_\) properly.

The original Unix architects had a particularly ghoulish sense of humour when you think of it - if you kill a parent process then the children become orphans that are adopted by the initial parent process. If you kill a child process and the parent is not expecting it to die, the child becomes a zombie. If the parent then dies, this zombie becomes an orphan, is reparented to the init process, which then reaps the process to terminate it fully. It's interesting to note that signals are sent to processes via the `kill()` system call \(or the kill command\)...

The other way that a process can terminate is abnormally, via the `abort()` system call. `abort()` sends a `SIGABRT` signal to the process and must be processed - it cannot be blocked or ignored. There are other signals that can be sent to the process, these are:

* **SIGTERM** - signals program termination, and is what `kill` uses by default. This signal can be blocked, handled or ignored.

* **SIGQUIT** - the quit signal allows a program to terminate and produces a core dump for later examination. This signal can be blocked, handled or ignored.

* **SIGKILL** - tells the program to immediately terminate, and is considered a fatal error as it can't be ignored or blocked. This is the signal that the infamous `kill -9` command sends.

* **SIGHUP** - the "hang up" signal, so called because it informs the process that the user's controlling terminal has been disconnected. This signal is so called because in the days of mainframes, actual terminals were connected to the mainframe via a serial cable, but often a modem was used and the signal was sent if there was a line disconnection, or more frequently when the user hung up the modem.  This signal can be ignored, which is what the `nohup` program does. When all the a `SIGHUP` signal is sent to all jobs \(defined as "a set of processes, comprising a shell pipeline, and any processes descended from it, that are all in the same process group"\) by the _session leader_ process, and once all the process groups have ended the session leader process terminates itself.

### Unix termination function

The termination function is implemented in `osl_terminateProcess()` - it is quite simple in that it merely calls on the POSIX `kill()` function, and sends the `SIGKILL` signal to the process. If the signal is processed, then `osl_Process_E_None` is returned, if not then it checks what the error is and advises that the process cannot be found \(errno is `ESRCH`, returning `osl_Process_E_NotFound`\), permissions were denied to terminate the process \(`errno`is `EPERM`, returned `osl_Process_E_No_Permission`\), or the termination process failure reason is unknown \(returns `osl_ProcessE_Unknown`\).

> **Sidenote:** I am a bit opinionated on this one. I don't think we should call on `SIGKILL`, I think we should use `SIGTERM` so that we can handle the signal. We don't seem to have any code that needs this though, so it remains `SIGKILL`.

```cpp
oslProcessError SAL_CALL osl_terminateProcess(oslProcess Process)
{
    if (Process == nullptr)
        return osl_Process_E_Unknown;

    if (kill(static_cast<oslProcessImpl*>(Process)->m_pid, SIGKILL) != 0)
    {
        switch (errno)
        {
            case EPERM:
                return osl_Process_E_NoPermission;

            case ESRCH:
                return osl_Process_E_NotFound;

            default:
                return osl_Process_E_Unknown;
        }
    }

    return osl_Process_E_None;
}
```

## Windows

On Windows a process is terminated after either `TerminateProcess()` or `ExitProcess()` is called, or the final thread is terminated. If ExitProcess\(\) is called, then each attached dll has its entrypoint called \(`DLLPROCESSDETACH`\) indicating that the process is detaching from the dll. This does not occur when `TerminateProcess()` is called. Unlike Unix, however, a child process does not need to be reparented, and does not make the parent process wait.

### Windows termination function

The Windows termination function is somewhat more involved than the Unix version. Like in Unix version, the termination function is implemented in `osl_terminate_Process()`_ , \_however we want to avoid the use of _`TerminateProcess()`_ so that we can ensure an orderly process shutdown._ \_

**Step 1:** validate process identity is correct

```cpp
oslProcessError SAL_CALL osl_terminateProcess(oslProcess Process)
{
    if (Process == nullptr)
        return osl_Process_E_Unknown;

    HANDLE hProcess = static_cast<oslProcessImpl*>(Process)->m_hProcess;
    DWORD dwPID = GetProcessId(hProcess);

    // cannot be System Process (0x00000000)
    if (dwPID == 0x0)
        return osl_Process_E_InvalidError;
```

**Step 2:** ensure that we can access the other process to terminate it - we need to have the ability to create a new thread, have the ability to query the access token of the process, have the ability to operate in the process' virtual address space and read and write within it.

```cpp
    HANDLE hDupProcess = nullptr;

    DWORD dwAccessFlags = (PROCESS_CREATE_THREAD | PROCESS_QUERY_INFORMATION | PROCESS_VM_OPERATION
                                    | PROCESS_VM_WRITE | PROCESS_VM_READ);

    BOOL bHaveDuplHdl = DuplicateHandle(GetCurrentProcess(),    // handle to process that has handle
                                    hProcess,                   // handle to be duplicated
                                    GetCurrentProcess(),        // process that will get the dup handle
                                    &hDupProcess,               // store duplicate process handle here
                                    dwAccessFlags,              // desired access
                                    FALSE,                      // handle can't be inherited
                                    0);                         // zero means no additional action needed

    if (bHaveDuplHdl)
        hProcess = hDupProcess;     // so we were able to duplicate the handle, all good...
    else
        SAL_WARN("sal.osl", "Could not duplicate process handle, let's hope for the best...");
```

**Step 3:** if the process is running, then create a new thread in this process and call on `ExitProcess()` in this thread.

```cpp
    DWORD dwProcessStatus = 0;
    HANDLE hRemoteThread = nullptr;

    if (GetExitCodeProcess(hProcess, &dwProcessStatus) && (dwProcessStatus == STILL_ACTIVE))
    {

        DWORD dwTID = 0;    // dummy variable as we don't need to track the thread ID
        UINT uExitCode = 0; // dummy variable... ExitProcess has no return value

        HINSTANCE hKernel = GetModuleHandleA("kernel32.dll");
        FARPROC pfnExitProc = GetProcAddress(hKernel, "ExitProcess");
        hRemoteThread = CreateRemoteThread(
                            hProcess,           /* process handle */
                            nullptr,            /* default security descriptor */
                            0,                  /* initial size of stack in bytes is default
                                                   size for executable */
                            reinterpret_cast<LPTHREAD_START_ROUTINE>(pfnExitProc), /* Win32 ExitProcess() */
                            reinterpret_cast<PVOID>(uExitCode),   /* ExitProcess() dummy return... */
                            0,                  /* value of 0 tells thread to run immediately
                                                   after creation */
                            &dwTID);            /* new remote thread's identifier */

    }
```

**Step 4:** Wait for the process to terminate, then close the termination thread handle so that the process can fully exit and then the duplicated process handle \(if this was created successfully\). If the termination thread finished successfully, then we know that the process terminated. If, however, there was no termination thread, then the function must fall back to terminate the process `TerminateProcess()`, which is less than ideal but much better than nothing at all.

```cpp
    bool bHasExited = false;

    if (hRemoteThread)
    {
        WaitForSingleObject(hProcess, INFINITE); // wait for process to terminate, never stop waiting...
        CloseHandle(hRemoteThread);              // close the thread handle to allow the process to exit
        bHasExited = true;
    }

    // need to close this duplicated process handle...
    if (bHaveDuplHdl)
        CloseHandle(hProcess);

    if (bHasExited)
        return osl_Process_E_None;

    // fallback - given that we we wait for an infinite time on WaitForSingleObject, this should
    // never occur... unless CreateRemoteThread failed
    SAL_WARN("sal.osl", "TerminateProcess(hProcess, 0) called - we should never get here!");
    return (TerminateProcess(hProcess, 0) == FALSE) ? osl_Process_E_Unknown : osl_Process_E_None;
}
```

### Example

The following example can be found on [my private branch](https://cgit.freedesktop.org/libreoffice/core/log/?h=private/tbsdy/workbench) in the LO git repository:

[.../sal/workben/osl/process/terminateprocess.cxx](https://cgit.freedesktop.org/libreoffice/core/tree/sal/workben/osl/process/terminateprocess.cxx?h=private/tbsdy/workbench)

```cpp
#include <sal/config.h>
#include <sal/main.h>
#include <sal/log.hxx>
#include <rtl/ustring.hxx>
#include <rtl/alloc.h>
#include <osl/thread.h>
#include <osl/file.h>

#include <osl/process.h>

#include <cstdio>

SAL_IMPLEMENT_MAIN()
{
    oslProcess aProcess;

    fprintf(stdout, "Execute process.\n");

    rtl_uString *pustrExePath = nullptr;
    osl_getExecutableFile(&pustrExePath);

    rtl_uString *pTempExePath = nullptr;
    sal_uInt32 nLastChar;

    nLastChar = rtl_ustr_lastIndexOfChar(rtl_uString_getStr(pustrExePath), SAL_PATHDELIMITER);
    rtl_uString_newReplaceStrAt(&pTempExePath, pustrExePath, nLastChar, rtl_ustr_getLength(rtl_uString_getStr(pustrExePath)), nullptr);
    rtl_freeMemory(pustrExePath);
    pustrExePath = pTempExePath;

#if defined(_WIN32)
#  define BATCHFILE "\\..\\sal\\workben\\osl\\batchwait.bat"
#  define BATCHFILE_LENGTH 39
#else
#  define BATCHFILE "/../../../sal/workben/osl/batchwait.sh"
#  define BATCHFILE_LENGTH 38
#endif

    rtl_uString_newConcatAsciiL(&pustrExePath, pustrExePath, BATCHFILE, BATCHFILE_LENGTH);

    oslProcessError osl_error = osl_executeProcess(
        pustrExePath,           // process to execute
        nullptr,                // no arguments
        0,                      // no arguments
        osl_Process_NORMAL,     // process execution mode
        nullptr,                // security context is current user
        nullptr,                // current working directory inherited from parent process
        nullptr,                // no environment variables
        0,                      // no environment variables
        &aProcess);              // process handle

    rtl_freeMemory(pustrExePath);

    if (osl_error != osl_Process_E_None)
        fprintf(stderr, "Process failed\n");

    fprintf(stdout, "    Process running...\n");
    osl_error = osl_terminateProcess(aProcess);
    if (osl_error == osl_Process_E_None)
    {
        fprintf(stdout, "    ...process terminated.\n");
    }
    else
    {
        fprintf(stderr, "    ... process could not be terminated.\n");
        osl_joinProcess(aProcess);
    }

    osl_freeProcessHandle(aProcess);

    return 0;
}
```





