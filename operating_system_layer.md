# Operating System Layer

The OSL \(Operating System Layer\) allows cross platform access to common operating system features but that are accessed differently depending on the platform. The OSL consists of a series of C++ classes, backed by a C-based API for maximum portability. This was necessary when Star Division started because many of the things needed, such as mutexes, condition variables, threading, time functions and a variety of other operating system specific mechanisms hadn't been produced by libraries such as the STL, and certainly what there was couldn't be used as a cross platform solution.

As the C++ Standard Template Library has matured, there have also been other libraries that work in a cross platform manner \(such as Boost\) and so large parts of the OSL \(or all of it\) is largely better handled by these libraries. The following will discuss the functionality implemented in the OSL, with a comparison against more modern, cross platform C++ libraries.

## Threading

A computer program consists of one or many [_threads of execution_](https://en.wikipedia.org/wiki/Thread_(computing). Each thread represents the smallest sequence of programmed instructions that can be managed independently by a scheduler. LibreOffice's OSL can manage multiple threads of execution, which exist within the LibreOffice process.

In OSL, threads are encapsulated by the `Thread` class. This class has been designed to be inherited - to use it, derive your thread class from `Thread` and implement the `run()` function, and if necessary implement the `onTerminated()` function. A very basic example can be found in the SAL unit tests - navigate to [sal/qa/osl/thread/test\_thread.cxx](http://opengrok.libreoffice.org/xref/core/sal/qa/osl/thread/test_thread.cxx) and review the test class, also named `Thread`:

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

The unit test creates 50 threads which each wait on one global condition variable. Once all the threads have been created the main thread sets the global condition variable, which "wakes up" all of the created threads and the main thread then waits for 20 seconds to give each of the threads time to complete fully before the program in turn terminates itself.

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

