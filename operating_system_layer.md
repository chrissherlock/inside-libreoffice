# Operating System Layer

The OSL \(Operating System Layer\) allows cross platform access to common operating system features but that are accessed differently depending on the platform. The OSL consists of a series of C++ classes, backed by a C-based API for maximum portability. This was necessary when Star Division started because many of the things needed, such as mutexes, condition variables, threading, time functions and a variety of other operating system specific mechanisms hadn't been produced by libraries such as the STL, and certainly what there was couldn't be used as a cross platform solution.

As the C++ Standard Template Library has matured, there have also been other libraries that work in a cross platform manner \(such as [Boost](http://www.boost.org/)\) and so large parts of the OSL \(or all of it\) is largely better handled by these libraries. The following will discuss the functionality implemented in the OSL, with a comparison against more modern, cross platform C++ libraries.

## Threading

A computer program consists of one or many [_threads of execution_](https://en.wikipedia.org/wiki/Thread_(computing). Each thread represents the smallest sequence of programmed instructions that can be managed independently by a scheduler. LibreOffice's OSL can manage multiple threads of execution, which exist within the LibreOffice process.

### Thread creation

In OSL, threads are encapsulated by the `Thread` class. This class has been designed to be inherited - to use it, derive your thread class from `Thread` and implement the `run()` function, and if necessary implement the `onTerminated()` function.

To create a new thread, you first call upon the `ThreadClassName::create()` function - which actually calls upon [`osl::Thread::create()`](http://opengrok.libreoffice.org/xref/core/include/osl/thread.hxx#70) - and you then implement your functionality in `ThreadClassName::run()`, which is a pure virtual function in [`osl::Thread::run()`](http://opengrok.libreoffice.org/xref/core/include/osl/thread.hxx#172). Only one thread can be executing at any time, however whilst you can create a new thread and have it run immediately via the `create()` function, but you can also create a suspended thread until you decide to unsuspend it to do work via [`createSuspended()`](http://opengrok.libreoffice.org/xref/core/include/osl/thread.hxx#createSuspended).

#### Example

A very basic example can be found in the SAL unit tests - navigate to [sal/qa/osl/thread/test\_thread.cxx](http://opengrok.libreoffice.org/xref/core/sal/qa/osl/thread/test_thread.cxx) and review the test class, also named `Thread`:

```cpp
osl::Condition global;

class Thread: public osl::Thread
{
public:
    explicit Thread(osl::Condition &cond) : m_cond(cond) {}

private:
    virtual void SAL_CALL run() {}
    virtual void SAL_CALL onTerminated();

    osl::Condition &m_cond;
}

void Thread::onTerminated() 
{
    m_cond.set();
    CPPUNIT_ASSERT_EQUAL(osl::Condition::result_ok, global.wait());
}
```

\(We will get to `osl::Condition` soon\)

The unit test creates 50 `Thread` instances, which each call the `create()` function. It then has each thread instance wait on one global condition variable. Once all the threads have been created the main thread sets the global condition variable, which "wakes up" all of the created threads and the main thread then waits for 20 seconds to give each of the threads time to complete fully before the program in turn terminates itself.

The [unit test function](http://opengrok.libreoffice.org/xref/core/sal/qa/osl/thread/test_thread.cxx#53) is:

```cpp
void test() 
{
    for (int i = 0; i < 50; ++i) {
        osl::Condition c;
        Thread t(c);
        CPPUNIT_ASSERT(t.create());
        // Make sure virtual Thread::run/onTerminated are called before Thread::~Thread:
        CPPUNIT_ASSERT_EQUAL(osl::Condition::result_ok, c.wait());
    }

    // Make sure Thread::~Thread is called before each spawned thread terminates:
    global.set();

    // Give the spawned threads enough time to terminate:
    osl::Thread::wait(std::chrono::seconds(20));
}
```

To run the thread via the CPPUnit test framework, the test repeats a loop 50 times that creates an `osl::Condition` object instance \(which is a condition variable\), then the newly derived `Thread` class is used to instantiate a new thread instance, passing in the condition variable. The thread is then created via the [`osl:Thread::create()`](http://opengrok.libreoffice.org/xref/core/include/osl/thread.hxx#70) function, and whilst this thread is being created returns control to the main thread which then waits for this thread's condition variable to be set.

The thread is created via a low level C-based OSL thread API function, which sets a global callback function [`threadFunc()`](http://opengrok.libreoffice.org/xref/core/include/osl/thread.hxx#threadFunc) that when invoked calls on the thread's`osl::Thread:run()` function and then calls on the thread's`osl::Thread::onTerminated()` function. As the run\(\) function essentially does nothing, the onTerminated\(\) function runs immediately. This termination function flags the threads condition variable, which wakes up the main thread so it can process the next thread it wants to create in the loop. The termination function then waits on a global condition variable global. In essense what happens is that each thread gets created, runs itself, then makes its termination function wait for all the threads to also run and get into the termination phase of their lifecycle.

Once each of the threads are created the main thread sets the global condition variable, which all the threads are waiting to be changed so they can continue terminating. To be sure that everything is processed fully, the main thread then waits 20 seconds before it too terminates.

### Condition variables

What, you may ask, is a "condition variable"? A condition variable is essentially an object that is initially cleared which a thread waits on until it is "set". It allows a thread to synchronize execution by allowing other threads to wait for the condition to change before that thread then continues execution. LibreOffice's OSL implements this idiom via the [`osl::Condition`](http://opengrok.libreoffice.org/xref/core/include/osl/conditn.hxx) class. This is the equivalent of the C++ Standard Template Library's [`std::condition_variable`](http://en.cppreference.com/w/cpp/thread/condition_variable), however it is nowhere near as robust, and in fact has been deprecated in favor of this anyway. Nonetheless, it is still used so it is worthwhile explaining.

`osl::Condition` works by first instantiating a new instance of the condition, and a thread then calls on it's `wait()` function \(which has an optional timeout parameter\). The condition starts as false, and then when condition has been met, then the condition variable's `set()` function is called which releases all waiting threads.

A condition variable can be reused via the `reset()` function, which sets the condition back to false. It also has a `check()` function which checks if the condition is set without blocking execution.

### Thread operations

Threads can be suspended via the `suspend()` function, suspended threads can later be resumed via the `resume()` function. A thread can be put to sleep for a time via the `wait()` function, which takes a [`TimeValue`](http://opengrok.libreoffice.org/xref/core/include/osl/time.h#TimeValue) instance to specify the time the thread should be sleeping for. A thread can also wait for another thread to wait for the completion of another thread by calling on the other thread's `join()` function, or if it has no work it can call on the `Yeild()` function to place itself at the bottom of the queue of scheduled threads, then relinquish control to the next thread. And of course, a thread can end itself by calling on the `terminate()` function. If you want to see if a thread is running, then call `isRunning()`.

A thread uses the `schedule()` function to indicate to the thread scheduler that it is ready to be given control and waits for the scheduler to unsuspend it. A common and basic use of the `schedule()` function is to :

```cpp
void SAL_CALL run() override
{
    while (schedule()) {
        printf("Called schedule() again");
    }
}
```

What happens here is that a loop is started that calls `schedule()` each time until the thread terminates. All `schedule()` does is to check or wait for the thread to be unsuspended, after which it checks if the thread has been terminated and if so then it returns false - thus ending the loop. Otherwise `schedule()` returns true and the loop continues.

Threads can be given higher or lower priorities, which effects the thread scheduler of the operating system. This is largely operating system dependent. Linux, for instance, by default uses a [round robin scheduler](http://man7.org/linux/man-pages/man2/sched_setscheduler.2.html), which works by allocating a time slice to each thread of each priority level. The threads at the highest priority level will be run first, each running for the timeslice allocated them, then will be suspended and the scheduler will move on to execute the next thread for it's timeslice, and so on. Once no threads need to execute anything, it drops to the priority below it and executes all these theads in a round robin fashion until it too has no more active threads. The scheduler eventually drops to the lowest priority and does the same on these threads.

A thread's priority is set via `setPriority()` and `getPriority()`.

### Mutexes

As resources are shared between multiple threads due to the threads being in the same process, mechanisms to allow threads to gain exclusive access to theses resources are needed to ensure that race conditions do not occur. Once such mechanism is the _mutex_, which is short for "mututal exclusion". Mutexes act as a way of allowing a thread to use or modify a resource to the exclusion of all other threads.

#### Base `osl::Mutex` class

The [`osl::Mutex`](http://opengrok.libreoffice.org/xref/core/include/osl/mutex.hxx#Mutex) class is the base class that defines a mutual exclusion synchronization object.  A newly instantiated Mutex object calls on the lower level C-based `osl_createMutex()` function, and this mutex is later destroyed by `osl_destroyMutex()` via the `Mutex`destructor. Once the mutex has been created, the program then attempts to [`acquire()`](http://opengrok.libreoffice.org/xref/core/include/osl/mutex.hxx#acquire) the mutex which involves reserving it for the sole use of the current thread, or if it is in use already the program blocks execution \(i.e. temporarily stops doing anything\) until the mutex is released by the thread holding it, after which the current thread "acquires" the mutex exclusively. Once the critical bit of work is done, the thread releases the mutex via the [`release()`](http://opengrok.libreoffice.org/xref/core/include/osl/release.hxx#acquire) function, which allows other previous blocked threads to acquire the mutex, or if none are blocked allows new threads to acquire the mutex exclusively.

> _**Note!**_ if using a `osl::Mutex` object directly, then you should first release the mutex and \_then \_delete the object. This is because the osl\_destroyMutex\(\) function only releases the underlying operating system structures and frees the data structure. Destroying the mutex before unlocking it can lead to undefined behaviour on some platforms - the most notable being POSIX-based systems which uses `[pthread_mutex_destroy](http://pubs.opengroup.org/onlinepubs/9699919799/)` - [IEEE Std 1003.1-2008, 2016 Edition](http://pubs.opengroup.org/onlinepubs/9699919799/) states that:
>
> > _"Attempting to destroy a locked mutex, or a mutex that another thread is attempting to lock, or a mutex that is being used in a pthread\_cond\_timedwait\(\) or pthread\_cond\_wait\(\) call by another thread, results in undefined behavior."_

A further primitive function provided by the `osl::Mutex` class is the rather oddly named [`tryToAcquire()`](http://opengrok.libreoffice.org/xref/core/include/osl/mutex.hxx#tryToAcquire) function, which attempts to acquire the mutex, but unlike the regular acquire function which blocks the thread, this function just returns an error if another thread holds the mutex.

`osl::Mutex` also provides for a "global mutex", which can be acquired by calling [`osl::Mutex::getGlobalMutex()`](http://opengrok.libreoffice.org/xref/core/include/osl/mutex.hxx#getGlobalMutex). This static class function acts as a [critical section](https://en.wikipedia.org/wiki/Critical_section) for LibreOffice code - in other words, once in the critical section the thread gains exclusive access to that section of code and any thread that needs access to it will block until the thread holding the global mutex releases it.

#### Guards

The osl::Mutex class can and is used in LibreOffice code, however often what happens is that a mutex is applied in a function and then is released just before the function returns. Consequently, a safer "guard" class was developed which releases the mutex once the mutex is destroyed.

Guards are implemented by a base, templatized class named [`osl::Guard`](http://opengrok.libreoffice.org/xref/core/include/osl/mutex.hxx#Guard). This is derived from `osl::Mutex` and takes a generic template parameter, which expects a class that implements the `acquire()` and `release()` functions. It works in much the same way as a Mutex, except

### Threading example

As with most things in LibreOffice, there is a unit test available that shows how things should work. In this case, we will examine the source code at [sal/qa/osl/process/osl\_Thread.cxx](http://opengrok.libreoffice.org/xref/core/sal/qa/osl/process/osl_Thread.cxx) This is a comprehensive suite of threading unit tests based on CppUnit. The first test focuses on thread creation - it uses a thread class [`myThread`](http://opengrok.libreoffice.org/xref/core/sal/qa/osl/process/osl_Thread.cxx#myThread) designed for the purpose.

myThread is defined as the following:

```cpp
/** Simple thread for testing Thread-create.

    Just add 1 of value 0, and after running, result is 1.
 */

class myThread : public Thread
{
    ThreadSafeValue<sal_Int32> m_aFlag;

public:
    sal_Int32 getValue() { return m_aFlag.getValue(); }

protected:
    /** guarded value which initialized 0

        @see ThreadSafeValue
    */
    void SAL_CALL run() override
        {
            while(schedule())
            {
                m_aFlag.incValue();
                ThreadHelper::thread_sleep_tenth_sec(1);
            }
        }

public:
    virtual void SAL_CALL suspend() override
        {
            m_aFlag.acquire();
            ::osl::Thread::suspend();
            m_aFlag.release();
        }

    virtual ~myThread() override
        {
            if (isRunning())
            {
                t_print("error: not terminated.\n");
            }
        }

};
```

We will temporarily ignore mutexes for now and focus on the thread concepts I discussed above. Note that `ThreadSafeValue` is a templatized class created for this test that allows a thread to gain exclusive access to the value without any other thread interfering with it.

