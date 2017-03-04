# Windows implementation

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
