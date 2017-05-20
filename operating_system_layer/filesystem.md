# Filesystem

The OSL provides a universal portable and high performance interface that can access file system functionality on any operating systems. The interface has a few main goals:

1. The path specifications always has to be absolute. Any usage of relative path specifications is forbidden. Exceptions are `osl_getSystemPathFromFileURL()`, `osl_getFileURLFromSystemPath()` and `osl_getAbsoluteFileURL()`. Most operating  
   systems provide a "Current Directory" per process, which is the reason why  relative path specifications can cause problems in multithreading  environments.

2. Proprietary notations of file paths are not supported. Every path notation must the file URL specification. File URLs must be encoded in UTF8 and after that escaped. Although the URL parameter is a unicode string, the must contain only ASCII characters.

3. The caller cannot get any information whether a file system is case sensitive, case preserving or not. The operating system implementation itself should determine if it can map case-insensitive paths. The case correct notation of a filename or file path is part of the "File Info". This case correct name can be used as a unique key if necessary.

4. Obtaining information about files or volumes is controlled by a bitmask which specifies which fields are of interest. Due to performance reasons it is not recommended to obtain information which is not needed.  But if the operating system provides more information anyway the implementation can set more fields on output as were requested. It is in the responsibility of the caller to decide if they use this additional information or not. But they should do so to prevent further unnecessary calls if the information is already there.

   The input bitmask supports a flag `osl_FileStatus_Mask_Validate` which can be used to force retrieving uncached validated information. Setting this flag when calling `osl_getFileStatus` in combination with no other flag is a synonym for a "FileExists". This should only be done when processing a single file \(i.e. before opening\) and _never_ during enumeration of directory contents on any step of information processing. This would change the runtime behaviour from O\(n\) to O\(n\*n/2\) on nearly every file system.  On Windows NT-based operating systems, reading the contents of an directory with 7000 entries and getting full information about every file only takes 0.6 seconds. Specifying the flag osl\_FileStatus\_Mask\_Validate for each entry will increase the time to 180 seconds \(!!!\).

## File URIs

The filesystem abstraction uses file URIs as a way of handling the different file system naming conventions in a cross-platform way. The format of a file URI is specified in [RFC8089](https://tools.ietf.org/html/rfc8089) and looks like the following:

```
file://host/path
```

The host part is the name of the system on which to locate the file (and should be the FQDN), and the path is the directory name that specifies the location of the file in the filesystem. The host part is optional, so you can specify `file:///path/to/file.txt`

There is an exception for DOS and Windows drive letters, in that the file URI will include the drive letter and a colon, then the absolute path:

```
file:///c:/path/to/file
```

## Absolute file URIs

The API does not refer to file URIs as Universal Resource _Indicators_, but as file URLs (Universal Resource _Locations_), which is actually a misnomer as a URL specifically refers to web resources and not files on local filesystems. 

To get an absolute file URI, you must call `osl_getAbsoluteFileURL()` - the first parameter being the base directory of the relative path, and the path relative to the base directory. Alternatively, if the base parameter is set to NULL or is empty, then the OSL expects the relative parameter to actually hold an absolute URI. This function returns an error code, and uses the third parameters as an output parameter to hold the absolute file URI it generates. 

## System paths

A system path is a filesystem location encoded in the format required by the underlying operating system. Both Unix and Windows have specific quirks that must be converted before LibreOffice can form a file URI. On Unix, the `osl_getFileURLFromSystemPath()` first checks if the path starts with the ~ character (or ~user), and if so replaces it with the appropriate home directory, and it converts any occurences of repeated slashes to a single slash. 

> **Note:** the POSIX standard actually states that any path starting with double-slashes should be treated in an implementation manner. This is a bug reported in [bug 107967](https://bugs.documentfoundation.org/show_bug.cgi?id=107967)
