# C++ UNO Runtime Engine



The C++ UNo Runtime Engine is implemented under the cppuhelper module. During bootstrap, it installs a type manager and a service manager. The service manager is installed as follows:

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
* **Environment**: it is loaded in (e.g. Java, gcc3, etc.)
* **Module URI:** what the service is implemented in.
* **Service implementations:** this provides an implementation name, in a namespace, and can provide an optional contructor function to initialize the service (there must, however, be an environment provided in the component)
  * an implementation can have a **Service**, which is defined by a grouping of interfaces
  * an implementation can further be defined as a **Singleton**, which defines a global name for a UNO object and determines that there can only be one instance of this object that must be reachable under this name
