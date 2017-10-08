# Universal Network Objects (UNO)

UNO is a component model that allows LibreOffice to create objects that can communicate between processes, and across network boundaries. It is similar in many ways to COM+, Corba and Mozilla's XPCOM technologies. Each object that is created is operated on via _interfaces_ from a _service_. An interface describes one aspect of an object, however each object might have a variety of aspects to its functionality. Thus the concept of a service must be introduced - basically it specifies the object's functionality via multiple services. The object then inherits the service, which it must then concretely implement. 

<span style="align: center">
![Services](/assets/RelationshipSpecImpl.png)<br>**Figure: Services in LibreOffice** <br>Source: [OpenOffice](https://wiki.openoffice.org/wiki/File:RelationshipSpecImpl.png), License: ALv2</span>



Modules:

* **store** - legacy .rdb (resource database) format, handled services and types but service definitions are now replaced with XML files, and types replaced with unoidl format

* **registry** - wrapper around store to handle binary type database format, the wrapper manipulates and creates the type registry.

* **stoc** - an old registries, reflection and introspection implementation for UNO.

* **xmlreader** - implements a simple, fast pull parser, currently used by configmgr and stoc's simpleregistry code (used to register UNO components in services.rdb files). It supports a subset of XML features, but is fast and small.

* **unoidl** - support for UNOIDL registry formats in a unoidl::Manager and unoidl::Provider implementation; also contains helper tools to covert to UNOIDL format, and a few other functions

* **cppu** - stands for C++ UNO, and contains the definitions and implementations for binary UNO.

* **cppuhelper** - helpers for using cppu in C++, e.g. templates for implementing UNO components, bootstrapping

* **i18nlangtag** - code for language tags, LanguageTag wrapper for [liblangtag](http://tagoh.github.io/liblangtag/index.html) and converter between BCP47 language tags, Locale (Language, Country, Variant) and MS-LangIDs.



