# OSL process creation and execution

Process creation occurs by calling the `osl_executeProcess(...)` function, which loads a program image into a new process. The function definition is:

```cpp
SAL_DLLPUBLIC oslProcessError SAL_CALL osl_executeProcess(
    rtl_uString* ustrImageName,
    rtl_uString* ustrArguments[],
    sal_uInt32 nArguments,
    oslProcessOption Options,
    oslSecurity Security,
    rtl_uString* ustrDirectory,
    rtl_uString* ustrEnvironments[],
    sal_uInt32 nEnvironmentVars,
    oslProcess* pProcess
);
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

On both Windows and Unix platforms, this is a wrapper to `osl_executeProcess_WithRedirectedIO()`.

## Unix platform implementation details

`osl_executeProcess(...)` calls on `osl_executeProcess_WithRedirectedIO(...)`, which on Unix platforms works as follows:

**Step 1:** gets the executable image name, checks that the directory exists if the first argument is NULL.

```cpp
oslProcessError SAL_CALL osl_executeProcess_WithRedirectedIO(
        rtl_uString *ustrImageName,
        rtl_uString *ustrArguments[],
        sal_uInt32 nArguments,
        oslProcessOption Options,
        oslSecurity Security,
        rtl_uString *ustrWorkDir,
        rtl_uString *ustrEnvironment[],
        sal_uInt32 nEnvironmentVars,
        oslProcess *pProcess,
        oslFileHandle *pInputWrite,
        oslFileHandle *pOutputRead,
        oslFileHandle *pErrorRead
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
**Step 2:** search for the image via the `$PATH` variable.


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

**Step 3:** get the directory the executable resides in.

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

**Step 4:** process the arguments.
```cpp
    if (pArguments == nullptr && nArguments > 0)
    {
        pArguments = static_cast<sal_Char**>(malloc((nArguments + 2) * sizeof(sal_Char*)));
    }
        
    for (idx = 0 ; idx < nArguments ; ++idx)
    {
        rtl_String* strArg = nullptr;
        
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

**Step 5:** process the environment variables.
```cpp
    for (idx = 0 ; idx < nEnvironmentVars ; ++idx)
    {
        rtl_String* strEnv=nullptr;
        
        if (pEnvironment == nullptr)
        {
            pEnvironment = static_cast<sal_Char**>(malloc((nEnvironmentVars + 2) * sizeof(sal_Char*)));
        }
        
        rtl_uString2String(&strEnv,
                            rtl_uString_getStr(ustrEnvironment[idx]),
                            rtl_uString_getLength(ustrEnvironment[idx]),
                            osl_getThreadTextEncoding(),
                            OUSTRING_TO_OSTRING_CVTFLAGS);
        
        pEnvironment[idx]=strdup(rtl_string_getStr(strEnv));
        rtl_string_release(strEnv);
        pEnvironment[idx+1]=nullptr;
    }
```

**Step 6:** Load the image and execute it in a new process.

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

**Step 7:** clean up the process by freeing allocated memory structures.


```cpp
    if (pArguments != nullptr)
    {
        for (idx = 0 ; idx < nArguments ; ++idx)
        {
            if (pArguments[idx] != nullptr)
            {
                free(pArguments[idx]);
            }
        }
        free(pArguments);
    }
    
    if (pEnvironment != nullptr)
    {
        for (idx = 0 ; idx < nEnvironmentVars ; ++idx)
        {
            if (pEnvironment[idx] != nullptr)
            {
                free(pEnvironment[idx]);
            }
        }
        
        free(pEnvironment);
    }
    
    return Error;
}
```

## Loading and execution the image

The process is actually loaded and executed in step 6 above, with a call to `osl_psz_executeProcess(...)`, which works as follows:

**Step 1:** Zero-initialize the process data structure.

```cpp
oslProcessError SAL_CALL osl_psz_executeProcess(sal_Char *pszImageName,
                                                sal_Char *pszArguments[],
                                                oslProcessOption Options,
                                                oslSecurity Security,
                                                sal_Char *pszDirectory,
                                                sal_Char *pszEnvironments[],
                                                oslProcess *pProcess,
                                                oslFileHandle *pInputWrite,
                                                oslFileHandle *pOutputRead,
                                                oslFileHandle *pErrorRead
                                                )
{
    int i;
    ProcessData Data;
    oslThread hThread;
    
    memset(&Data,0,sizeof(ProcessData));
```

**Step 2:** initialize the process' data structure's anonymous pipes.


```cpp
    Data.m_pInputWrite = pInputWrite;
    Data.m_pOutputRead = pOutputRead;
    Data.m_pErrorRead = pErrorRead;
```

**Step 3:** setup the process data structure's executable image name, arguments and working directory.

```cpp
    OSL_ASSERT(pszImageName != nullptr);
    
    if (pszImageName == nullptr)
    {
        return osl_Process_E_NotFound;
    }
    
    Data.m_pszArgs[0] = strdup(pszImageName);
    Data.m_pszArgs[1] = nullptr;
    
    if (pszArguments != nullptr)
    {
        for (i = 0; ((i + 2) < MAX_ARGS) && (pszArguments[i] != nullptr); i++)
            Data.m_pszArgs[i+1] = strdup(pszArguments[i]);
            
        Data.m_pszArgs[i+2] = nullptr;
    }
    
    Data.m_options = Options;
    Data.m_pszDir = (pszDirectory != nullptr) ? strdup(pszDirectory) : nullptr;
```

**Step 4:** setup the environment variables.

```cpp
    if (pszEnvironments != nullptr)
    {
        for (i = 0; ((i + 1) < MAX_ENVS) && (pszEnvironments[i] != nullptr); i++)
            Data.m_pszEnv[i] = strdup(pszEnvironments[i]);
            
        Data.m_pszEnv[i+1] = nullptr;
    }
    else
    {
        Data.m_pszEnv[0] = nullptr;
    }
```

**Step 5:** sets up the security of the process - sets the Unix user ID (uid), group ID (gid) and the name of the process owner.

```cpp
    if (Security != nullptr)
    {
        Data.m_uid = static_cast<oslSecurityImpl*>(Security)->m_pPasswd.pw_uid;
        Data.m_gid = static_cast<oslSecurityImpl*>(Security)->m_pPasswd.pw_gid;
        Data.m_name = static_cast<oslSecurityImpl*>(Security)->m_pPasswd.pw_name;
    }
    else
    {
        Data.m_uid = (uid_t)-1;
    }
```
**Step 6:** initializes the process ID \(PID\) as 0, sets up a condition variable (for more details on this, see the threads chapter), and sets the next process in the linked list to NULL.

```cpp
    Data.m_pProcImpl = static_cast<oslProcessImpl*>(malloc(sizeof(oslProcessImpl)));
    Data.m_pProcImpl->m_pid = 0;
    Data.m_pProcImpl->m_terminated = osl_createCondition();
    Data.m_pProcImpl->m_pnext = nullptr;
```

Initializes the process ID (PID) as 0, sets up a condition variable (for more details on this, see the threads chapter), and sets the next process in the linked list to NULL.

Note the line:

```cpp
    Data.m_pProcImpl->m_terminated = osl_createCondition();
```

This sets up a condition variable that is set if the thread is unexpected terminated.

**Step 7:** `ChildListMutex` ensures that the pointer to the global pointer to the mutex that protects access to the global linked list of child processes is set to a new mutex.

```cpp
    if (ChildListMutex == nullptr)
        ChildListMutex = osl_createMutex();
```

**Step 8:** The process is actually executed in this thread, when it is done it sets the condition variable to allow the function to shutdown the process cleanly.

Note that it calls on `osl_createThread(ChildStatusProc, &Data)` - we fork and execute the process in `ChildStatusProc(...)` which I will detail later.

```cpp
    Data.m_started = osl_createCondition();
    
    hThread = osl_createThread(ChildStatusProc, &Data);
    
    if (hThread != nullptr)
    {
        osl_waitCondition(Data.m_started, nullptr);
    }
    osl_destroyCondition(Data.m_started);
```

**Step 9:** Free up all resources

The process is actually executed in this thread, when it is done it sets the condition variable to allow the function to shutdown the process cleanly.

```cpp
    for (i = 0; Data.m_pszArgs[i] != nullptr; i++)
        free(const_cast<char *>(Data.m_pszArgs[i]));
    
    for (i = 0; Data.m_pszEnv[i] != nullptr; i++)
        free(Data.m_pszEnv[i]);
    
    if ( Data.m_pszDir != nullptr )
    {
        free(const_cast<char *>(Data.m_pszDir));
    }
    
    osl_destroyThread(hThread);
```

**Step 10:** If the process has been flagged to wait, then this waits for the child process to finish (via `osl_joinProcess(*pProcess)`, which blocks the current process until the specified process finishes).

```cpp
    if (Data.m_pProcImpl->m_pid != 0)
    {
        assert(hThread != nullptr);
        
        *pProcess = Data.m_pProcImpl;
        
        if (Options & osl_Process_WAIT)
            osl_joinProcess(*pProcess);
        
        return osl_Process_E_None;
    }
```

**Step 11:** If the process was terminated abnormally the application cleans up by destroying the termination condition variable, and frees the process structure.

```cpp
    osl_destroyCondition(Data.m_pProcImpl->m_terminated);
    free(Data.m_pProcImpl);
    
    return osl_Process_E_Unknown;
}
```

## `ChildStatusProc(...)` function

`ChildStatusProc(...)` forks and executes the process, sets up a Unix domain socket between the child and parent processes and redirects IO pipes. It works as follows:

**Step 1:** setup the function

We need to declare the function with C linking.

```c
extern "C" {
    static void ChildStatusProc(void *pData)
    {
```

It gives the current thread a name and declares the variables needed.

```c
        osl_setThreadName("osl_executeProcess");
  
        pid_t pid = -1;
        int   status = 0;
        int   channel[2] = { -1, -1 };
        ProcessData  data;
        ProcessData *pdata;
        int     stdOutput[2] = { -1, -1 }, stdInput[2] = { -1, -1 }, stdError[2] = { -1, -1 };
    
        pdata = static_cast<ProcessData *>(pData);
    
        /* make a copy of our data, because forking will only copy
           our local stack of the thread, so the process data will not be accessible
           in our child process */
        memcpy(&data, pData, sizeof(data));
```

Handles operating systems that have no processes. 

```c
#ifdef NO_CHILD_PROCESSES
#define fork() (errno = EINVAL, -1)
#endif
```

**Step 2:** create a Unix domain socket so that the parent and child processes can communicate. A Unix domain socket is part of the Unix address family (what the "AF" in "AF_UNIX" stands for), and uses a byte-oriented bi-directional stream. The `socketpair(...)` function returns a pair of file descriptors that define both communication endpoints. These file descriptors are set to close on execution termination with `fcntl(...)` by setting `FD_CLOEXEC`.

```c
        if (socketpair(AF_UNIX, SOCK_STREAM, 0, channel) == -1)
        {
            status = errno;
            SAL_WARN("sal.osl", "executeProcess socketpair() errno " << status);
        }
    
        (void) fcntl(channel[0], F_SETFD, FD_CLOEXEC);
        (void) fcntl(channel[1], F_SETFD, FD_CLOEXEC);
```

**Step 3:** create pipes for standard input, standard ouput and standard error

```c    
        /* Create redirected IO pipes */
        if (status == 0 && data.m_pInputWrite && pipe(stdInput) == -1)
        {
            status = errno;
            assert(status != 0);
            SAL_WARN("sal.osl", "executeProcess pipe(stdInput) errno " << status);
        }
    
        if (status == 0 && data.m_pOutputRead && pipe(stdOutput) == -1)
        {
            status = errno;
            assert(status != 0);
            SAL_WARN("sal.osl", "executeProcess pipe(stdOutput) errno " << status);
        }
    
        if (status == 0 && data.m_pErrorRead && pipe(stdError) == -1)
        {
            status = errno;
            assert(status != 0);
            SAL_WARN("sal.osl", "executeProcess pipe(stdError) errno " << status);
        }
```
**Step 4:** [fork the process](http://pubs.opengroup.org/onlinepubs/9699919799/functions/fork.html). What this means is that the process is cloned with a new process ID, and the cloned process is made the child of the process that forked it. 

```c    
        if ((status == 0) && ((pid = fork()) == 0))
        {
```

**Child process: Step 1:** if `fork(...)` returns 0 then the process is the child process. 

A copy of the file descriptors of the parent process is provided to the child process, which means that the child process needs to close the file descriptor used for the parent process of the Unix domain socket used for IPC between the child and parent processes. This needs to be done because until all file descriptors referencing this socket are closed the resource will not be freed.  

```c
            /* Child */
            int chstatus = 0;
            int errno_copy;
    
            if (channel[0] != -1) close(channel[0]);
```

**Child process: Step 2:** if there is a valid process user owner (`data.m_uid` is not -1) and the process owner or the process group of the child process are not the same as the parent's, then the process's uid and guid is changed to the one passed to the function. It also clears the `$HOME` environment variable. 

```c    
            if ((data.m_uid != (uid_t)-1) && ((data.m_uid != getuid()) || (data.m_gid != getgid())))
            {
                OSL_ASSERT(geteuid() == 0);     /* must be root */
    
                if (! INIT_GROUPS(data.m_name, data.m_gid) || (setuid(data.m_uid) != 0))
                    SAL_WARN("sal.osl", "Failed to change uid and guid, errno=" << errno << " (" << strerror(errno) << ")" );
    
                const rtl::OUString envVar("HOME");
                osl_clearEnvironment(envVar.pData);
            }
```

**Child process: Step 3:** change the working director of the process

```c    
            if (data.m_pszDir)
                chstatus = chdir(data.m_pszDir);
```

**Child process: Step 4:** if allowed, then checks for invalid environment variables, closes the write end of the standard input descriptor and the read end of standard output and standard error (as these do not get used in the child process and redirects the pipes created earlier to their corresponding pipe ends 

```c    
            if (chstatus == 0 && ((data.m_uid == (uid_t)-1) || ((data.m_uid == getuid()) && (data.m_gid == getgid()))))
            {
                int i;
                for (i = 0; data.m_pszEnv[i] != nullptr; i++)
                {
                    if (strchr(data.m_pszEnv[i], '=') == nullptr)
                    {
                        unsetenv(data.m_pszEnv[i]); /* TODO: check error return*/
                    }
                    else
                    {
                        putenv(data.m_pszEnv[i]); /* TODO: check error return*/
                    }
                }
    
                /* Connect std IO to pipe ends */
    
                /* Write end of stdInput not used in child process */
                if (stdInput[1] != -1) close( stdInput[1] );
    
                /* Read end of stdOutput not used in child process */
                if (stdOutput[0] != -1) close( stdOutput[0] );
    
                /* Read end of stdError not used in child process */
                if (stdError[0] != -1) close( stdError[0] );
    
                /* Redirect pipe ends to std IO */
    
                if ( stdInput[0] != STDIN_FILENO )
                {
                    dup2( stdInput[0], STDIN_FILENO );
                    if (stdInput[0] != -1) close( stdInput[0] );
                }
    
                if ( stdOutput[1] != STDOUT_FILENO )
                {
                    dup2( stdOutput[1], STDOUT_FILENO );
                    if (stdOutput[1] != -1) close( stdOutput[1] );
                }
    
                if ( stdError[1] != STDERR_FILENO )
                {
                    dup2( stdError[1], STDERR_FILENO );
                    if (stdError[1] != -1) close( stdError[1] );
                }
```

**Child process: Step 5:** program now executes the program and passes on the arguments via `execv(...)`.
    
```c  
                // No need to check the return value of execv. If we return from
                // it, an error has occurred.
                execv(data.m_pszArgs[0], const_cast<char **>(data.m_pszArgs));
            }
```

**Child process: unreachable code:** we can only get into this section if `execv` fails. If this occurs, then we send the error to the parent process to advise it of the problem. 
```c    
            SAL_WARN("sal.osl", "Failed to exec, errno=" << errno << " (" << strerror(errno) << ")");
    
            SAL_WARN("sal.osl", "ChildStatusProc : starting '" << data.m_pszArgs[0] << "' failed");
    
            /* if we reach here, something went wrong */
            errno_copy = errno;
            if ( !safeWrite(channel[1], &errno_copy, sizeof(errno_copy)) )
                SAL_WARN("sal.osl", "sendFdPipe : sending failed (" << strerror(errno) << ")");
    
            if ( channel[1] != -1 )
                close(channel[1]);
    
            _exit(255);
        }
```

**Parent process: Step 1:** `fork()` returns a non-zero positive value that holds the child process' ID when in the parent process that called on `fork()`.  If the value is -1 then this indicates an error and `errno` is set.

As with the child process closing the Unix domain socket's parent file descriptor, the parent process must close the child process' Unix domain socket file descriptor so it can later be reclaimed by the operating system. 

The unused pipe ends of the parent process must also be closed for the same reason. 

```c
        else
        {   /* Parent  */
            int i = -1;
            if (channel[1] != -1) close(channel[1]);
    
            /* Close unused pipe ends */
            if (stdInput[0] != -1) close( stdInput[0] );
            if (stdOutput[1] != -1) close( stdOutput[1] );
            if (stdError[1] != -1) close( stdError[1] );
```

**Parent process: Step 2:** If the PID is less than 0, then it indicates an error. The parent process waits for the child process to send its error to the parent process, which it reads from the socket. If the read fails, then `errno` returns `EINTR` so it breaks out of the loop.

```c    
            if (pid > 0)
            {
                while (((i = read(channel[0], &status, sizeof(status))) < 0))
                {
                    if (errno != EINTR)
                        break;
                }
            }
```

**Parent process: Step 3:** Once the child process has terminated, then close the IPC socket on the parent. 

```c    
            if (channel[0] != -1) close(channel[0]);
```

**Parent process: Step 4a:** If the process finished cleanly, then lock the child list, record the process ID, add the process to the linked list of children, and store the pipe ends in `ProcessData` structure. 

```c    
            if ((pid > 0) && (i == 0))
            {
                pid_t   child_pid;
                osl_acquireMutex(ChildListMutex);
    
                pdata->m_pProcImpl->m_pid = pid;
                pdata->m_pProcImpl->m_pnext = ChildList;
                ChildList = pdata->m_pProcImpl;
    
                /* Store used pipe ends in data structure */
    
                if ( pdata->m_pInputWrite )
                    *(pdata->m_pInputWrite) = osl::detail::createFileHandleFromFD( stdInput[1] );
    
                if ( pdata->m_pOutputRead )
                    *(pdata->m_pOutputRead) = osl::detail::createFileHandleFromFD( stdOutput[0] );
    
                if ( pdata->m_pErrorRead )
                    *(pdata->m_pErrorRead) = osl::detail::createFileHandleFromFD( stdError[0] );
    
                osl_releaseMutex(ChildListMutex);
```

Notify threads that the process has finished starting.

```c    
                osl_setCondition(pdata->m_started);
```

Now for final cleanup we need to run `waitpid(...)` on the child process. 

```c    
                do
                {
                    child_pid = waitpid(pid, &status, 0);
                } while (0 > child_pid && EINTR == errno);
    
                if ( child_pid < 0)
                {
                    SAL_WARN("sal.osl", "Failed to wait for child process, errno=" << errno << " (" << strerror(errno) << ")");
    
                    /*
                    We got an other error than EINTR. Anyway we have to wake up the
                    waiting thread under any circumstances */
    
                    child_pid = pid;
                }
```

Walk the child process list until it finds the child process that exited and check to see and store the process status - if the process exited normally (`WIFEXITED(status)`) then record this, otherwise if the process terminated abnormally (`WIFSIGNALED(status)`), in which case store the termination process status, or if it terminated for any other reason then store -1. 

After the status has been recorded set the termination condition variable. 

```c    
                if (child_pid > 0)
                {
                    oslProcessImpl* pChild;
    
                    osl_acquireMutex(ChildListMutex);
    
                    pChild = ChildList;
    
                    /* check if it is one of our child processes */
                    while (pChild != nullptr)
                    {
                        if (pChild->m_pid == child_pid)
                        {
                            if (WIFEXITED(status))
                                pChild->m_status = WEXITSTATUS(status);
                            else if (WIFSIGNALED(status))
                                pChild->m_status = 128 + WTERMSIG(status);
                            else
                                pChild->m_status = -1;
    
                            osl_setCondition(pChild->m_terminated);
                        }
    
                        pChild = pChild->m_pnext;
                    }
    
                    osl_releaseMutex(ChildListMutex);
                }
            }
```

**Parent process: Step 4b:** If the process terminated abnormally the close the pipe ends, and if for some reason the child process was actually created, to prevent the process from being a "defunct" process wait on the process, then once this is done set the condition variable to notify the parent thread.

```c
            else
            {
                SAL_WARN("sal.osl", "ChildStatusProc : starting '" << data.m_pszArgs[0] << "' failed");
                SAL_WARN("sal.osl", "Failed to launch child process, child reports errno=" << status << " (" << strerror(status) << ")");
    
                /* Close pipe ends */
                if (pdata->m_pInputWrite)
                    *pdata->m_pInputWrite = nullptr;
    
                if (pdata->m_pOutputRead)
                    *pdata->m_pOutputRead = nullptr;
    
                if (pdata->m_pErrorRead)
                    *pdata->m_pErrorRead = nullptr;
    
                if (stdInput[1] != -1) close( stdInput[1] );
                if (stdOutput[0] != -1) close( stdOutput[0] );
                if (stdError[0] != -1) close( stdError[0] );
    
                // if pid > 0 then a process was created, even if it later failed
                // e.g. bash searching for a command to execute, and we still
                // need to clean it up to avoid "defunct" processes
                if (pid > 0)
                {
                    pid_t child_pid;
                    do
                    {
                        child_pid = waitpid(pid, &status, 0);
                    } while (0 > child_pid && EINTR == errno);
                }
    
                /* notify (and unblock) parent thread */
                osl_setCondition(pdata->m_started);
            }
        }
    }

}
```

## Windows implementation

`osl_executeProcess(...)` calls on `osl_executeProcess_WithRedirectedIO(...)`, which on the Windows platforms works as follows:

**Step 1:** get the executable image name

```c
oslProcessError SAL_CALL osl_executeProcess_WithRedirectedIO(
    rtl_uString *ustrImageName,
    rtl_uString *ustrArguments[],
    sal_uInt32   nArguments,
    oslProcessOption Options,
    oslSecurity Security,
    rtl_uString *ustrDirectory,
    rtl_uString *ustrEnvironmentVars[],
    sal_uInt32 nEnvironmentVars,
    oslProcess *pProcess,
    oslFileHandle *pProcessInputWrite,
    oslFileHandle *pProcessOutputRead,
    oslFileHandle *pProcessErrorRead)
{
    rtl::OUString exe_path = get_executable_path(
        ustrImageName, ustrArguments, nArguments, (Options & osl_Process_SEARCHPATH) != 0);

    if (0 == exe_path.getLength())
        return osl_Process_E_NotFound;

    if (pProcess == nullptr)
        return osl_Process_E_InvalidError;
```

**Step 2:** check if the executable is a batch file, if so add the "batch processor" (normally `cmd.exe`, which requires a `/c` switch) to the processor

```c
    DWORD flags = NORMAL_PRIORITY_CLASS;
    rtl::OUStringBuffer command_line;

    if (is_batch_file(exe_path))
    {
        rtl::OUString batch_processor = get_batch_processor();

        if (batch_processor.getLength())
        {
            /* cmd.exe does not work without a console window */
            if (!(Options & osl_Process_WAIT) || (Options & osl_Process_DETACHED))
                flags |= CREATE_NEW_CONSOLE;

            command_line.append(batch_processor);
            command_line.append(" /c ");
        }
        else
        {
            // should we return here in case of error?
            return osl_Process_E_Unknown;
        }
    }

    command_line.append(exe_path);
```

**Step 2:** process the arguments from the command line

```c
    /* Add remaining arguments to command line. If ustrImageName is nullptr
       the first parameter is the name of the executable so we have to
       start at 1 instead of 0 */
    for (sal_uInt32 n = (nullptr != ustrImageName) ? 0 : 1; n < nArguments; n++)
    {
        command_line.append(SPACE);

        /* Quote arguments containing blanks */
        if (rtl::OUString(ustrArguments[n]).indexOf(' ') != -1)
            command_line.append(quote_string(ustrArguments[n]));
        else
            command_line.append(ustrArguments[n]);
    }
```

**Step 3:** process the environment variables

```c
    environment_container_t environment;
    LPVOID p_environment = nullptr;

    if (nEnvironmentVars && ustrEnvironmentVars)
    {
        if (!setup_process_environment(
                ustrEnvironmentVars, nEnvironmentVars, environment))
            return osl_Process_E_InvalidError;

        flags |= CREATE_UNICODE_ENVIRONMENT;
        p_environment = &environment[0];
    }
```

**Step 4:** get the directory the executable resides in.

```c
    rtl::OUString cwd;
    if (ustrDirectory && ustrDirectory->length && (osl::FileBase::E_None != osl::FileBase::getSystemPathFromFileURL(ustrDirectory, cwd)))
           return osl_Process_E_InvalidError;

    LPCWSTR p_cwd = (cwd.getLength()) ? cwd.getStr() : nullptr;
```

**Step 5:** setup the process. 

When the process is created from the command processor, the command processor creates a new [_console process_](https://msdn.microsoft.com/en-us/library/windows/desktop/ms682528%28v=vs.85%29.aspx), which is a character mode application that has an input buffer and one or more screen buffers. When the command processor creates a new process, this new process inherits the command processors's console, unless the `CreateProcess(...)` function is passed a `CREATE_NEW_CONSOLE` flag (in which case, the new process creates a new process with a new console), or `DETACHED_PROCESS` (which creates a new process, that doesn't have a console process attached to it). These two flags are obviously incompatible, hence the check to see if `CREATE_NEW_CONSOLE` is set as a flag option. 

```c
    if ((Options & osl_Process_DETACHED) && !(flags & CREATE_NEW_CONSOLE))
        flags |= DETACHED_PROCESS;
```


Allocate the initial `STARTUPINFO` instance \([`STARTUPINFO`](https://msdn.microsoft.com/en-us/library/windows/desktop/ms686331%28v=vs.85%29.aspx) &quot;specifies the window station, desktop, standard handles, and appearance of the main window for a process at creation time.")

```c
    STARTUPINFO startup_info;
    memset(&startup_info, 0, sizeof(STARTUPINFO));
```

Size of `STARTUPINFO` in bytes.

```c
    startup_info.cb        = sizeof(STARTUPINFO);
```

Flags that `wShowWindow` holds information.

```c
    startup_info.dwFlags   = STARTF_USESHOWWINDOW;
```

Indicates that the process should connect to the [interactive window station of the current user](https://msdn.microsoft.com/en-us/library/windows/desktop/ms684859%28v=vs.85%29.aspx).

```c
    startup_info.lpDesktop = const_cast<LPWSTR>(L"");
```

Redirect IO pipes.

```c
    /* Create pipes for redirected IO */
    HANDLE hInputRead  = nullptr;
    HANDLE hInputWrite = nullptr;
    if (pProcessInputWrite && create_pipe(&hInputRead, true, &hInputWrite, false))
        startup_info.hStdInput = hInputRead;

    HANDLE hOutputRead  = nullptr;
    HANDLE hOutputWrite = nullptr;
    if (pProcessOutputRead && create_pipe(&hOutputRead, false, &hOutputWrite, true))
        startup_info.hStdOutput = hOutputWrite;

    HANDLE hErrorRead  = nullptr;
    HANDLE hErrorWrite = nullptr;
    if (pProcessErrorRead && create_pipe(&hErrorRead, false, &hErrorWrite, true))
        startup_info.hStdError = hErrorWrite;

    bool b_inherit_handles = false;
    if (pProcessInputWrite || pProcessOutputRead || pProcessErrorRead)
    {
        startup_info.dwFlags |= STARTF_USESTDHANDLES;
        b_inherit_handles      = true;
    }
```

Specify the type of window - hidden, minimized, maximized or set to full screen mode.

```c
    switch(Options & (osl_Process_NORMAL | osl_Process_HIDDEN | osl_Process_MINIMIZED | osl_Process_MAXIMIZED | osl_Process_FULLSCREEN))
    {
        case osl_Process_HIDDEN:
            startup_info.wShowWindow = SW_HIDE;
            flags |= CREATE_NO_WINDOW; // ignored for non-console
                                       // applications; ignored on
                                       // Win9x
            break;

        case osl_Process_MINIMIZED:
            startup_info.wShowWindow = SW_MINIMIZE;
            break;

        case osl_Process_MAXIMIZED:
        case osl_Process_FULLSCREEN:
            startup_info.wShowWindow = SW_MAXIMIZE;
            break;

        default:
            startup_info.wShowWindow = SW_NORMAL;
    }
```

Setup the command line for the process. 

```c
    rtl::OUString cmdline = command_line.makeStringAndClear();'
```

**Step 6:** Creates the process, either as an impersonated user or as the current user. `CreateProcess(...)` takes the command line, startup info, process creation flags, environment and current working directory. It the returns the process information in a [`PROCESS_INFORMATION`](https://msdn.microsoft.com/en-us/library/windows/desktop/ms684873%28v=vs.85%29.aspx) structure. 

```c
    PROCESS_INFORMATION process_info;
    BOOL bRet = FALSE;

    if ((Security != nullptr) && (static_cast<oslSecurityImpl*>(Security)->m_hToken != nullptr))
    {
        bRet = CreateProcessAsUser(
            static_cast<oslSecurityImpl*>(Security)->m_hToken,
            nullptr, const_cast<LPWSTR>(cmdline.getStr()), nullptr,  nullptr,
            b_inherit_handles, flags, p_environment, p_cwd,
            &startup_info, &process_info);
    }
    else
    {
        bRet = CreateProcess(
            nullptr, const_cast<LPWSTR>(cmdline.getStr()), nullptr,  nullptr,
            b_inherit_handles, flags, p_environment, p_cwd,
            &startup_info, &process_info);
    }
```

**Step 7:** Once the process has been created, then the handles need to be closed. 

```c
    /* Now we can close the pipe ends that are used by the child process */

    if (hInputRead)
        CloseHandle(hInputRead);

    if (hOutputWrite)
        CloseHandle(hOutputWrite);

    if (hErrorWrite)
        CloseHandle(hErrorWrite);

    if (bRet)
    {
        CloseHandle(process_info.hThread);

        oslProcessImpl* pProcImpl = static_cast<oslProcessImpl*>(
            rtl_allocateMemory(sizeof(oslProcessImpl)));

        if (pProcImpl != nullptr)
        {
            pProcImpl->m_hProcess  = process_info.hProcess;
            pProcImpl->m_IdProcess = process_info.dwProcessId;

            *pProcess = static_cast<oslProcess>(pProcImpl);

            if (Options & osl_Process_WAIT)
                WaitForSingleObject(pProcImpl->m_hProcess, INFINITE);

            if (pProcessInputWrite)
                *pProcessInputWrite = osl_createFileHandleFromOSHandle(hInputWrite, osl_File_OpenFlag_Write);

            if (pProcessOutputRead)
                *pProcessOutputRead = osl_createFileHandleFromOSHandle(hOutputRead, osl_File_OpenFlag_Read);

            if (pProcessErrorRead)
                *pProcessErrorRead = osl_createFileHandleFromOSHandle(hErrorRead, osl_File_OpenFlag_Read);

            return osl_Process_E_None;
        }
    }

    /* if an error occurred we have to close the server side pipe ends too */

    if (hInputWrite)
        CloseHandle(hInputWrite);

    if (hOutputRead)
        CloseHandle(hOutputRead);

    if (hErrorRead)
        CloseHandle(hErrorRead);

    return osl_Process_E_Unknown;
}
```
