# Universal Network Objects (UNO)

TODO: 

* What is it?

Modules:

* **store** - legacy .rdb (resource database) format, handled services and types but service definitions are now replaced with XML files, and types replaced with unoidl format

* **registry** - wrapper around store to handle binary type database format, the wrapper manipulates and creates the type registry.

* **unoidl** - support for UNOIDL registry formats in a unoidl::Manager and unoidl::Provider implementation; also contains helper tools to covert to UNOIDL format, and a few other functions
