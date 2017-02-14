# Operating System Layer

The OSL \(Operating System Layer\) allows cross platform access to common operating system features but that are accessed differently depending on the platform. The OSL consists of a series of C++ classes, backed by a C-based API for maximum portability. This was necessary when Star Division started because many of the things needed, such as mutexes, condition variables, threading, time functions and a variety of other operating system specific mechanisms hadn't been produced by libraries such as the STL, and certainly what there was couldn't be used as a cross platform solution.

As the C++ Standard Template Library has matured, there have also been other libraries that work in a cross platform manner \(such as [Boost](http://www.boost.org/)\) and so large parts of the OSL \(or all of it\) is largely better handled by these libraries. The following will discuss the functionality implemented in the OSL, with a comparison against more modern, cross platform C++ libraries.



