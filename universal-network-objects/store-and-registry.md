# Store and Registry

## Store

This module implements a legacy binary UNO types format, still used by extensions and core code. Eventually the LibreOffice team want to migrate away from this format.

The module works on files and memory streams. Possibly the easiest way of understanding how the format works is to show an example of how to read and write a byte of data to a memory stream (writing to a file backed store works in almost the same way):

* To open a file in memory, you do the following:

```cpp
  store::OStoreFile aFile;
  aFile.createInMemory()
```

* To write to the file, you must first open a stream, then write to it. The following is an example of how to write a byte to the stream, and then read the byte back again.

```cpp
  if aFile.isValid();
  {
     store::OStoreStream aStream;
     if (aStream.create(aFile,
                    "testnode", // normally the directory
                    "testname", // normally the file name
                    storeAccessMode::ReadWrite)
     {
         {
             std::unique_ptr<sal_uInt8[]> pWriteBuffer(new sal_uInt8[1]);
             pWriteBuffer[0] = 'a';
             
             sal_uInt32 writtenBytes;
             
             if (!(aStream.writeAt(
                       0,            // start offset
                       pWriteBuffer.get(),
                       1,            // number of bytes to write
                       writtenBytes) // record the bytes written
                    && writtenBytes == 1))
             {
                assert(false);
             }
         }
         
         {
             std::unique_ptr<sal_uInt8[]> pReadBuffer;
             sal_uInt32 readBytes;
             
             if (!(aStream.readAt(
                       0,            // start offset
                       pReadBuffer.get(),
                       1,            // number of bytes to read
                       readBytes) // record the bytes read
                    && readBytes == 1))
             {
                assert(false);
             }
         }
     }
  }
```

As the store is deprecated, I will not go into how it actually stores the files.

**Note:** I have written some unit tests, please see [https://gerrit.libreoffice.org/c/core/+/127674](https://gerrit.libreoffice.org/c/core/+/127674) - one day hopefully a developer will review.

## Registry

The registry holds the system's UNO type information in a database. The following data types are stored in the registry:

* Modules
* Structs
* Enums
* Interfaces
* Exceptions
* Services
* Value types (aka constants)

****

#### Reading the registry

All keys in the registry are part of a module. To read the registry, you must first open it. To do this, you first instantiate a `Registry` object, and call `open()`**.** You then need to open the root key (the registry is a hierarchical key/value store), and from the root key you can find your subkey.

For example, say you have a registry file with a single module called ModuleA, containing a constant key "test", you would do the following:

```cpp
#include <registry/registry.hxx>

Registry reg;
reg.open("registryfile.reg", RegAccessMode::READONLY);

RegistryKey root;
reg.openRootKey(root);

RegistryKey modulekey;
root.openKey("ModuleA", modulekey);

RegistryKey testkey;
modulekey.openKey("test");
```

There is another way of reading the registry. You can take the binary data and stuff it into a `Reader` instance. This exposes a fair amount of information, including a documentation field that describes what the key is used for.&#x20;

**Note:** it's highly unlikely you'll actually ever need this. The only thing that uses it is a UNO IDL processor. However, that said the unit tests are all not working for this module. I have started to migrate this to Cppunit, the patch for this is waiting here: [https://gerrit.libreoffice.org/c/core/+/128031/](https://gerrit.libreoffice.org/c/core/+/128031/)

**Bug:** if you create a Writer with no field/method/reference count, and then you try to add a field/method/reference then you get a segfault. A patch for this can be found here: [https://gerrit.libreoffice.org/c/core/+/128140/](https://gerrit.libreoffice.org/c/core/+/128140/)
