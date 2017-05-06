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

## Windows

On Windows a process is terminated after either `TerminateProcess()` or `ExitProcess()` is called, or the final thread is terminated. If ExitProcess\(\) is called, then each attached dll has its entrypoint called \(`DLL`_`PROCESS`_`DETACH`\) indicating that the process is detaching from the dll. This does not occur when `TerminateProcess()` is called. Unlike Unix, however, a child process does not need to be reparented, and does not make the parent process wait.  

