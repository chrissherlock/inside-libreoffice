# Universal Network Objects

UNO is a component model that allows LibreOffice to create objects \(components\) that can communicate between processes, and across network boundaries. 

UNO runs in what is known as a UNO Runtime Environment \(URE\). It is similar in many ways to COM+, Corba and Mozilla's XPCOM technologies. Each component that is created is operated on via _interfaces_ from a _service_. An interface describes one aspect of an object, however each object might have a variety of aspects to its functionality. Thus the concept of a service must be introduced - basically it specifies the object's functionality via multiple services. The object then inherits the service, which it must then concretely implemented.

 ![Services](../.gitbook/assets/RelationshipSpecImpl.png)  
**Figure: Services in LibreOffice**  
Source: [OpenOffice](https://wiki.openoffice.org/wiki/File:RelationshipSpecImpl.png), License: ALv2

## Startup

It is instructive to see how UNO is started in LibreOffice. This is done via the function `cppu::defaultBootstrap_InitialComponentContext()`. This function finds the configuration file for the URE, which stores information about the types and services that are implemented in UNO. 

LibreOffice creates a service manager and a type manager. Before we can understand what a service manager and a type manager are, and how they are constructed, there are a few concepts we must understand first.

### Types

#### Basic types

UNO was designed to be language agnostic. Due to this, it has it's own set of types and these must be mapped to the language that the component is being developed in \(we call this the _language binding_\). The following are the basic, fundamental types:

| UNO name | Description | Type library enumeration | C++ type |
| :--- | :--- | :--- | :--- |
| void | empty type | `typelib_TypeClass_VOID` | `void` |
| boolean | Boolean type | `typelib_TypeClass_BOOLEAN` | `sal_Bool` |
| byte | signed 8-bit integer type | `typelib_TypeClass_BYTE` | `sal_Int8` |
| short | signed 16-bit integer type | `typelib_TypeClass_SHORT` | `sal_InT16` |
| unsigned short | unsigned 16-bit integer type | `typelib_TypeClass_BYTE` | `sal_uInt16` |
| long | signed 32-bit integer type | `typelib_TypeClass_LONG` | `sal_uInt32` |
| unsigned long | unsigned 32-bit integer type | `typelib_TypeClass_UNSIGNED_LONG` | `sal_Int32` |
| hyper | signed 64-bit integer type | `typelib_TypeClass_HYPER` | `sal_Int64` |
| unsigned hyper | unsigned 64-bit integer type | `typelib_TypeClass_UNSIGNED_HYPER` | `sal_uInt64` |
| float | IEC 60559 single precision floating point type | `typelib_TypeClass_FLOAT` | `float` |
| double | IEC 60599 double precision floating point type | `typelib_TypeClass_DOUBLE` | `double` |
| char | 16-bit Unicode character type \(UTF-16 code unit\) | `typelib_TypeClass_CHAR` | `sal_Unicode` |

One further simple type is the UNO string type, however this has no corresponding simple C++ type - it actually maps to the `rtl::OUString` class and the enumeration in the type library is `typelib_TypeClass_STRING`.

One further basic type is an Enum type \(an enumeration\). These are the same concept as a C++ enum, but do not map to enums directly. When creating a UNO enum, they are used with the scope operator - so the enum `com.sun.star.table.CellVertJustify` is defined as `com::sun::star::table::CellVertJustify.TOP`.

These basic types are implemented via a C type library. A type is essentially defined by a type description, and these references to these type descriptions are used when creating new instances of the types. The following is an example of how you can create a type reference:

```cpp
typelib_TypeDescriptionReference* pType 
    = *typelib_static_type_getByTypeClass(typelib_TypeClass_FLOAT);
typelib_typedescriptionreference_acquire(pType);

// use the type

typelib_typedescriptionreference_release(pType);
```

To create an enum, the typelib requires an array of `rtl_uString`s to the enumerator names, and an array of integers to define the enumerator name indices. The following is a basic unit test that creates and then releases an enumerator:

```cpp
void Test::testNewEnum()
{
    // create an array of strings { "enum1", "enum2" }
    rtl_uString* sEnumName1 = nullptr;
    rtl_uString_newFromAscii(&sEnumName1, "enum1\0");

    rtl_uString* sEnumName2 = nullptr;
    rtl_uString_newFromAscii(&sEnumName2, "enum2\0");

    rtl_uString** pEnumNames;
    pEnumNames = (rtl_uString**)malloc(sizeof(struct _rtl_uString*) * 2);
    pEnumNames[0] = sEnumName1;
    pEnumNames[1] = sEnumName2;

    // create an array of corresponding enum values for each name (this *could* be { 1, 3 })
    sal_Int32 pEnumValues[2] = { 1, 2 };

    // now we create the new enumerator type description called "testenum"
    typelib_TypeDescription* pType = nullptr;
    typelib_typedescription_newEnum(&pType, OUString("testenum").pData, 1, 1, pEnumNames,
                                    pEnumValues);

    // we need to register this new enum type
    typelib_typedescription_register(&pType);

    // now we need to get a reference to the type
    typelib_TypeDescriptionReference* pTypeRef = nullptr;
    typelib_typedescriptionreference_new(&pTypeRef, typelib_TypeClass_ENUM,
                                         OUString("testenum").pData);

    typelib_typedescriptionreference_acquire(pTypeRef);
    CPPUNIT_ASSERT_EQUAL(OUString("testenum"), OUString(pTypeRef->pTypeName));
    typelib_typedescriptionreference_release(pTypeRef);

    rtl_uString_release(sEnumName1);
    rtl_uString_release(sEnumName2);
    free(pEnumNames);
}
```

This is reasonably self explanatory, however note that you must register enum types before they can be accessed.

The type library is wrapped by the C++ `Type` class, which wraps a `typelib_TypeDescriptionReference` pointer. To construct a new Type, you pass it a TypeClass enum \(translates to `typelib_TypeClass`\) and a type description string; alternatively you can pass a `typelib_TypeDescriptionReference` pointer.

### Service Manager

The Service Manager manages a set of components. Here is how it works:

{% code title="cppuhelper/source/servicemanager.hxx" %}
```cpp
    rtl::Reference smgr(
        new cppuhelper::ServiceManager);
    smgr->init(getBootstrapVariable(bs, "UNO_SERVICES"));
```
{% endcode %}

The Service Manager is initialized by parsing a config file, which the environment variable UNO\_SERVICES points to on application startup. Whilst there is a legacy config files in a binary format, the preferred format is a well defined XML file. The services configuration file starts something like this:

{% code title="services.rdb" %}
```cpp
<?xml version="1.0"?>
<components xmlns="http://openoffice.org/2010/uno-components">
  <component loader="com.sun.star.loader.SharedLibrary"
  environment="gcc3" prefix="binaryurp"
  uri="vnd.sun.star.expand:$URE_INTERNAL_LIB_DIR/libbinaryurplo.dylib">
    <implementation name="com.sun.star.comp.bridge.BridgeFactory">
      <service name="com.sun.star.bridge.BridgeFactory" />
    </implementation>
  </component>
  <component loader="com.sun.star.loader.SharedLibrary"
  environment="gcc3" prefix="io"
  uri="vnd.sun.star.expand:$URE_INTERNAL_LIB_DIR/libiolo.dylib">
    <implementation name="com.sun.star.comp.io.Pump">
      <service name="com.sun.star.io.Pump" />
    </implementation>
    <implementation name="com.sun.star.comp.io.stm.DataInputStream">
      <service name="com.sun.star.io.DataInputStream" />
    </implementation>
    <implementation name="com.sun.star.comp.io.stm.DataOutputStream">
      <service name="com.sun.star.io.DataOutputStream" />
    </implementation>
    <implementation name="com.sun.star.comp.io.stm.MarkableInputStream">
      <service name="com.sun.star.io.MarkableInputStream" />
    </implementation>
    <implementation name="com.sun.star.comp.io.stm.MarkableOutputStream">
      <service name="com.sun.star.io.MarkableOutputStream" />
    </implementation>
    <implementation name="com.sun.star.comp.io.stm.ObjectInputStream">
      <service name="com.sun.star.io.ObjectInputStream" />
    </implementation>
    <implementation name="com.sun.star.comp.io.stm.ObjectOutputStream">
      <service name="com.sun.star.io.ObjectOutputStream" />
    </implementation>
    <implementation name="com.sun.star.comp.io.stm.Pipe">
      <service name="com.sun.star.io.Pipe" />
    </implementation>
    <implementation name="com.sun.star.comp.io.Acceptor">
      <service name="com.sun.star.connection.Acceptor" />
    </implementation>
    <implementation name="com.sun.star.comp.io.Connector">
      <service name="com.sun.star.connection.Connector" />
    </implementation>
    <implementation name="com.sun.star.comp.io.TextInputStream">
      <service name="com.sun.star.io.TextInputStream" />
    </implementation>
        <implementation name="com.sun.star.comp.io.TextOutputStream">
      <service name="com.sun.star.io.TextOutputStream" />
    </implementation>
  </component>
```
{% endcode %}

The Service Manager needs the following to manage each component:

* **Loader**: specifies what loads the component, 
* **Environment**: it is loaded in \(e.g. Java, gcc3, etc.\)
* **Module URI:** what the service is implemented in.
* **Service implementations:** this provides an implementation name, in a namespace, can provide an optional contructor function to initialize the service \(there must, however, be an environment provided in the component\)
  * an implementation can have a **Service**, which is defined by a grouping of interfaces
  * an implementation can further be defined as a **Singleton**, which defines a global name for a UNO object and determines that there can only be one instance of this object that must be reachable under this name 

### Type Manager



## Modules

* **store** - legacy .rdb \(resource database\) format, handled services and types but service definitions are now replaced with XML files, and types replaced with unoidl format
* **registry** - wrapper around store to handle binary type database format, the wrapper manipulates and creates the type registry.
* **stoc** - an old registries, reflection and introspection implementation for UNO.
* **xmlreader** - implements a simple, fast pull parser, currently used by configmgr and stoc's simpleregistry code \(used to register UNO components in services.rdb files\). It supports a subset of XML features, but is fast and small.
* **unoidl** - support for UNOIDL registry formats in a unoidl::Manager and unoidl::Provider implementation; also contains helper tools to covert to UNOIDL format, and a few other functions
* **cppu** - stands for C++ UNO, and contains the definitions and implementations for binary UNO.
* **cppuhelper** - helpers for using cppu in C++, e.g. templates for implementing UNO components, bootstrapping
* **i18nlangtag** - code for language tags, LanguageTag wrapper for [liblangtag](http://tagoh.github.io/liblangtag/index.html) and converter between BCP47 language tags, Locale \(Language, Country, Variant\) and MS-LangIDs.
* **jvmfwk** - Wrappers so you can use all the Java Runtime Environments with their slightly incompatible APIs with more ease

