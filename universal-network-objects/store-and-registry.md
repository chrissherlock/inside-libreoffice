# Store and Registry

## Store

This module implements a legacy binary UNO types format, still used by extensions and core code. Eventually the LibreOffice team want to migrate away from this format.&#x20;

The module works on files and memory streams. Possibly the easiest way of understanding how the format works is to show an example of how to read and write a byte of data to a memory stream (writing to a file backed store works in almost the same way):

* To open a file in memory, you do the following:\
  \
  `store::OStoreFile aFile;`\
  `aFile.createInMemory()`\

* To write to the file, you must first open a stream, then write to it. The following is an example of how to write a byte to the stream, and then read the byte back again.\
  \
  `if aFile.isValid();`\
  `{`\
  &#x20;   `store::OStoreStream aStream;`\
  &#x20;   `if (aStream.create(aFile,`\
  &#x20;                  `"testnode", // normally the directory`\
  &#x20;                  `"testname", // normally the file name`\
  &#x20;                  `storeAccessMode::ReadWrite)`\
  &#x20;   `{`\
  &#x20;       `{`\
  &#x20;           `std::unique_ptr<sal_uInt8[]> pWriteBuffer(new sal_uInt8[1]);`\
  &#x20;           `pWriteBuffer[0] = 'a';`\
  ``\
  &#x20;           `sal_uInt32 writtenBytes;`\
  &#x20;           ``            \
  &#x20;           `if (!(aStream.writeAt(`\
  &#x20;                     `0,            // start offset`\
  &#x20;                     `pWriteBuffer.get(),`\
  &#x20;                     `1,            // number of bytes to write`\
  &#x20;                     `writtenBytes) // record the bytes written` \
  &#x20;                  `&& writtenBytes == 1))` \
  &#x20;           `{`\
  &#x20;              `assert(false);`\
  &#x20;           `}`\
  &#x20;       `}`\
  ``\
  &#x20;       `{`\
  &#x20;           `std::unique_ptr<sal_uInt8[]> pReadBuffer;`\
  &#x20;           `sal_uInt32 readBytes;`\
  ``\
  &#x20;           `if (!(aStream.readAt(`\
  &#x20;                     `0,            // start offset`\
  &#x20;                     `pReadBuffer.get(),`\
  &#x20;                     `1,            // number of bytes to read`\
  &#x20;                     `readBytes) // record the bytes read` \
  &#x20;                  `&& readBytes == 1))` \
  &#x20;           `{`\
  &#x20;              `assert(false);`\
  &#x20;           `}`\
  &#x20;       `}`\
  &#x20;   `}`\
  `}`

As the store is deprecated, I will not go into how it actually stores the files.&#x20;

## Registry

The registry holds the system's UNO type information in a database.&#x20;
