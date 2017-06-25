# UNO IDL

UNO IDL is a way of specifying, types, services, and other entities used by UNO. The BNF notation is [as follows](https://www.openoffice.org/udk/common/man/idl_syntax.html):

```idl
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

## Classes

* `unoidl::Manager` - factory, creates Providers, Entities and MapCursors
  * `loadProvider(uri)` - `Provider` class - what reads the file format and converts into a type
  * `findEntity(name)` - `Entity` class - can be a module or publishable entity (struct, polymorphic struct, interface, typedef or service
  * `createCursor(name)` - `Cursor` class - iterator over the IDL file ???

* `unoidl::Provider` - factory interface, creates the root cursor, and also can find an entity, implemented by:
  * `unoidl::detail::LegacyProvider` - old store based types.rdb format
  * `unoidl::detail::UnoidlProvider` - newer, binary types.rdb format
  * `unoidl::detail::SourceTreeProvider` - directory of .idl files in IDL format
  * `unoidl::detail::SourceFileProvider` - .idl file in IDL format

  ![](/assets/Provider_class_dependency_diagram.svg)  
* `unoidl::Entity`
  * `unoidl::ModuleEntity`
  * `unoidl::PublishableEntity`
    * Services:
      * `unoidl:ServiceBasedSingletonEntity`
      * `unoidl:SingleInterfaceBasedServiceEntity`
      * `unoidl::AccumulationBasedServiceEntity`
    * Interfaces:
      * `InterfaceBasedSingletonEntity`
      * `InterfaceTypeEntity`
    * Exceptions:
      * `unoidl::ExceptionTypeEntity`
    * struct:
      * `unoidl::PlainStructTypeEntity`
      * `unoidl::PolymorphicStructTypeTemplateEntity`
    * Enumeration
      * `unoidl::EnumTypeEntity`
    * Typedef
      * `unoidl::TypedefEntity`
    * `unoidl::ConstantGroupEntity`  

![](/assets/Entity_class_dependency_diagram.svg)