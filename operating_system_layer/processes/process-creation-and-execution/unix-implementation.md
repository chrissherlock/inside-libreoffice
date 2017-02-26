# Unix implementation

The function `osl_executeProcess_WithRedirectedIO()` in Unix works as follows:

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

The process is actually loaded and executed in step 6, with a call to `osl_psz_executeProcess(...)`, which works as follows:

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

Note that it calls on `osl_createThread(ChildStatusProc, &Data)` - we fork and execute the process in `ChildStatusProc()` which I will detail later.

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