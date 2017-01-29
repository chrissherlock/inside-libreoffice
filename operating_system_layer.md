# Operating System Layer

The OSL \(Operating System Layer\) allows cross platform access to common operating system features but that are accessed differently depending on the platform. The OSL consists of a series of C++ classes, backed by a C-based API for maximum portability. This was necessary when Star Division started because many of the things needed, such as mutexes, condition variables, threading, time functions and a variety of other operating system specific mechanisms hadn't been produced by libraries such as the STL, and certainly what was there couldn't be used as a cross platform solution. 

As the C++ Standard Template Library has matured, there have also been other libraries that work in a cross platform manner \(such as Boost\) and so large parts of the OSL \(or most of it\) is largely better handled by these libraries. The following will discuss the functionality implemented in the OSL, with a comparison against more modern, cross platform C++ libraries. 

## Threading

A computer program consists of one or many [_threads of execution_](https://en.wikipedia.org/wiki/Thread_(computing)). Each thread represents the smallest sequence of programmed instructions that can be managed independently by a scheduler. LibreOffice's OSL can manage multiple threads of execution, which exist within the LibreOffice process. 

In OSL, threads are encapsulated by the `Thread` class. This class has been designed to be inherited - to use it, derive your thread class from `Thread` and implement the `run()` function, and if necessary implement the `onTerminated()` function. A very basic example can be found in the SAL unit tests - navigate to [sal/qa/osl/thread/test\_thread.cxx](http://opengrok.libreoffice.org/xref/core/sal/qa/osl/thread/test_thread.cxx) and review the test class, also named `Thread `

