# Universal Content Broker

The [UCB](https://wiki.documentfoundation.org/Documentation/DevGuide/Universal\_Content\_Broker) (Universal Content Broker) provides a standard interface for generalized access to different data sources and functions for querying, modifying, and creating data contents. The LibreOffice document types are all handled by the UCB. In addition, it is used for help files, directory trees and resource links.

To provide access to such disparate sources, the UCB uses a system of _providers_ (the UCP).&#x20;

## UCB setup

The UCB is setup from the desktop module via the desktop module, from [`Desktop::RegisterServices()`](https://opengrok.libreoffice.org/xref/core/desktop/source/app/appinit.cxx?r=91ba9654#87).&#x20;
