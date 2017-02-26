# Unix implementation

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
    if ( pArguments == nullptr && nArguments > 0 )
    {
        pArguments = static_cast<sal_Char**>(malloc((nArguments + 2) * sizeof(sal_Char*)));
    }
        
    for ( idx = 0 ; idx < nArguments ; ++idx )
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
    for ( idx = 0 ; idx < nEnvironmentVars ; ++idx )
    {
        rtl_String* strEnv=nullptr;
        
        if ( pEnvironment == nullptr )
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
    if ( pArguments != nullptr )
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

**Step 3:** redirect IO pipes

```c    
        /* Create redirected IO pipes */
        if ( status == 0 && data.m_pInputWrite && pipe( stdInput ) == -1 )
        {
            status = errno;
            assert(status != 0);
            SAL_WARN("sal.osl", "executeProcess pipe(stdInput) errno " << status);
        }
    
        if ( status == 0 && data.m_pOutputRead && pipe( stdOutput ) == -1 )
        {
            status = errno;
            assert(status != 0);
            SAL_WARN("sal.osl", "executeProcess pipe(stdOutput) errno " << status);
        }
    
        if ( status == 0 && data.m_pErrorRead && pipe( stdError ) == -1 )
        {
            status = errno;
            assert(status != 0);
            SAL_WARN("sal.osl", "executeProcess pipe(stdError) errno " << status);
        }
```


```c    
        if ( (status == 0) && ((pid = fork()) == 0) )
        {
            /* Child */
            int chstatus = 0;
            int errno_copy;
    
            if (channel[0] != -1) close(channel[0]);
    
            if ((data.m_uid != (uid_t)-1) && ((data.m_uid != getuid()) || (data.m_gid != getgid())))
            {
                OSL_ASSERT(geteuid() == 0);     /* must be root */
    
                if (! INIT_GROUPS(data.m_name, data.m_gid) || (setuid(data.m_uid) != 0))
                    SAL_WARN("sal.osl", "Failed to change uid and guid, errno=" << errno << " (" << strerror(errno) << ")" );
    
                const rtl::OUString envVar("HOME");
                osl_clearEnvironment(envVar.pData);
            }
    
            if (data.m_pszDir)
                chstatus = chdir(data.m_pszDir);
    
            if (chstatus == 0 && ((data.m_uid == (uid_t)-1) || ((data.m_uid == getuid()) && (data.m_gid == getgid()))))
            {
                int i;
                for (i = 0; data.m_pszEnv[i] != nullptr; i++)
                {
                    if (strchr(data.m_pszEnv[i], '=') == nullptr)
                    {
                        unsetenv(data.m_pszEnv[i]); /*TODO: check error return*/
                    }
                    else
                    {
                        putenv(data.m_pszEnv[i]); /*TODO: check error return*/
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
    
                // No need to check the return value of execv. If we return from
                // it, an error has occurred.
                execv(data.m_pszArgs[0], const_cast<char **>(data.m_pszArgs));
            }
    
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
        else
        {   /* Parent  */
            int i = -1;
            if (channel[1] != -1) close(channel[1]);
    
            /* Close unused pipe ends */
            if (stdInput[0] != -1) close( stdInput[0] );
            if (stdOutput[1] != -1) close( stdOutput[1] );
            if (stdError[1] != -1) close( stdError[1] );
    
            if (pid > 0)
            {
                while (((i = read(channel[0], &status, sizeof(status))) < 0))
                {
                    if (errno != EINTR)
                        break;
                }
            }
    
            if (channel[0] != -1) close(channel[0]);
    
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
    
                osl_setCondition(pdata->m_started);
    
                do
                {
                    child_pid = waitpid(pid, &status, 0);
                } while ( 0 > child_pid && EINTR == errno );
    
                if ( child_pid < 0)
                {
                    SAL_WARN("sal.osl", "Failed to wait for child process, errno=" << errno << " (" << strerror(errno) << ")");
    
                    /*
                    We got an other error than EINTR. Anyway we have to wake up the
                    waiting thread under any circumstances */
    
                    child_pid = pid;
                }
    
                if ( child_pid > 0 )
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
            else
            {
                SAL_WARN("sal.osl", "ChildStatusProc : starting '" << data.m_pszArgs[0] << "' failed");
                SAL_WARN("sal.osl", "Failed to launch child process, child reports errno=" << status << " (" << strerror(status) << ")");
    
                /* Close pipe ends */
                if ( pdata->m_pInputWrite )
                    *pdata->m_pInputWrite = nullptr;
    
                if ( pdata->m_pOutputRead )
                    *pdata->m_pOutputRead = nullptr;
    
                if ( pdata->m_pErrorRead )
                    *pdata->m_pErrorRead = nullptr;
    
                if (stdInput[1] != -1) close( stdInput[1] );
                if (stdOutput[0] != -1) close( stdOutput[0] );
                if (stdError[0] != -1) close( stdError[0] );
    
                //if pid > 0 then a process was created, even if it later failed
                //e.g. bash searching for a command to execute, and we still
                //need to clean it up to avoid "defunct" processes
                if (pid > 0)
                {
                    pid_t child_pid;
                    do
                    {
                        child_pid = waitpid(pid, &status, 0);
                    } while ( 0 > child_pid && EINTR == errno );
                }
    
                /* notify (and unblock) parent thread */
                osl_setCondition(pdata->m_started);
            }
        }
    }

}
```