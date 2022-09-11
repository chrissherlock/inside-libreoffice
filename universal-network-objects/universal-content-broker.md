# Universal Content Broker

The [UCB](https://wiki.documentfoundation.org/Documentation/DevGuide/Universal\_Content\_Broker) (Universal Content Broker) provides a standard interface for generalized access to different data sources and functions for querying, modifying, and creating data contents. The LibreOffice document types are all handled by the UCB. In addition, it is used for help files, directory trees and resource links.

To provide access to such disparate sources, the UCB uses a system of _providers_ (the UCP).&#x20;

## UCB setup

The UCB is setup from the desktop module via the desktop module, from [`Desktop::RegisterServices()`](https://opengrok.libreoffice.org/xref/core/desktop/source/app/appinit.cxx?r=91ba9654#87). This creates an instance of `UniversalContentBroker`.&#x20;

The actual initialization of the UCB is done via the function [`configureUcb()`](https://opengrok.libreoffice.org/xref/core/ucb/source/core/ucb.cxx#configureUcb), which validates the parameters and populates a list of providers. The actual processing is done via [`registerAtUcb()`](https://opengrok.libreoffice.org/xref/core/ucbhelper/source/provider/registerucb.cxx?r=734dc3c3\&fi=registerAtUcb#registerAtUcb).

If a service name is specified, then the function can instantiate a proxy to a content provider, or if not marked as a proxy then it instantiates the content provider directly. Once this has been instatiated, it needs to be checked to see if it is a parameterized content provider in which case it registers the parameters with the provider.

Once the content provider is fully instantiated then it needs to be registered with the content provider manager. This code validates that it is not already registered, or had generates an exception during registeration, in which case it rolls back the registration.
