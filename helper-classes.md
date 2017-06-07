# SAL Helpers

The `salhelper` module has a raft of classes designed to make SAL usage easier:

| Class                   | Description                                       |
| ----------------------- | ------------------------------------------------- |
| `Condition`<br/> `ConditionModifier`<br/> `ConditionWaiter` | A wrapper around `osl::Condition`, you construct a new `ConditionModifier` to start a condition variable, and the destructor sets the condition variable. To wait on the condition variable, you construct a `ConditionWaiter` (which takes an optional timeout parameter). |
| `ORealDynamicLoader`    | Wrapper around the `oslModule` interface, the function `newInstance()` initializes the loader, loads the library and call the initialization function. To get the list of initialized API functions call on `getApi()`. |
| `LinkResolver`          | On file systems that use file links, to resolve the file linkage, you use this class - the constructor takes a file status mask, and to fetch the file status (which, if you recall, is how you get things like the filename) you call on `fetchFileStatus(rURL, nDepth=128)` where the depth is how many times it follows the link (and returns the error `E_MULTIHOP` if it reaches this limit). |
| `ReferenceObject`       | Simple reference counting class, but deprecated in favour of `SimpleReferenceObject` |
| `SimpleReferenceObject` | Replaces `ReferenceObject`, however it uses class local `new` and `delete` operators to ensure they are called on correctly from within shared libraries that have classes that inherit from it. |
| `SingletonRef`          | Singleton class                                  |
| `Thread`                | A safe implementation of `osl::Thread`           |
| `TTimeValue`            | Helper class for easier manipulation with TimeValue, the times are seconds in UTC since 1st January, 1970. |
