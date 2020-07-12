# Runtime Layer

The runtime layer \(RTL\) provides a interface for platform independent functionality. The library implements memory management, handles strings, locales, processes and object lifecycle management, amongst other things.

## Bootstrapping

When LibreOffice loads, it must read a config file. RTL contains code that bootstraps the configuration from a config file. This code is found in [sal/rtl/bootstrap.cxx](https://opengrok.libreoffice.org/xref/core/sal/rtl/bootstrap.cxx) The ini file is set via the function `rtl_bootstrap_set_InitFileName()` This function must be called before getting individual bootstrap settings.

The location of the bootstrap files is:

* `%APPDATA%\libreoffice\4\user` \(Windows\)
* `/home/<user name>/.config/libreoffice/4/user` \(Linux\)
* `~/Library/Application Support/LibreOffice/4/user` \(macOS\)
* `/assets/rc` \(Android, in the app's .apk archive\)

Once the bootstrap filename is set, you must open the file via `rtl_bootstrap_args_open()` and to close it you use `rtl_bootstrap_args_close()` The open function returns a handle to the bootstrap settings file. To get the ini file you call on `rtl_bootstrap_get_iniNamefrom_handle()`

To get the value of a setting, you call `rtl_bootstrap_get()`and to set a value you call `rtl_bootstrap_set().`

Note that the bootstrap code allows for macro expansion \(in `Bootstrap_Impl::expandValue()` and `Bootstrap_Impl::expandMacros()`\). Basically, the key and/or value can contain a macro that will be expanded - the syntax is `${file:key}`, where file is the ini file, and key is the value to be looked up in the ini file. In fact, it also handles nested macros, so you can have `${file:${file:key}}` or `${${file:key}:${file:key}}` or even \(if you are insane\) `${${file:${file:key}}:${file:${file:${file:key}}}}`.

When the key is looked up via `Bootstrap_Impl::getValue()`, there are some special hardcoded values. They are:

* `_OS`
* `_ARCH`
* `CPPU_ENV`
* `APP_DATA_DIR` \(for both Android and iOS\)
* `ORIGIN` \(gets the path to the ini file\)

There is also a few system defined variables that can be overridden by an environment variable or from the command line via the `-env:` switch \(the function name is rather confusingly called `getAmbienceValue()`...\). These are:

* `SYSUSERCONFIG`
* `SYSUSERHOME`
* `SYSBINDIR`

_All_ of these values can be overriden, however, by using the syntax `${.override:file:value}`

There is a final macro expansion that falls back to an `osl::Profile` lookup - the syntax for this is `${key}`. However, this does _not_ allow for expanding macros, so you can't do something like `${${file:key}}`. A [comment in the code](https://opengrok.libreoffice.org/xref/core/sal/rtl/bootstrap.cxx#991-994) actually states that it:

> ...erroneously does not recursively expand macros in the resulting replacement text \(and if it did, it would fail to detect cycles that pass through here\)

Finally, if no value can be found, the `Bootstrap_Impl::getValue()` allows for a default value to be optionally specified.

Note that the unit tests for this were never converted, and removed in the [following commit](https://cgit.freedesktop.org/libreoffice/core/commit/?id=18cc5cb2fdb8bca18a6c55d0a165b749f6730420).

## Process and library management

The RTL functions for processes get the process ID and command line arguments. They differ subtly from the OSL functions. `rtl_getProcessID()` _\_gets a UUID that represents the process ID,_ \_but does not use the Ethernet address. `rtl_getAppCommandArg()` and `rtl_getAppCommandArgCount()` gets the command line arguments, but ignores the ones set by `-env:`

## Object lifecycle management

RTL implements its own shared pointer via the `Reference` class. It is largely equivalent to `std::shared_ptr`, using reference counting to own a pointer, but is less fully featured. The functions are defined in `include/rtl/ref.hxx`

| **rtl::Reference** | **std::shared\_ptr** |
| :--- | :--- |
| `template <class reference_type> Reference(reference_type*);` | `shared_ptr <class U> shared_ptr(U*);` |
| `Reference<reference_type> operator= &(reference_type*);` | `shared_ptr& operator= (const shared_ptr&) noexcept;` |
| `Reference<reference_type>& set(reference_type*);` | `shared_ptr& operator= (const shared_ptr&) noexcept;` |
| `reference_type* get() const;` | `element_type* get() const noexcept;` |
| `reference_type& operator* () const;` | `element_type& operator* () const noexcept;` |
| `reference_type* operator-> () const;` | `element_type* operator-> () const noexcept;` |
| `Reference<reference_type>& clear();` | `template<class U> void reset(U*);` |
| same relational operators | same relational operators |
| `bool is() const;` | `operator bool() const noexcept;` |
| no equivalent `swap()` function | `void swap(shared_ptr&) noexcept;` |
| no equivalent `use_count()` function | `long int use_count() const noexcept;` |
| no equivalent `unique()` function | `bool unique() const noexcept;` |

For a singleton class that uses [double-checked locking](http://www.cs.umd.edu/~pugh/java/memoryModel/DoubleCheckedLocking.html), the class `rtl::Instance` can be used.

## Memory management

RTl handles memory allocation. There are two memory allocators - one that uses the standard malloc-based allocator of the system, and a custom allocator that is based around [memory arenas](https://en.wikipedia.org/wiki/Region-based_memory_management). This, however, has [now been disabled](https://cgit.freedesktop.org/libreoffice/core/commit/sal?id=bc6a5d8e79e7d0e7d75ac107aa8e6aa275e434e9) \(except in the `bridges` module, which bridges C++ ABIs, Java JNI and Microsoft .NET to UNO and back\).

The standard, malloc-based allocator uses the following functions:

| Function name | Allocator |
| :--- | :--- |
| `rtl_allocateMemory(sal_Size Bytes)` | `malloc(size_t bytes)` |
| `rtl_reallocateMemory(void *p, sal_Size Bytes)` | `realloc(void *p, size_t bytes)` |
| `rtl_freeMemory(void *p)` | `free(void *p)` |

There are a few additional functions that build on these. `rtl_allocateZeroMemory` allocates memory, but uses `memset` to zero out that memory via `memset`. `rtl_secureZeroMemory` fills a block of memory with zeroes in a way that is guaranteed to be secure \(for Unix it is implemented casting the pointer to a volatile char pointer, then it zeroes out each byte in a loop - the volatile pointer ensures that the compiler will not optimize this away. `rtl_secureZeroMemory` and `rtl_freeZeroMemory` do similar things.

## Byte sequences

TODO: byteseq.h, byteseq.hxx

## String handling

TODO: character.hxx, strbuf.h, strbuff.hxx, string.h, string.hxx, stringconcat.hxx, stringutils.hxx, textenc.h, textcvt.h, textenc.h, ustrbuf.h, ustrbuff.hxx, ustring.h, ustring.hxx

## Locale handling

TODO: locale.h

## URI handling

TODO: uri.h, uri.hxx

## UUIDs, Ciphers, digests, CRCs and random generator

TODO: uuid.h, cipher.h, crc.h, digest.h, random.h

