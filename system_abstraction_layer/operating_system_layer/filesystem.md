# Filesystem

The OSL provides a universal portable and high performance interface that can access file system functionality on any operating systems. The interface has a few main goals:

1. The path specifications always has to be absolute. Any usage of relative path specifications is forbidden. Exceptions are `osl_getSystemPathFromFileURL()`, `osl_getFileURLFromSystemPath()` and `osl_getAbsoluteFileURL()`. Most operating systems provide a "Current Directory" per process, which is the reason why relative path specifications can cause problems in multithreading environments.
2. Proprietary notations of file paths are not supported. Every path notation must the file URL specification. File URLs must be encoded in UTF8 and after that escaped. Although the URL parameter is a unicode string, the must contain only ASCII characters.
3. The caller cannot get any information whether a file system is case sensitive, case preserving or not. The operating system implementation itself should determine if it can map case-insensitive paths. The case correct notation of a filename or file path is part of the "File Info". This case correct name can be used as a unique key if necessary.
4. Obtaining information about files or volumes is controlled by a bitmask which specifies which fields are of interest. Due to performance reasons it is not recommended to obtain information which is not needed. But if the operating system provides more information anyway the implementation can set more fields on output as were requested. It is in the responsibility of the caller to decide if they use this additional information or not. But they should do so to prevent further unnecessary calls if the information is already there.

   The input bitmask supports a flag `osl_FileStatus_Mask_Validate` which can be used to force retrieving uncached validated information. Setting this flag when calling `osl_getFileStatus()` in combination with no other flag is a synonym for a "FileExists". This should only be done when processing a single file \(i.e. before opening\) and _never_ during enumeration of directory contents on any step of information processing. This would change the runtime behaviour from O\(n\) to O\(n\*n/2\) on nearly every file system. On Windows NT-based operating systems, reading the contents of an directory with 7000 entries and getting full information about every file only takes 0.6 seconds. Specifying the flag `osl_FileStatus_Mask_Validate` for each entry will increase the time to 180 seconds \(!!!\).

## File URIs

The filesystem abstraction uses file URIs as a way of handling the different file system naming conventions in a cross-platform way. The format of a file URI is specified in [RFC8089](https://tools.ietf.org/html/rfc8089) and looks like the following:

```text
file://host/path
```

The host part is the name of the system on which to locate the file \(and should be the FQDN\), and the path is the directory name that specifies the location of the file in the filesystem. The host part is optional, so you can specify `file:///path/to/file.txt`

There is an exception for DOS and Windows drive letters, in that the file URI will include the drive letter and a colon, then the absolute path:

```text
file:///c:/path/to/file
```

## Absolute file URIs

The API does not refer to file URIs as Universal Resource _Indicators_, but as file URLs \(Universal Resource _Locations_\), which is actually a misnomer as a URL specifically refers to web resources and not files on local filesystems.

To get an absolute file URI, you must call `osl_getAbsoluteFileURL()` - the first parameter being the base directory of the relative path, and the path relative to the base directory. Alternatively, if the base parameter is set to NULL or is empty, then the OSL expects the relative parameter to actually hold an absolute URI. This function returns an error code, and uses the third parameters as an output parameter to hold the absolute file URI it generates.

## System paths

A system path is a filesystem location encoded in the format required by the underlying operating system. Both Unix and Windows have specific quirks that must be converted before LibreOffice can form a file URI. On Unix, the `osl_getFileURLFromSystemPath()` first checks if the path starts with the ~ character \(or ~user\), and if so replaces it with the appropriate home directory, and it converts any occurences of repeated slashes to a single slash.

> **Note:** the POSIX standard actually states that any path starting with double-slashes should be treated in an implementation-defined manner. This is a bug reported in [bug 107967](https://bugs.documentfoundation.org/show_bug.cgi?id=107967).
>
> Interestingly, we have a quandry I have emailed the listed author of RFC8089 about: When we convert from system paths to file URIs, the RFC handles everything except for system paths on POSIX systems that start with double slashes. POSIX defines this as up to the operating system to implement. However, I cannot see anywhere in the RFC where it describes how to handle initial double slashes in file URIs. I literally have no idea what we should be doing in this case...
>
> There is also another issue whereby `~user` does not expand to the user - which I believe is largely because we haven't implemented anything that lets us impersonate users via the logon functions in `OslSecurity`.

On Windows, the function checks to see if a UNC path is being used \(i.e. of the form `\\server\path\to\file.txt`\), in which case it converts it to the file URI form.

## File searches

Both Windows and Unix have a way of directing the command processor or shell to find files in the filesystem. Both use the environment variable `$PATH` to influence searches, however each does this differently. On Windows, the `%path%` is searched _after_ the current directory is searched for the executable. On Unix, only the paths in `$PATH` are searched. Thus, a search function to unify the two operating systems is used in LibreOffice - `osl_getFileURLFromSystemPath()` which searches for a specified filename in a listed search path, and thereafter searches each of the directories in the system's PATH. The delimiter is not unified, however, so on Windows you must use the semicolon \(;\) and on Unix, you must use the colon \(:\). The API Doxygen comment for the function states that:

> The value of an environment variable should be used \(e.g. `LD_LIBRARY_PATH`\) if the caller is not aware of the Operating System and so doesn't know which path list delimiter to use.

## Temp files

To create a temp file, you must be fairly careful to ensure that you don't lead to a race condition whereby a temp file is created, then another process writes or replaces the file.

There are two functions that can be called:

* `osl_getTempDirURL()` - gets the location of temporary files
* `osl_createTempFile()` - creates a secure temporary file

## File status

In LibreOffice a file is described by its status, or list of attributes associated with the file. This is defined in [`oslFileStatus`](http://opengrok.libreoffice.org/xref/core/include/osl/file.h#oslFileStatus):

```c
typedef struct _oslFileStatus {
/** Must be initialized with the size in bytes of the structure before passing it to any function */
    sal_uInt32      uStructSize;
/** Determines which members of the structure contain valid data */
    sal_uInt32      uValidFields;
/** The type of the file (file, directory, volume). */
    oslFileType eType;
/** File attributes */
    sal_uInt64  uAttributes;
/** First creation time in nanoseconds since 1/1/1970. Can be the last modify time depending on
    platform or file system. */
    TimeValue   aCreationTime;
/** Last access time in nanoseconds since 1/1/1970. Can be the last modify time depending on
    platform or file system. */
    TimeValue   aAccessTime;
/** Last modify time in nanoseconds since 1/1/1970. */
    TimeValue   aModifyTime;
/** Size in bytes of the file. Zero for directories and volumes. */
    sal_uInt64  uFileSize;
/** Case correct name of the file. Should be set to zero before calling osl_getFileStatus
    and released after usage. */
    rtl_uString *ustrFileName;
/** Full URL of the file. Should be set to zero before calling osl_getFileStatus
    and released after usage. */
    rtl_uString *ustrFileURL;
/** Full URL of the target file if the file itself is a link.
    Should be set to zero before calling osl_getFileStatus
    and released after usage. */
    rtl_uString *ustrLinkTargetURL;
} oslFileStatus;
```

File types are:

```c
typedef enum {
    osl_File_Type_Directory,
    osl_File_Type_Volume,
    osl_File_Type_Regular,
    osl_File_Type_Fifo,
    osl_File_Type_Socket,
    osl_File_Type_Link,
    osl_File_Type_Special,
    osl_File_Type_Unknown
} oslFileType;
```

TODO: document how to set file attributes \(and file time\)

## File operations

As with any file system, you can perform a number of logical operations on the files that reside within it via the LibreOffice OSL API. The OSL API follows the Unix file system convention, which uses the following paradigm:

1. _**Open**_ the file for usage by the process

   The API function that performs this is:

   ```cpp
   oslFileError SAL_CALL osl_openFile(
      rtl_uString* strPath,
      oslFileHandle* pHandle,
      sal_uInt32 uFlags);
   ```

   The function is given a file URI, which it converts to a system path, and is provided a set of flags to tell it what mode to open the file in. A file handle that represents the file descriptor is passed back as an output parameter. This is used as a token to refer to the opened file when performing file operations.

   Windows and Unix systems use the following [flags](http://opengrok.libreoffice.org/xref/core/include/osl/file.h#osl_File_OpenFlag_Read):

   * `osl_File_OpenFlag_Read`
   * `osl_File_OpenFlag_Write`
   * `osl_File_OpenFlag_Create`
   * `osl_File_OpenFlag_NoLock`

   Unix systems use the following [flags](http://opengrok.libreoffice.org/xref/core/include/osl/detail/file.h#osl_File_OpenFlag_Trunc):

   * `osl_File_OpenFlag_Trunc`
   * `osl_File_OpenFlag_NoExcl`
   * `osl_File_OpenFlag_Private`

2. Move the cursor \(current position\) to the location in the file where you will be performing an operation \(often called _**seeking**_\).

   The API function that sets the position in the file is:

   ```cpp
   oslFileError SAL_CALL setFilePos(
       oslFileHandle Handle,
       sal_uInt32 uHow,
       sal_Int64 uPos);
   ```

   It takes a handle to a file and sets the file position based on an offset \(`uPos`\) from either the start of the file, from the current cursor position, or from the end of the file \(`uHow` can be `osl_Pos_Absolut`, `osl_Pos_Current` or `os_Pos_End` - if the latter then the offset must be negative\).

   To get the cursor position in the file, you use:

   ```cpp
   oslFileError SAL_CALL osl_getFilePos(
       oslFileHandle Handle,
       usl_uInt64 *pPos);
   ```

   To test if the end of the file is reached, call:

   ```cpp
   oslFileError SAL_CALL osl_isEndOfFile(
       osFileHandle Handle,
       sal_Bool *pIsEOF);
   ```

3. _**Read**_ or _**write**_ to the file at this cursor position, and if necessary move the cursor again; repeat as necessary.

   The function to read the file is:

   ```cpp
   osl_FileError SAL_CALL osl_readFile(
       oslFileHandle Handle,
       void *pBuffer,
       sal_uInt64 uBytesRequested,
       sal_uInt64 *pBytesRead);
   ```

   The function again takes a handle to an opened file, `pBuffer` is a pointer to a which recieves the data, `uBytesRequested` specifies the number of bytes to be read. When the file is finished reading, the number of bytes read is returned by `pBytesRead`.

   The function that writes to a file is:

   ```cpp
   osl_FileError SAL_CALL osl_writeFile(
       oslFileHandle Handle,
       void *pBuffer,
       sal_uInt64 uBytesToWrite,
       sal_uInt64 *pBytesWritten);
   ```

   Similar to `osl_ReadFile()`, `pBuffer` is a pointer to the data to be written to the file, `uBytesToWrite` specifies how many bytes should be written, and `pBytesWritten` is how many bytes are actually written to the file after the function completes.

   There are two variants that allow reads and writes from specific positions in the file, they are `osl_readFileAt()` and `osl_writeFileAt()`.

4. When all file processing is finished, then indicate that the process is done with it by _**closing**_ the file.

   To close the file you call:

   ```cpp
   oslFileError SAL_CALL osl_closeFile(osFileHandle Handle);
   ```

Another function that is quite useful is `osl_readLine()`, which reads from a file descriptor until it either hits a carriage-return \(CR\), carriage-return/line-feed \(CRLF\), or just a line-feed \(LF\).

Shared file mapping is explained further in the IPC chapter, as it can be used as inter-process communication, as well as for other functions that map the file to memory.

## Copy, move and delete files

To delete a file, call on `osl_removeFile(filename)`. This only works on regular files, if a directory is specified then it returns `osl_File_E_ISDIR`. To copy a file \(not a directory\) then call on `osl_copyFile(sourcefile, destfile)`, and to move a file call on `osl_moveFile(sourcefile, destfile)`. When moving a file, file time and attributes are preserved, but no assumptions can be made about files that are copied.

## Directory operations

## Volume operations

