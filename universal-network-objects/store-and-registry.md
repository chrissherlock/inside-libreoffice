# Store, Registry and UNO-IDL

## Store

This module implements a legacy binary UNO types format, still used by extensions and core code. Eventually the LibreOffice team want to migrate away from this format.

The module works on files and memory streams. Possibly the easiest way of understanding how the format works is to show an example of how to read and write a byte of data to a memory stream (writing to a file backed store works in almost the same way):

* To open a file in memory, you do the following:

```cpp
  store::OStoreFile aFile;
  aFile.createInMemory()
```

* To write to the file, you must first open a stream, then write to it. The following is an example of how to write a byte to the stream, and then read the byte back again.

```cpp
  if aFile.isValid();
  {
     store::OStoreStream aStream;
     if (aStream.create(aFile,
                    "testnode", // normally the directory
                    "testname", // normally the file name
                    storeAccessMode::ReadWrite)
     {
         {
             std::unique_ptr<sal_uInt8[]> pWriteBuffer(new sal_uInt8[1]);
             pWriteBuffer[0] = 'a';
             
             sal_uInt32 writtenBytes;
             
             if (!(aStream.writeAt(
                       0,            // start offset
                       pWriteBuffer.get(),
                       1,            // number of bytes to write
                       writtenBytes) // record the bytes written
                    && writtenBytes == 1))
             {
                assert(false);
             }
         }
         
         {
             std::unique_ptr<sal_uInt8[]> pReadBuffer;
             sal_uInt32 readBytes;
             
             if (!(aStream.readAt(
                       0,            // start offset
                       pReadBuffer.get(),
                       1,            // number of bytes to read
                       readBytes) // record the bytes read
                    && readBytes == 1))
             {
                assert(false);
             }
         }
     }
  }
```

As the store is deprecated, I will not go into how it actually stores the files.

**Note:** I have written some unit tests, please see [https://gerrit.libreoffice.org/c/core/+/127674](https://gerrit.libreoffice.org/c/core/+/127674) - one day hopefully a developer will review.

## Registry

The registry holds the system's UNO type information in a database. The following data types are stored in the registry:

* Modules
* Structs
* Enums
* Interfaces
* Exceptions
* Services
* Value types (aka constants)

#### Reading the registry

All keys in the registry are part of a module. To read the registry, you must first open it. To do this, you first instantiate a `Registry` object, and call `open()`**.** You then need to open the root key (the registry is a hierarchical key/value store), and from the root key you can find your subkey.

For example, say you have a registry file with a single module called ModuleA, containing a constant key "test", you would do the following:

```cpp
#include <registry/registry.hxx>

Registry reg;
reg.open("registryfile.reg", RegAccessMode::READONLY);

RegistryKey root;
reg.openRootKey(root);

RegistryKey modulekey;
root.openKey("ModuleA", modulekey);

RegistryKey testkey;
modulekey.openKey("test");
```

#### UNO-IDL

UNOIDL (UNO Interface Definition Language) is a way of specifying types, services, and other entities used by UNO via a metalanguage of its own. UNOIDL should be seen as a specification language, and is the building block used by UNO to create UNO components, which consist of a variety of compiled libraries that interacts are are bound to the UNO infrastructure.

[Starting in LibreOffice 7.5](https://gerrit.libreoffice.org/c/core/+/122363/), developers will start to use the unoidl module to write and read UNO types. Changes made will mean that LibreOffice extensions are now incompatible with OpenOffice.org extensions, and any LibreOffice extensions developed before LibreOffice 4.1 will no longer work either. This has been a very necessary step in degunking extemely legacy code (the idlc module and regmerge utility are being removed).

The unoidl module actually handles more than just types, it also processes the UNO modules, services, singletons, etc. that make up actual object instances. These are managed via .idl (Interface Definition Language) files, and thus must be processed differently than the binary types.rdb file.&#x20;

The first step in reading the registry is to load a _provider_, which does the hard work of actually reading from the binary types file. The provider is used to create the _root cursor_ - this cursor holds the root location in the type registry. This is then used to navigate the registry.

Let's say you have a types.rdb file. To open the file for reading, you must first instantiate a provider manager, and have the manager produce the provider that does the work of parsing the rdb file:

```clike
rtl::Reference<unoidl::Manager> mgr(new unoidl::Manager);
rtl::Reference<unoidl::Provider> prov = mgr.addProvider("types.rdb");
```

Each provider produces a root`MapCursor` which is a simple forward iterator. Each type is returned as an `Entity`.

```clike
rtl::Reference<unoidl::MapCursor> cursor = prov->getRootCursor();

for (;;)
{
    OUString id;
    rtl::Reference<unoidl::Entity> ent(cursor->getNext(&id));
    
    if (!ent.is()) {
        break;
    }
    
    // process entity
}
```

#### Interface Definition Language (IDL)

The BNF notation for IDL files that define services is [as follows](https://www.openoffice.org/udk/common/man/idl\_syntax.html):

```
(1) <idl_specification> := <definition>+

(2) <definition> := <type_decl> ";"
                    | <module_decl> ";"
                    | <constant_decl> ";"
                    | <exception_decl> ";"
                    | <constants_decl> ";"
                    | <service_decl> ";"

(3) <type_decl> := <interface>
                   | <struct_decl>
                   | <enum_decl>
                   | <union_decl>
                   | "typedef" <type_spec> <declarator> {"," <declarator> }* 

(4) <interface> := <interface_decl>
                   | <forward_decl>

(5) <forward_decl> := "interface" <identifier>

(6) <interface_decl> := <interface_header> "{" <interface_body> "}"

(7) <interface_header> := "interface" <identifier> [ <interface_inheritance> ]

(8) <interface_inheritance> := ":" <interface_name>

(9) <interface_name> := <scoped_name>

(10) <scoped_name> := <identifier>
                      | "::" <scoped_name>
                      | <scoped_name> "::" <identifier>

(11) <interface_body> := <export>+

(12) <export> := <attribute_decl> ";"
                 | <operation_decl> ";"

(13) <attribute_decl> := <attribute_head> <type_spec> <declarator> { "," <declarator> }*

(14) <attribute_head> := "[" ["readonly" ","] "attribute" "]"
                         | "[" "attribute" ["," "readonly"] "]"


(15) <declarator> := <identifier>
                     | <array_declarator> 

(16) <array_declarator> := <identifier> <array_size>+

(17) <array_size> := "[" <positive_int> "]"

(18) <positive_int> := <const_expr>

(19) <type_spec> := <simple_type_spec>
                    | constr_type_spec>

(20) <simple_type_spec> := <base_type_spec>
                           | <template_type_spec>
                           | <scoped_name>

(21) <base_type_spec> := <integer_type>
                         | <floating_point_type>
                         | <char_type>
                         | <byte_type>  
                         | <boolean_type>
                         | <string_type>
                         | <any_type>
                         | <type_type>

(22) <template_type> := <sequence_type>
                        | <array_type>

(23) <sequence_type> := "sequence" "<" <type_spec> ">"

(24) <array_type> := <type_spec> <array_size>+

(25) <floating_point_type> := "float"
                              | "double"

(26) <integer_type> := <signed_int>
                       | <unsinged_int>

(27) <signed_int> := "short"
                     | "long"
                     | "hyper"


(28) <unsigned_int> := "unsigned" "short"
                       | "unsigned" "long"
                       | "unsigned" "hyper"

(29) <char_type> := "char"

(30) <type_type> := "type"

(31) <string_type> := "string"

(32) <byte_type> := "byte"

(33) <any_type" := "any"

(34) <boolean_type> := "boolean"

(35) <constr_type_spec> := <struct_type>
                           | <enum_type>
                           | <union_type>

(36) <struct_type> := "struct" <identifier> [ <struct_inheritance> ] "{" <member>+ "}"

(37) <struct_inheritance> := ":" <scoped_name>

(38) <member> := <type_spec> <declarator> { "," <declarator> }*

(39) enum_type> := enum <identifier> "{" <enumerator> { "," <enumerator> }* "}"

(40) <enumerator> := <identifier> [ "=" <positive_int> ]

(41) <union_type> := "union" <identifier> "switch" "(" <switch_type_spec> ")"
                       "{" <switch_body> "}"    

(42) <switch_type_spec> := <integer_type>
                           | <enum_type>
                           | <scoped_name> 

(43) <switch_body> := <case>+

(44) <case> := <case_label> <element_spec> ";"

(45) <case_label> := "case" <const_expr> ":" 
                     | "default" ":";

(46) <element_spec> := <type_spec> <declarator>

(47) <exception_decl> := "exception" <identifier> [ <exception_inheritance> ] "{" <member>* "}"

(48) <exception_inheritance> := ":" <scoped_name>

(49) <module_decl> := "module" <identifier> "{" <definition>+ "}"

(50) <constant_decl> := "const" <const_type> <identifier> "=" <const_expr>

(51) <const_type> := <integer_type>
                     | <char_type>
                     | <boolean_type>
                     | <floating_point_type>  
                     | <string_type>
                     | <scoped_name>

(52) <const_expr> := <or_expr>

(53) <or_expr> := <xor_expr>
                  | <or_expr> "|" <xor_expr>

(54) <xor_expr> := <and_expr>
                   | <xor_expr> "^" <and_expr>

(55) <and_expr> := <shift_expr>
                   | <and_expr> "&" <shift_expr>

(56) <shift_expr> := <add_Expr>
                     | <shift_expr ">>" <add_expr>
                     | <shift_expr "<<" <add_expr>

(57) <add_expr> := <mult_expr>
                   | <add_expr> "+" <mult_expr>
                   | <add_expr> "-" <mult_expr>

(58) <mult_Expr> := <unary_expr>
                    | <mult_expr> "*" <unary_expr>
                    | <mult_expr> "/" <unary_expr>
                    | <mult_expr> "%" <unary_expr>

(59) <unary_expr> := <unary_operator><primary_expr>
                     | <primary_expr>

(60) <unary_operator> := "-" | "+" | "~"

(61) <primary_expr> := <scoped_name>
                       | <literal>
                       | "(" <const_expr> ")"

(62) <literal> := <integer_literal>
                  | <string_literal>
                  | <character_literal>
                  | <floating_point_literal>
                  | <boolean_literal>

(63) <boolean_literal> := "TRUE"
                          | "True"
                          | "FALSE"
                          | "False"
(64) <service_decl> := "service" <identifier> "{" <service_member>+ "}"

(65) <service_member> := <property_decl> ";"
                         | <support_decl> ";"
                         | <export_decl> ";"
                         | <observe_decl> ";"
                         | <needs_decl> ";"

(66) <property_decl> := <property_head> <type_spec> <declarator> { "," <declarator> }*

(67) <property_head> := "[" {<property_flags> ","}* "property" "]"
                         | "[" "property" {"," <property_flags>}* "]" 

(68) <property_flags> := "readonly"
                        | "bound
                        | "constrained"
                        | "maybeambigious"
                        | "maybedefault"
                        | "maybevoid"
                        | "optional"
                        | "removable"
                        | "transient"

(69) <support_decl> := "interface" <declarator> { "," <declarator> }*

(70) <export_decl> := "service" <declarator> { "," <declarator> }*

(71) <observe_decl> := "observe" <declarator> { "," <declarator> }*

(72) <needs_decl> := "needs" <declarator> { "," <declarator> }*

(73) <constants_decl> := "constants" <identifier> "{" <constant_decl>+ "}"
```

### Examples

Some examples using IDL:

#### Defining types

```
interface Example : ::BaseExample 
{
    [readonly, attribute] short exampleArray[10];
    long exampleVariable;

    struct ExampleStruct {
      unsigned hyper member;
    }
}
```
