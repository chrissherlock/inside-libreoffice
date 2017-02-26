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

