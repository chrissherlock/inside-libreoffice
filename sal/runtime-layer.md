# Runtime Layer

The runtime layer \(RTL\) provides a interface for platform independent functionality. The library implements memory management, handles strings, locales, processes and object lifecycle management, amongst other things.

## Bootstrapping

When LibreOffice loads, it must read a config file. RTL contains code that bootstraps the configuration from a config file. The ini file is set via the function `rtlbootstrapsetInitFileName()` This function must be called before getting individual bootstrap settings.

The location of the bootstrap files is:

* `%APPDATA%\libreoffice\4\user` \(Windows\)
* `/home/<user name>/.config/libreoffice/4/user` \(Linux\)
* `~/Library/Application Support/LibreOffice/4/user` \(macOS\)
* `/assets/rc` \(Android, in the app's .apk archive\)

Once the bootstrap filename is set, you must open the file via `rtl_bootstrap`_`args`_`open()` and to close it you use `rtlbootstrapargsclose()` The open function returns a handle to the bootstrap settings file. To get the ini file you call on `rtl_bootstrap_get_iniNamefrom_handle()`

To get the value of a setting, you call `rtl_bootstrap_get()`and to set a value, you call `rtl_bootstrap_set()`

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

