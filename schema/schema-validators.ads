-----------------------------------------------------------------------
--                XML/Ada - An XML suite for Ada95                   --
--                                                                   --
--                       Copyright (C) 2004-2010, AdaCore            --
--                                                                   --
-- This library is free software; you can redistribute it and/or     --
-- modify it under the terms of the GNU General Public               --
-- License as published by the Free Software Foundation; either      --
-- version 2 of the License, or (at your option) any later version.  --
--                                                                   --
-- This library is distributed in the hope that it will be useful,   --
-- but WITHOUT ANY WARRANTY; without even the implied warranty of    --
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU --
-- General Public License for more details.                          --
--                                                                   --
-- You should have received a copy of the GNU General Public         --
-- License along with this library; if not, write to the             --
-- Free Software Foundation, Inc., 59 Temple Place - Suite 330,      --
-- Boston, MA 02111-1307, USA.                                       --
--                                                                   --
-- As a special exception, if other files instantiate generics from  --
-- this unit, or you link this unit with other files to produce an   --
-- executable, this  unit  does not  by itself cause  the resulting  --
-- executable to be covered by the GNU General Public License. This  --
-- exception does not however invalidate any other reasons why the   --
-- executable file  might be covered by the  GNU Public License.     --
-----------------------------------------------------------------------

pragma Ada_05;

with Ada.Exceptions;
with GNAT.Dynamic_HTables;
with GNAT.Dynamic_Tables;
with Interfaces;
with Unicode.CES;
with Sax.HTable;
with Sax.Locators;
with Sax.Pointers;
with Sax.Readers;
with Sax.State_Machines;
with Sax.Symbols;
with Sax.Utils;

package Schema.Validators is

   XML_Schema_URI : constant Unicode.CES.Byte_Sequence :=
     "http://www.w3.org/2001/XMLSchema";
   XML_URI : constant Unicode.CES.Byte_Sequence :=
     "http://www.w3.org/XML/1998/namespace";
   XML_Instance_URI : constant Unicode.CES.Byte_Sequence :=
     "http://www.w3.org/2001/XMLSchema-instance";

   XML_Validation_Error : exception;
   --  Raised in case of error in the validation process. The exception message
   --  contains the error, but not its location

   XML_Not_Implemented : exception;
   --  Raised when a schema uses features that are not supported by XML/Ada yet

   type XSD_Versions is (XSD_1_0, XSD_1_1);
   --  The version of XSD the parser should support.
   --  The support for 1.1 is only partial at present.

   type XML_Validator_Record is tagged private;
   type XML_Validator is access all XML_Validator_Record'Class;
   --  A new validator is typically created every time a new element starts,
   --  and is in charge of checking the contents and attributes of that
   --  element.
   --  The default implementation always validates.

   type XML_Grammar is private;
   type XML_Grammar_NS_Record is private;
   type XML_Grammar_NS is access all XML_Grammar_NS_Record;
   --  The part of a grammar specialized for a given namespace.
   --  A grammar can contain the definition for multiple namespaces (generally
   --  the standard XML Schema namespace for predefined types, and the
   --  namespace we are defining). Each of these is accessed by a separate
   --  XML_Grammar_NS object
   --  A grammar is a smart pointer, and will take care of freeing memory
   --  automatically when no longer needed.

   procedure Set_System_Id
     (Grammar   : XML_Grammar_NS;
      System_Id : Sax.Symbols.Symbol);
   function Get_System_Id (Grammar : XML_Grammar_NS) return Sax.Symbols.Symbol;
   --  The URI from which we loaded the schema

   procedure Set_XSD_Version
     (Grammar : in out XML_Grammar;
      XSD_Version : XSD_Versions);
   function Get_XSD_Version (Grammar : XML_Grammar) return XSD_Versions;
   --  Set the version of XSD accepted by this grammar

   function Get_Symbol_Table
     (Grammar : XML_Grammar) return Sax.Utils.Symbol_Table;
   procedure Set_Symbol_Table
     (Grammar : XML_Grammar; Symbols : Sax.Utils.Symbol_Table);
   --  The symbol table used to create the grammar.
   --  Any parser using this grammmar must also use the same symbol table,
   --  otherwise no validation can succeed (this is ensured by special tests in
   --  Set_Grammar and Set_Symbol_Table).

   No_Grammar : constant XML_Grammar;
   --  No Grammar has been defined

   Unbounded : constant Integer := Integer'Last;
   --  To indicate that a Max_Occurs is set to unbounded

   type Form_Type is (Qualified, Unqualified);
   --  Whether locally declared elements need to be qualified or whether
   --  qualification is optional (the latter is the default). This does not
   --  apply to global elements, that always need to be qualified (or found in
   --  the default namespace).
   --  Note that elements defined in a <group> are considered local only if
   --  they do not use the R.Ref attribute, otherwise they are considered
   --  global and therefore the "form" does not apply to them.

   type Process_Contents_Type is (Process_Strict, Process_Lax, Process_Skip);
   --  When in an element that accepts any children (ur-type, or xsd:any), this
   --  type indicates that should be done to validate the children:
   --     Strict: the children must have a definition in the schema (as a
   --             global element)
   --     Lax:    if the children have a definition, it is used, otherwise they
   --             are just accepted as is.
   --     Skip:   even if the children have a definition, it is ignored, and
   --             the child is processed as a ur-type.

   --------------------
   -- State machines --
   --------------------
   --  The validators are implemented as state machines

   type Qualified_Name is record
      NS    : Sax.Symbols.Symbol;
      Local : Sax.Symbols.Symbol;
   end record;
   No_Qualified_Name : constant Qualified_Name :=
     (Sax.Symbols.No_Symbol, Sax.Symbols.No_Symbol);

   type Header_Num is new Interfaces.Integer_32 range 0 .. 1023;
   function Hash (Name : Qualified_Name) return Header_Num;
   function Hash (Name : Sax.Symbols.Symbol) return Header_Num;
   --  Suitable for instantiating hash tables

   type Any_Descr is record
      Process_Contents : Process_Contents_Type := Process_Strict;
      Namespace        : Sax.Symbols.Symbol := Sax.Symbols.No_Symbol;
      Target_NS        : Sax.Symbols.Symbol := Sax.Symbols.No_Symbol;
   end record;

   type Transition_Kind is (Transition_Symbol,
                            Transition_Any,
                            Transition_Close);
   type Transition_Event (Kind : Transition_Kind := Transition_Symbol) is
      record
         case Kind is
            when Transition_Symbol       => Name : Qualified_Name;
            when Transition_Close => null;
            when Transition_Any          => Any : Any_Descr;
         end case;
      end record;

   type Attribute_Validator_List is new Natural;
   Empty_Attribute_List : constant Attribute_Validator_List := 0;

   type Block_Type is (Block_Restriction,
                       Block_Extension,
                       Block_Substitution);
   type Block_Status is array (Block_Type) of Boolean;
   pragma Pack (Block_Status);
   No_Block : constant Block_Status := (others => False);

   type Final_Type is (Final_Restriction,
                       Final_Extension,
                       Final_Union,
                       Final_List);
   type Final_Status is array (Final_Type) of Boolean;
   pragma Pack (Final_Status);

   type Type_Descr is record
      Name           : Qualified_Name := No_Qualified_Name;
      Block          : Block_Status := No_Block;
      Final          : Final_Status := (others => False);
      Mixed          : Boolean := False;
      Is_Abstract    : Boolean := False;
      Simple_Content : Boolean := False;
      Attributes     : Attribute_Validator_List := Empty_Attribute_List;
      Simple_Type    : XML_Validator;  --  Validator for simpleType
   end record;
   No_Type_Descr : constant Type_Descr := (others => <>);

   type Attribute_Use_Type is (Prohibited, Optional, Required, Default);

   type Attribute_Descr is record
      Name         : Qualified_Name     := No_Qualified_Name;
      Simple_Type  : XML_Validator;
      Use_Type     : Attribute_Use_Type := Optional;
      Is_Local     : Boolean            := True;
      Fixed        : Sax.Symbols.Symbol := Sax.Symbols.No_Symbol;
      Form         : Form_Type          := Qualified;
      Default      : Sax.Symbols.Symbol := Sax.Symbols.No_Symbol;
      Target_NS    : Sax.Symbols.Symbol := Sax.Symbols.No_Symbol;

      Next         : Attribute_Validator_List; --  Next in the list
   end record;

   type State_User_Data is record
      Descr       : Type_Descr;
   end record;
   Default_User_Data : constant State_User_Data := (Descr => No_Type_Descr);
   --  All types (complexType or simpleType) are associated with a state in the
   --  NFA, which is used to hold the properties of that type.

   function Match (Trans, Sym : Transition_Event) return Boolean;
   function Image (Trans : Transition_Event) return String;
   --  Needed for the instantiation of Sax.State_Machines

   package Schema_State_Machines is new Sax.State_Machines
      (Symbol              => Transition_Event,
       Transition_Symbol   => Transition_Event,
       Match               => Match,
       Image               => Image,
       State_User_Data     => State_User_Data,
       Default_Data        => Default_User_Data,
       Default_State_Count => 1000,       --  XSD metaschema takes 904 states
       Default_Transition_Count => 1200); --  XSD metaschema takes 1096
   use Schema_State_Machines;

   function Image
     (S : Schema_State_Machines.State; Data : State_User_Data) return String;
   --  Needed for the instantiation of Pretty_Printers

   package Schema_State_Machines_PP
     is new Schema_State_Machines.Pretty_Printers (Image);

   type Reference_Kind is (Ref_Element,
                           Ref_Type,
                           Ref_Attribute,
                           Ref_Group,
                           Ref_AttrGroup);
   type Global_Reference (Kind : Reference_Kind := Ref_Element) is record
      case Kind is
         when Ref_Element   => Element : State;
         when Ref_Type      => Typ : State;  --  Start of nested NFA
         when Ref_Attribute => Attr : State;
         when Ref_Group     => Gr_Start, Gr_End : State;
         when Ref_AttrGroup => Attributes : Attribute_Validator_List;
      end case;
   end record;
   No_Global_Reference : constant Global_Reference :=
     (Ref_Type, Typ => No_State);
   --  The global elements in a grammar that can be referenced from another
   --  grammar (or from an XML file).

   type Reference_Name is record
      Name : Qualified_Name;
      Kind : Reference_Kind;
   end record;
   function Hash (Name : Reference_Name) return Header_Num;

   package Reference_HTables is new GNAT.Dynamic_HTables.Simple_HTable
     (Header_Num => Header_Num,
      Element    => Global_Reference,
      No_Element => No_Global_Reference,
      Key        => Reference_Name,
      Hash       => Hash,
      Equal      => "=");

   function Get_NFA
     (Grammar : XML_Grammar) return Schema_State_Machines.NFA_Access;
   function Get_References
     (Grammar : XML_Grammar) return access Reference_HTables.Instance;
   --  Returns the state machine and global references used to validate
   --  [Grammar]

   ---------------
   -- ID_Htable --
   ---------------

   type Id_Htable_Access is private;

   procedure Free (Id_Table : in out Id_Htable_Access);

   ------------
   -- Parser --
   ------------
   --  See packages Schema.Readers and Schema.Schema_Readers for non-abstract
   --  implementation of those.

   type Abstract_Validation_Reader
     is abstract new Sax.Readers.Sax_Reader
   with record
      Error_Location : Sax.Locators.Location;
      Error_Msg      : Unicode.CES.Byte_Sequence_Access;

      Id_Table  : Id_Htable_Access;
      --  Mapping of IDs to elements

      Grammar   : XML_Grammar := No_Grammar;

      All_NNI                : Sax.Symbols.Symbol; --  "allNNI"
      Annotated              : Sax.Symbols.Symbol; --  "annotated"
      Annotation             : Sax.Symbols.Symbol; --  "annotation"
      Any                    : Sax.Symbols.Symbol; --  "any"
      Any_Attribute          : Sax.Symbols.Symbol; --  "anyAttribute"
      Any_Namespace          : Sax.Symbols.Symbol;  --  "##any"
      Any_Simple_Type        : Sax.Symbols.Symbol; --  "anySimpleType"
      Anytype                : Sax.Symbols.Symbol;  --  "anyType"
      Appinfo                : Sax.Symbols.Symbol; --  "appinfo"
      Attr_Decls             : Sax.Symbols.Symbol; --  "attrDecls"
      Attribute              : Sax.Symbols.Symbol; --  "attribute"
      Attribute_Group        : Sax.Symbols.Symbol; --  "attributeGroup"
      Attribute_Group_Ref    : Sax.Symbols.Symbol; -- "attributeGroupRef"
      Base                   : Sax.Symbols.Symbol; --  "base"
      Block                  : Sax.Symbols.Symbol; --  "block"
      Block_Default          : Sax.Symbols.Symbol; --  "blockDefault"
      Block_Set              : Sax.Symbols.Symbol; --  "blockSet"
      Choice                 : Sax.Symbols.Symbol; --  "choice"
      Complex_Content        : Sax.Symbols.Symbol; --  "complexContent"
      Complex_Extension_Type : Sax.Symbols.Symbol; --  "complexExtensionType"
      Complex_Restriction_Type : Sax.Symbols.Symbol;
      Complex_Type           : Sax.Symbols.Symbol; --  "complexType"
      Complex_Type_Model     : Sax.Symbols.Symbol; -- "complexTypeModel"
      Def_Ref                : Sax.Symbols.Symbol; --  "defRef"
      Default                : Sax.Symbols.Symbol; --  "default"
      Derivation_Control     : Sax.Symbols.Symbol; -- "derivationControl"
      Derivation_Set         : Sax.Symbols.Symbol; --  "derivationSet"
      Documentation          : Sax.Symbols.Symbol; --  "documentation"
      Element                : Sax.Symbols.Symbol; --  "element"
      Enumeration            : Sax.Symbols.Symbol;  --  "enumeration"
      Explicit_Group         : Sax.Symbols.Symbol; --  "explicitGroup"
      Extension              : Sax.Symbols.Symbol; --  "extension"
      Extension_Type         : Sax.Symbols.Symbol; --  "extensionType"
      Facet                  : Sax.Symbols.Symbol; --  "facet"
      Field                  : Sax.Symbols.Symbol; -- "field"
      Final                  : Sax.Symbols.Symbol; --  "final"
      Final_Default          : Sax.Symbols.Symbol; --  "finalDefault"
      Fixed                  : Sax.Symbols.Symbol; --  "fixed"
      Form                   : Sax.Symbols.Symbol; --  "form"
      Form_Choice            : Sax.Symbols.Symbol; -- "formChoice
      Fraction_Digits        : Sax.Symbols.Symbol;
      Group                  : Sax.Symbols.Symbol; --  "group"
      Group_Def_Particle     : Sax.Symbols.Symbol; --  "groupDefParticle"
      Group_Ref              : Sax.Symbols.Symbol; --  "groupRef"
      Id                     : Sax.Symbols.Symbol; --  "id"
      Identity_Constraint    : Sax.Symbols.Symbol; --  "identityConstraint"
      Import                 : Sax.Symbols.Symbol; --  "import"
      Include                : Sax.Symbols.Symbol; --  "include"
      Item_Type              : Sax.Symbols.Symbol; --  "itemType"
      Key                    : Sax.Symbols.Symbol; --  "key"
      Keybase                : Sax.Symbols.Symbol; --  "keybase"
      Keyref                 : Sax.Symbols.Symbol; --  "keyref"
      Lang                   : Sax.Symbols.Symbol; --  "lang"
      Lax                    : Sax.Symbols.Symbol; --  "lax"
      Length                 : Sax.Symbols.Symbol;
      List                   : Sax.Symbols.Symbol; --  "list"
      Local                  : Sax.Symbols.Symbol;
      Local_Complex_Type     : Sax.Symbols.Symbol; --  "localComplexType"
      Local_Element          : Sax.Symbols.Symbol; --  "localElement"
      Local_Simple_Type      : Sax.Symbols.Symbol; --  "localSimpleType"
      MaxExclusive           : Sax.Symbols.Symbol;
      MaxInclusive           : Sax.Symbols.Symbol;
      MaxOccurs              : Sax.Symbols.Symbol;
      Max_Bound              : Sax.Symbols.Symbol; --  "maxBound"
      Maxlength              : Sax.Symbols.Symbol;  --  "maxLength"
      Member_Types           : Sax.Symbols.Symbol; --  "memberTypes"
      MinExclusive           : Sax.Symbols.Symbol;
      MinInclusive           : Sax.Symbols.Symbol;
      MinOccurs              : Sax.Symbols.Symbol;
      Min_Bound              : Sax.Symbols.Symbol; --  "minBound"
      Minlength              : Sax.Symbols.Symbol;  --  "minLength"
      Mixed                  : Sax.Symbols.Symbol; --  "mixed"
      NCName                 : Sax.Symbols.Symbol; --  "NCName"
      NMTOKEN                : Sax.Symbols.Symbol; --  "NMTOKEN"
      Name                   : Sax.Symbols.Symbol;
      Named_Attribute_Group  : Sax.Symbols.Symbol; --  "namedAttributeGroup"
      Named_Group            : Sax.Symbols.Symbol; --  "namedGroup"
      Namespace              : Sax.Symbols.Symbol;
      Namespace_List         : Sax.Symbols.Symbol; --  "namespaceList"
      Namespace_Target       : Sax.Symbols.Symbol; --  "targetNamespace"
      Nested_Particle        : Sax.Symbols.Symbol; --  "nestedParticle"
      Nil                    : Sax.Symbols.Symbol;
      Nillable               : Sax.Symbols.Symbol; --  "nillable"
      No_Namespace_Schema_Location : Sax.Symbols.Symbol;
      Non_Negative_Integer   : Sax.Symbols.Symbol; --  "nonNegativeInteger"
      Notation               : Sax.Symbols.Symbol; -- "notation"
      Num_Facet              : Sax.Symbols.Symbol; --  "numFacet"
      Occurs                 : Sax.Symbols.Symbol; -- "occurs"
      Open_Attrs             : Sax.Symbols.Symbol; --  "openAttrs"
      Optional               : Sax.Symbols.Symbol; --  "optional"
      Other_Namespace        : Sax.Symbols.Symbol;
      Particle               : Sax.Symbols.Symbol; --  "particle"
      Pattern                : Sax.Symbols.Symbol;
      Positive_Integer       : Sax.Symbols.Symbol;
      Precision_Decimal      : Sax.Symbols.Symbol;
      Process_Contents       : Sax.Symbols.Symbol; --  "processContents"
      Prohibited             : Sax.Symbols.Symbol; --  "prohibited"
      Public                 : Sax.Symbols.Symbol; --  "public"
      QName                  : Sax.Symbols.Symbol; --  "QName"
      Qualified              : Sax.Symbols.Symbol; --  "qualified"
      Real_Group             : Sax.Symbols.Symbol; -- "realGroup"
      Redefinable            : Sax.Symbols.Symbol; --  "redefinable"
      Redefine               : Sax.Symbols.Symbol; --  "redefine"
      Reduced_Derivation_Control : Sax.Symbols.Symbol;
      Ref                    : Sax.Symbols.Symbol;
      Refer                  : Sax.Symbols.Symbol; --  "refer"
      Required               : Sax.Symbols.Symbol; --  "required"
      Restriction            : Sax.Symbols.Symbol; --  "restriction"
      Restriction_Type       : Sax.Symbols.Symbol; --  "restrictionType"
      S_1                    : Sax.Symbols.Symbol; --  "1"
      S_Abstract             : Sax.Symbols.Symbol; --  "abstract"
      S_All                  : Sax.Symbols.Symbol; --  "all"
      S_Attribute_Form_Default : Sax.Symbols.Symbol; --  "attributeFormDefault"
      S_Boolean              : Sax.Symbols.Symbol; --  "boolean"
      S_Element_Form_Default : Sax.Symbols.Symbol; --  "elementFormDefault"
      S_False                : Sax.Symbols.Symbol; --  "false"
      S_Schema               : Sax.Symbols.Symbol; --  "schema"
      S_String               : Sax.Symbols.Symbol; --  "string"
      S_Use                  : Sax.Symbols.Symbol; --  "use"
      Schema_Location        : Sax.Symbols.Symbol;
      Schema_Top             : Sax.Symbols.Symbol; --  "schemaTop"
      Selector               : Sax.Symbols.Symbol; --  "selector"
      Sequence               : Sax.Symbols.Symbol; --  "sequence"
      Simple_Content         : Sax.Symbols.Symbol; --  "simpleContent"
      Simple_Derivation      : Sax.Symbols.Symbol; --  "simpleDerivation"
      Simple_Derivation_Set  : Sax.Symbols.Symbol; --  "simpleDerivationSet"
      Simple_Extension_Type  : Sax.Symbols.Symbol; --  "simpleExtensionType"
      Simple_Restriction_Model : Sax.Symbols.Symbol;
      Simple_Restriction_Type  : Sax.Symbols.Symbol;
      Simple_Type            : Sax.Symbols.Symbol; --  "simpleType"
      Source                 : Sax.Symbols.Symbol; --  "source"
      Strict                 : Sax.Symbols.Symbol; --  "strict"
      Substitution_Group     : Sax.Symbols.Symbol; --  "substitutionGroup"
      System                 : Sax.Symbols.Symbol; --  "system"
      Target_Namespace       : Sax.Symbols.Symbol; --  "##targetNamespace"
      Token                  : Sax.Symbols.Symbol; --  "token"
      Top_Level_Attribute    : Sax.Symbols.Symbol; --  "topLevelAttribute"
      Top_Level_Complex_Type : Sax.Symbols.Symbol; --  "topLevelComplexType"
      Top_Level_Element      : Sax.Symbols.Symbol; --  "topLevelElement"
      Top_Level_Simple_Type  : Sax.Symbols.Symbol; --  "topLevelSimpleType"
      Total_Digits           : Sax.Symbols.Symbol;
      Typ                    : Sax.Symbols.Symbol;
      Type_Def_Particle      : Sax.Symbols.Symbol; --  "typeDefParticle"
      UC_ID                  : Sax.Symbols.Symbol; --  "ID"
      URI_Reference          : Sax.Symbols.Symbol; --  "uriReference"
      Unbounded              : Sax.Symbols.Symbol;
      Union                  : Sax.Symbols.Symbol; --  "union"
      Unique                 : Sax.Symbols.Symbol; -- "unique"
      Unqualified            : Sax.Symbols.Symbol; --  "unqualified"
      Ur_Type                : Sax.Symbols.Symbol; --  "ur-Type"
      Value                  : Sax.Symbols.Symbol; --  "value"
      Version                : Sax.Symbols.Symbol; --  "version"
      Whitespace             : Sax.Symbols.Symbol;
      Wildcard               : Sax.Symbols.Symbol; --  "wildcard"
      XML_Instance_URI       : Sax.Symbols.Symbol;
      XML_Schema_URI         : Sax.Symbols.Symbol;
      XML_URI                : Sax.Symbols.Symbol; --  XML_URI
      XPath                  : Sax.Symbols.Symbol; --  "xpath"
      XPath_Expr_Approx      : Sax.Symbols.Symbol; --  "XPathExprApprox"
      XPath_Spec             : Sax.Symbols.Symbol; --  "XPathSpec"
      Xmlns                  : Sax.Symbols.Symbol := Sax.Symbols.No_Symbol;
   end record;
   type Abstract_Validating_Reader_Access
     is access all Abstract_Validation_Reader'Class;

   overriding procedure Initialize_Symbols
     (Parser : in out Abstract_Validation_Reader);
   --  See inherited documentation

   procedure Validation_Error
     (Reader  : access Abstract_Validation_Reader;
      Message : Unicode.CES.Byte_Sequence;
      Loc     : Sax.Locators.Location := Sax.Locators.No_Location;
      Except  : Ada.Exceptions.Exception_Id := XML_Validation_Error'Identity);
   --  Sets an error message, and raise XML_Validation_Error.
   --  The message can contain special characters like:
   --    '#': if first character, it will be replaced by the current location
   --         of the Reader

   function Get_Locator
     (Reader : Abstract_Validation_Reader) return Sax.Locators.Locator
     is abstract;
   --  Return the current location in the file

   function Get_Error_Message
     (Reader : Abstract_Validation_Reader) return Unicode.CES.Byte_Sequence;
   --  Return the current error message

   procedure Free (Reader : in out Abstract_Validation_Reader);
   --  Free the contents of Reader

   ------------
   -- Facets --
   ------------

   type Facets_Description_Record is abstract tagged null record;
   type Facets_Description is access all Facets_Description_Record'Class;

   type Facets_Names is (Facet_Whitespace,
                         Facet_Pattern,
                         Facet_Enumeration,
                         Facet_Implicit_Enumeration,
                         Facet_Length,
                         Facet_Min_Length,
                         Facet_Max_Length,
                         Facet_Total_Digits,
                         Facet_Fraction_Digits,
                         Facet_Max_Inclusive,
                         Facet_Min_Inclusive,
                         Facet_Max_Exclusive,
                         Facet_Min_Exclusive);
   type Facets_Mask is array (Facets_Names) of Boolean;
   pragma Pack (Facets_Mask);
   --  The list of all possible facets. Not all facets_description will support
   --  these, however.

   procedure Add_Facet
     (Facets      : in out Facets_Description_Record;
      Reader      : access Abstract_Validation_Reader'Class;
      Facet_Name  : Sax.Symbols.Symbol;
      Facet_Value : Unicode.CES.Byte_Sequence;
      Applied     : out Boolean) is abstract;
   --  Set the value of a facet.
   --  Applied is set to True if the facet was valid for Facets

   procedure Check_Facet
     (Facets : in out Facets_Description_Record;
      Reader : access Abstract_Validation_Reader'Class;
      Value  : Unicode.CES.Byte_Sequence;
      Mask   : in out Facets_Mask) is abstract;
   --  Check whether Value matches Facets. Raises XML_Validator_Error otherwise
   --  Mask indicates which facets should be check (when set to True). On exit,
   --  the facets that have been checked have been set to False

   procedure Copy
     (From : Facets_Description_Record;
      To   : in out Facets_Description_Record'Class) is abstract;
   --  Copy all the facets defined in From into To

   procedure Free (Facets : in out Facets_Description_Record) is abstract;
   procedure Free (Facets : in out Facets_Description);
   --  Free the facets;

   -----------
   -- Types --
   -----------

   type XML_Type is private;
   No_Type : constant XML_Type;
   --  A type, which can either be named (ie it has been explicitely declared
   --  with a name and stored in the grammar), or anonymous.

   function Get_Validator (Typ : XML_Type) return XML_Validator;
   --  Return the validator used for that type

--     function List_Of
--       (Grammar : XML_Grammar_NS; Typ : XML_Type) return XML_Type;
   --  Return a new type validator that checks for a list of values valid for
   --  Validator.

   function Is_ID (Typ : XML_Type) return Boolean;
   --  Whether Typ is an ID, ie the values of its attributes must be unique
   --  throughout the document

   function Is_ID (Validator : XML_Validator_Record) return Boolean;
   --  Whether the validator is associated with an ID type

   function Extension_Of
     (G         : XML_Grammar_NS;
      Base      : XML_Type;
      Extension : XML_Validator := null) return XML_Validator;
   --  Create an extension of Base.
   --  Base doesn't need to be a Clone of some other type, since it isn't
   --  altered. See also Is_Extension_Of below

   function Is_Extension_Of
     (Validator : XML_Validator_Record;
      Base      : access XML_Validator_Record'Class) return Boolean;
   function Is_Restriction_Of
     (Validator : XML_Validator_Record;
      Base      : access XML_Validator_Record'Class) return Boolean;
   --  Whether Validator is an extension/restriction of Base

   function Restriction_Of
     (G           : XML_Grammar_NS;
      Reader      : access Abstract_Validation_Reader'Class;
      Base        : XML_Type;
      Restriction : XML_Validator := null) return XML_Validator;
   --  Create a restriction of Base
   --  Base doesn't need to be a Clone of some other type, since it isn't
   --  altered. See also Is_Restriction_Of below

--     procedure Check_Content_Type
--       (Typ              : XML_Type;
--        Reader           : access Abstract_Validation_Reader'Class;
--        Should_Be_Simple : Boolean);
   --  Check whether Typ is a simpleType or a complexType. See the description
   --  of the homonym for validators.
   --  When in doubt, use this one instead of the one for validators, since
   --  this one properly handles No_Type and types whose definition has not yet
   --  been parsed in the Schema.

--     function Is_Simple_Type
--       (Reader : access Abstract_Validation_Reader'Class;
--        Typ    : XML_Type) return Boolean;
   --  Whether Typ is a simple type

   procedure Set_Block (Typ    : XML_Type; Blocks : Block_Status);
   function Get_Block (Typ : XML_Type) return Block_Status;
   --  Set the "block" status of the type.
   --  This can also be done at the element's level

--     procedure Set_Final (Typ : XML_Type; Final : Final_Status);
   function Get_Final (Typ : XML_Type) return Final_Status;
   --  Set the final status of the element

   procedure Normalize_Whitespace
     (Typ    : XML_Type;
      Reader : access Abstract_Validation_Reader'Class;
      Atts   : Sax.Readers.Sax_Attribute_List;
      Index  : Natural);
   --  Normalizes whitespaces in the attribute, depending on the type
   --  represented by Validator.

   function Do_Normalize_Whitespaces
     (Typ     : XML_Type;
      Reader  : access Abstract_Validation_Reader'Class;
      Val     : Sax.Symbols.Symbol) return Sax.Symbols.Symbol;
   --  Normalize whitespaces in Val.

   -------------------------
   -- Attribute_Validator --
   -------------------------

   type Namespace_Kind is (Namespace_Other, Namespace_Any, Namespace_List);
   --  "Any":   any non-conflicting namespace
   --  "Other": any non-conflicting namespace other than targetNamespace
   --  Namespace_List can contain "##local", "##targetNamespace" or actual
   --  namespaces.

   type NS_List is array (Natural range <>) of Sax.Symbols.Symbol;
   Empty_NS_List : constant NS_List;

   function Create_Any_Attribute
     (In_NS  : XML_Grammar_NS;
      Process_Contents : Process_Contents_Type := Process_Strict;
      Kind   : Namespace_Kind;
      List   : NS_List := Empty_NS_List) return Attribute_Descr;
   --  Equivalent of <anyAttribute> in an XML schema.
   --  List is irrelevant if Kind /= Namespace_List. It is adopted by the
   --  attribute, and should not be freed by the caller

   ---------------------
   -- Type validators --
   ---------------------
   --  Such validators are build to validate specific parts of an XML
   --  document (a whole element).

   procedure Free (Validator : in out XML_Validator_Record) is null;
   --  Free the memory occupied by Validator

   procedure Validate_Attributes
     (Grammar   : XML_Grammar;
      Attributes : Attribute_Validator_List;
      Reader    : access Abstract_Validation_Reader'Class;
      Atts      : in out Sax.Readers.Sax_Attribute_List;
      Nillable  : Boolean;
      Is_Nil    : out Boolean);
   --  Check whether this list of attributes is valid for elements associated
   --  with this validator. By default, this simply check whether the list of
   --  attributes registered through Add_Attribute matches Atts.
   --
   --  Id_Table is used to ensure that two same Ids are not in the document. It
   --  is passed as an access type, so that in case of exception it is still
   --  properly set on exit.
   --
   --  Nillable indicates whether the xsi:nil attribute should be supported,
   --  even if not explicitely inserted in the list. Is_Nil is set to the value
   --  of this attribute.
   --
   --  Sets the type of the attributes (through Sax.Attributes.Set_Type) to Id
   --  if the corresponding attribute is an id.

   procedure Validate_Characters
     (Validator     : access XML_Validator_Record;
      Reader        : access Abstract_Validation_Reader'Class;
      Ch            : Unicode.CES.Byte_Sequence;
      Empty_Element : Boolean;
      Mask          : in out Facets_Mask);
   --  Check whether this Characters event is valid in the context of
   --  Validator. Multiple calls to the SAX event Characters are grouped before
   --  calling this subprogram.
   --  If Empty_Element is true, this indicates that the element is in fact
   --  empty. This is to distinguish from the empty string:
   --      <tag/>   and <tag></tag>
   --  If Empty_Element is true, then Ch is irrelevant

   function Equal
     (Validator      : access XML_Validator_Record;
      Reader         : access Abstract_Validation_Reader'Class;
      Value1, Value2 : Unicode.CES.Byte_Sequence) return Boolean;
   --  Return True if Value1 = Value2, interpreted from the type. For instance,
   --  an decimal "1.0" is the same as "1.00".

   function Get_Facets
     (Validator : access XML_Validator_Record;
      Reader    : access Abstract_Validation_Reader'Class)
      return Facets_Description;
   --  Return the facets of the validator, or null if there are no facets

   procedure Add_Facet
     (Validator   : access XML_Validator_Record;
      Reader      : access Abstract_Validation_Reader'Class;
      Facet_Name  : Sax.Symbols.Symbol;
      Facet_Value : Unicode.CES.Byte_Sequence);
   --  Add a restriction to the set of possible values for Validator.
   --  The valid list of restrictions and their values depends on the type
   --  of Validator.
   --  By default, an error is reported through Invalid_Restriction

   procedure Add_Attribute
     (Grammar   : XML_Grammar;
      List      : in out Attribute_Validator_List;
      Attribute : Attribute_Descr);
   procedure Add_Attributes
     (Grammar    : XML_Grammar;
      List       : in out Attribute_Validator_List;
      Attributes : Attribute_Validator_List);
   --  Add a valid attribute to Validator.
   --  Is_Local should be true if the attribute is local, or False if this is
   --  a reference to a global attribute.
   --  The second version copies elements from [Attributes] into [List].

   function Is_Wildcard
     (Validator : access XML_Validator_Record) return Boolean;
   --  Whether Validator is a wildcard

   procedure Set_Mixed_Content
     (Validator : access XML_Validator_Record;
      Mixed     : Boolean);
   function Get_Mixed_Content
     (Validator : access XML_Validator_Record) return Boolean;
   --  Whether character data is allowed within that element, in addition to
   --  children nodes

--     procedure Check_Content_Type
--       (Validator        : access XML_Validator_Record;
--        Reader           : access Abstract_Validation_Reader'Class;
--        Should_Be_Simple : Boolean);
   --  Check whether Validator describes a simple Type (or a complex Type with
   --  simpleContent), if Should_Be_Simple is true, or the opposite otherwise.
   --  Raises XML_Validator_Error in case of error.

   ------------
   -- Unions --
   ------------

   function Create_Union (G : XML_Grammar_NS) return XML_Validator;
   --  Create a new empty union

   procedure Add_Union
     (Validator : access XML_Validator_Record'Class;
      Reader    : access Abstract_Validation_Reader'Class;
      Part      : Type_Descr);
   --  Add a new element to the union in Validator

   --------------
   -- Elements --
   --------------

--     procedure Set_Substitution_Group
--       (Element : XML_Element;
--        Reader  : access Abstract_Validation_Reader'Class;
--        Head    : XML_Element);
   --  Define a substitution group for Validator, as declared through the
   --  "substitutionGroup" attribute of the XML Schema.
   --  Anywhere Head is referenced, Validator can be used
   --  instead.

--     function Is_Extension_Of
--       (Element : XML_Element; Base : XML_Element) return Boolean;
--     function Is_Restriction_Of
--       (Element : XML_Element; Base : XML_Element) return Boolean;
   --  Whether Element is an extension/restriction of Base

--     procedure Set_Default
--       (Element  : XML_Element;
--        Reader   : access Abstract_Validation_Reader'Class;
--        Default  : Sax.Symbols.Symbol);
   --  Manipulation of the "default" attribute.
   --  The value returned by Get_Default mustn't be altered or freed, and
   --  will be null if the attribute wasn't set. We return a pointer for
   --  efficiency only

--     procedure Set_Fixed
--       (Element  : XML_Element;
--        Reader   : access Abstract_Validation_Reader'Class;
--        Fixed    : Sax.Symbols.Symbol);
   --  Manipulation of the "fixed" attribute
   --  The value returned by Get_Fixed mustn't be altered or freed, and
   --  will be null if the attribute wasn't set. We return a pointer for
   --  efficiency only

--     procedure Check_Qualification
--       (Reader        : access Abstract_Validation_Reader'Class;
--        Element       : XML_Element;
--        NS            : XML_Grammar_NS);
   --  Check whether the element should have been qualified or not,
   --  depending on its "form" attribute.
   --  Namespace_URI is the namespace as read in the file.

--     function Is_Global (Element : XML_Element) return Boolean;
   --  Whether Element is a global element (ie declared at the top-level of
   --  the schema file), as opposed to a local element declared inside a
   --  global element:
   --     <schema>
   --       <element name="global">
   --         <sequence>
   --           <element name="local" />

--     function Get_QName (Element : XML_Element) return Qualified_Name;
   --  Return the qualified name for Element

   --------------
   -- Grammars --
   --------------

   procedure Get_NS
     (Grammar       : XML_Grammar;
      Namespace_URI : Sax.Symbols.Symbol;
      Result        : out XML_Grammar_NS;
      Create_If_Needed : Boolean := True);
   --  Return the part of the grammar specialized for a given namespace.
   --  If no such namespace exists yet in the grammar, it is created.

   procedure Set_Target_NS (Grammar : XML_Grammar; NS : XML_Grammar_NS);
   function Get_Target_NS (Grammar : XML_Grammar) return XML_Grammar_NS;
   --  Set the target namespace for the grammar. This is the "targetNamespace"
   --  attribute of the <schema> node.

   procedure Create_Global_Type
     (Grammar    : XML_Grammar;
      Name       : Qualified_Name;
      Validator  : access XML_Validator_Record'Class);
   --  Same as above, but doesn't return the newly created type. Use Lookup if
   --  you need access to it later on

   procedure Set_Block_Default
     (Grammar : XML_Grammar_NS; Blocks  : Block_Status);
   function Get_Block_Default (Grammar : XML_Grammar_NS) return Block_Status;
   --  Set the default value for the "block" attribute

   procedure Initialize_Grammar
     (Reader : access Abstract_Validation_Reader'Class);
   --  Initialize the internal structure of the grammar.
   --  This adds the definition for all predefined types

   procedure Reset (Grammar : in out XML_Grammar);
   --  Partial reset of the grammar: all the namespace-specific grammars are
   --  deleted, except for the grammar used to validate the XSD files
   --  themselves. This is mostly convenient if you want to reuse a grammar
   --  to handle _lots_ of unrelated XSD files (if your application only uses
   --  a few of these, you can easily store them all in the same grammar, but
   --  if you have hundreds of them, it might be more memory-efficient to
   --  discard the namespaces you no longer use).
   --  Keeping the grammar for the XSD files provides a minor optimization,
   --  avoiding the need to recreate it the next time you parse a XSD file.

   function Get_Namespace_URI
     (Grammar : XML_Grammar_NS) return Sax.Symbols.Symbol;
   --  Return the namespace URI associated with Grammar

   function URI_Was_Parsed
     (Grammar : XML_Grammar;
      URI     : Sax.Symbols.Symbol) return Boolean;
   --  Return True if the schema at URI was already parsed and included in
   --  Grammar. URI must be an absolute URI.

   procedure Set_Parsed_URI
     (Reader  : access Abstract_Validation_Reader'Class;
      Grammar : in out XML_Grammar;
      URI     : Sax.Symbols.Symbol);
   --  Indicate that the schema found at URI was fully parsed and integrated
   --  into Grammar. It can then be tested through URI_Was_Parsed.

   procedure Debug_Dump (Grammar : XML_Grammar);
   --  Dump the grammar to stdout. This is for debug only

   function To_QName (Name : Qualified_Name) return Unicode.CES.Byte_Sequence;
   function To_QName (NS : XML_Grammar_NS; Local : Sax.Symbols.Symbol)
      return Unicode.CES.Byte_Sequence;
   --  Return the name as it should be displayed in error messages

private

   ---------
   -- Ids --
   ---------

   type Id_Ref is record
      Key : Sax.Symbols.Symbol;
   end record;
   No_Id : constant Id_Ref := (Key => Sax.Symbols.No_Symbol);

   procedure Free (Id : in out Id_Ref);
   function Get_Key (Id : Id_Ref) return Sax.Symbols.Symbol;
   package Id_Htable is new Sax.HTable
     (Element       => Id_Ref,
      Empty_Element => No_Id,
      Free          => Free,
      Key           => Sax.Symbols.Symbol,
      Get_Key       => Get_Key,
      Hash          => Sax.Symbols.Hash,
      Equal         => Sax.Symbols."=");
   type Id_Htable_Access is access Id_Htable.HTable;
   --  This table is used to store the list of IDs that have been used in the
   --  document so far, and prevent their duplication in the document.

   --------------
   -- XML_Type --
   --------------

   type Content_Type is (Simple_Content, Complex_Content, Unknown_Content);

   type XML_Type_Record is record
      Local_Name  : Sax.Symbols.Symbol;
      Validator   : XML_Validator;
      Simple_Type : Content_Type;

      Blocks : Block_Status;
      --  The value for the "block" attribute of the type

      Final : Final_Status;
      --  Whether this element is final for "restriction" or "extension" or
      --  both

      Next : XML_Type;
      --  Next type in the list of allocated types for this grammar.
      --  This list is used for proper memory management, and ensures that all
      --  types are properly freed on exit.
   end record;
   type XML_Type is access all XML_Type_Record;
   No_Type : constant XML_Type := null;

   -------------------------
   -- Attribute_Validator --
   -------------------------

   function Is_ID (Attr : Attribute_Descr) return Boolean;
   --  Whether the attribute is an ID

   package Attributes_Tables is new GNAT.Dynamic_Tables
     (Table_Component_Type => Attribute_Descr,
      Table_Index_Type     => Attribute_Validator_List,
      Table_Low_Bound      => Empty_Attribute_List + 1,
      Table_Initial        => 200,
      Table_Increment      => 200);

   procedure Validate_Attribute
     (Attr      : Attribute_Descr;
      Reader    : access Abstract_Validation_Reader'Class;
      Atts      : in out Sax.Readers.Sax_Attribute_List;
      Index     : Natural);

   Empty_NS_List : constant NS_List := (1 .. 0 => Sax.Symbols.No_Symbol);

--     type Any_Attribute_Validator (NS_Count : Natural) is
--       new Attribute_Validator_Record
--     with record
--        Process_Contents : Process_Contents_Type;
--        Kind             : Namespace_Kind;
--        List             : NS_List (1 .. NS_Count);
--     end record;
--     function Equal
--       (Validator      : Any_Attribute_Validator;
--        Reader         : access Abstract_Validation_Reader'Class;
--        Value1, Value2 : Unicode.CES.Byte_Sequence) return Boolean;
--     procedure Validate_Attribute
--       (Validator : Any_Attribute_Validator;
--        Reader    : access Abstract_Validation_Reader'Class;
--        Atts      : in out Sax.Readers.Sax_Attribute_List;
--        Index     : Natural);
--     function Is_Equal
--       (Attribute : Any_Attribute_Validator;
--        Attr2     : Attribute_Validator_Record'Class)
--       return Boolean;

   --------------
   -- Grammars --
   --------------

   type Grammar_NS_Array is array (Natural range <>) of XML_Grammar_NS;
   type Grammar_NS_Array_Access is access all Grammar_NS_Array;

   type String_List_Record;
   type String_List is access String_List_Record;
   type String_List_Record is record
      Str  : Sax.Symbols.Symbol;
      Next : String_List;
   end record;
   --  We will use Ada2005 containers when the compiler is more widely
   --  available

   procedure Free (List : in out String_List);
   --  Free the list and its contents

   type XML_Grammar_Record is new Sax.Pointers.Root_Encapsulated with record
      Symbols  : Sax.Utils.Symbol_Table;

      Grammars : Grammar_NS_Array_Access;
      --  All the namespaces known for that grammar

      Parsed_Locations : String_List;
      --  List of schema locations that have already been parsed. This is used
      --  in particular to handle cases where a schema imports two others
      --  schemas, that in turn import a common one.

      XSD_Version : XSD_Versions := XSD_1_0;

      References : aliased Reference_HTables.Instance;
      Attributes : Attributes_Tables.Instance;
      NFA : Schema_State_Machines.NFA_Access;
      --  The state machine representing the grammar
      --  This includes the states for all namespaces

      Target_NS : XML_Grammar_NS;
   end record;

   procedure Free (Grammar : in out XML_Grammar_Record);
   --  Free the memory occupied by the grammar

   package XML_Grammars is new Sax.Pointers.Smart_Pointers
     (XML_Grammar_Record);
   type XML_Grammar is new XML_Grammars.Pointer;
   No_Grammar : constant XML_Grammar :=
     XML_Grammar (XML_Grammars.Null_Pointer);

   -------------------
   -- XML_Validator --
   -------------------

   type XML_Validator_Record is tagged record
      Attributes : Attribute_Validator_List;
      --  The list of valid attributes registered for this validator.
      --  ??? Could be implemented more efficiently through a htable

      Mixed_Content : Boolean := False;
      --  Whether character data is allowed in addition to children nodes

      Next : XML_Validator;
      --  Next validator in the list of allocated validators for this grammar.
      --  This list is used for proper memory management, and ensures that all
      --  validators are properly freed on exit.
      --  This is not null when validator was already registered in one of the
      --  grammars, and should not be registered again
   end record;

   -------------
   -- Grammar --
   -------------

   type XML_Grammar_NS_Record is record
      Namespace_URI : Sax.Symbols.Symbol;
      System_ID     : Sax.Symbols.Symbol;
      Blocks        : Block_Status := No_Block;
   end record;

   procedure Free (Grammar : in out XML_Grammar_NS);
   --  Free the memory occupied by Grammar

   function Get_Name
     (Validator : access XML_Validator_Record'Class) return String;
   --  Return a string "(rule "name")" if the name of the validator is defined.
   --  This is for debug purposes only

   procedure Check_Id
     (Reader    : access Abstract_Validation_Reader'Class;
      Validator : access XML_Validator_Record'Class;
      Value     : Unicode.CES.Byte_Sequence);
   --  Check whether Value is a unique ID in the document.
   --  If yes, store it in Id_Table to ensure its future uniqueness.
   --  This does nothing if Validator is not associated with an ID type.

end Schema.Validators;
