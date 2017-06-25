# UNO IDL

* `unoidl::Manager` - factory, creates Providers, Entities and MapCursors
  * `loadProvider(uri)` - `Provider` class - what reads the file format and converts into a type
  * `findEntity(name)` - `Entity` class - can be a module or publishable entity (struct, polymorphic struct, interface, typedef or service
  * `createCursor(name)` - `Cursor` class - iterator over the IDL file ???

* `unoidl::Provider` - factory interface, creates the root cursor, and also can find an entity, implemented by:
  * `unoidl::detail::LegacyProvider` - old store based .rdb format
  * `unoidl::detail::UnoidlProvider` - new .rdb format
  * `unoidl::detail::SourceTreeProvider` - directory of .idl files in IDL format
  * `unoidl::detail::SourceFileProvider` - .idl file in IDL format

  ![](/assets/Provider_class_dependency_diagram.svg)  
* `unoidl::Entity`

![](/assets/Entity_class_dependency_diagram.svg)