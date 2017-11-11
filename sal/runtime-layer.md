# Runtime Layer

The runtime layer \(RTL\) provides a interface for platform independent functionality. The library implements memory management, handles strings, locales, processes and object lifecycle management, amongst other things.

## Bootstrapping

When LibreOffice loads, it must read a config file. RTL contains code that bootstraps the configuration from a config file. This code is found in [sal/rtl/bootstrap.cxx](https://opengrok.libreoffice.org/xref/core/sal/rtl/bootstrap.cxx) The ini file is set via the function `rtl_bootstrap_set_InitFileName()` This function must be called before getting individual bootstrap settings.

The location of the bootstrap files is:

* `%APPDATA%\libreoffice\4\user` \(Windows\)
* `/home/<user name>/.config/libreoffice/4/user` \(Linux\)
* `~/Library/Application Support/LibreOffice/4/user` \(macOS\)
* `/assets/rc` \(Android, in the app's .apk archive\)

Once the bootstrap filename is set, you must open the file via `rtl_bootstrap_args_open()` and to close it you use `rtl_bootstrap_args_close()`  The open function returns a handle to the bootstrap settings file. To get the ini file you call on `rtl_bootstrap_get_iniNamefrom_handle()`

To get the value of a setting, you call `rtl_bootstrap_get()`and to set a value you call `rtl_bootstrap_set().`

Note that the bootstrap code allows for macro expansion \(in `Bootstrap_Impl::expandValue()` and `Bootstrap_Impl::expandMacros()`\). Basically, the key and/or value can contain a macro that will be expanded - the syntax is `${file:key}`, where file is the ini file, and key is the value to be looked up in the ini file. In fact, it also handles nested macros, so you can have `${file:${file:key}}` or `${${file:key}:${file:key}}` or even \(if you are insane\) `${${file:${file:key}}:${file:${file:${file:key}}}}`.

When the key is looked up via `Bootstrap_Impl::getValue()`, there are some special hardcoded values. They are:

* `_OS`
* `_ARCH`
* `CPPU_ENV`
* `APP_DATA_DIR` \(for both Android and iOS\)
* `ORIGIN` \(gets the path to the ini file\)

There is also a few system defined variables that can be overridden by an environment variable or from the command line \(the function name is rather confusingly called `getAmbienceValue()`...\). These are:

* `SYSUSERCONFIG`
* `SYSUSERHOME`
* `SYSBINDIR`

_All_ of these values can be overriden, however, by using the syntax `${.override:file:value}`

There is a final macro expansion that falls back to an `osl::Profile` lookup - the syntax for this is `${key}`. However, this does _not_ allow for expanding macros, so you can't do something like `${${file:key}}`. A [comment in the code](https://opengrok.libreoffice.org/xref/core/sal/rtl/bootstrap.cxx#991-994) actually states that it:

> ..erroneously does not recursively expand macros in the resulting replacement text \(and if it did, it would fail to detect cycles that pass through here\)

Finally, if no value can be found, the `Bootstrap_Impl::getValue()` allows for a default value to be optionally specified.

Note that the unit tests for this were never converted, and removed in the [following commit](https://cgit.freedesktop.org/libreoffice/core/commit/?id=18cc5cb2fdb8bca18a6c55d0a165b749f6730420).

## Process and library management

TODO: process.h - how this difference from process management in OSL, why it is needed, etc; unload.h

## Object lifecycle management

TODO: ref.hxx, instance.hxx

## Memory management

TODO: alloc.h

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

