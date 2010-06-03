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

with Schema.Validators;              use Schema.Validators;
with Schema.Validators.Simple_Types; use Schema.Validators.Simple_Types;
with Schema.Validators.UR_Type;      use Schema.Validators.UR_Type;

package body Schema.Validators.XSD_Grammar is

   procedure Add_Schema_For_Schema
     (R : access Schema.Validators.Abstract_Validation_Reader'Class)
   is
      G, XML_G      : XML_Grammar_NS;
      Tmp2          : XML_Validator;
      Typ, Typ2     : XML_Validator;
      Seq1, Seq2    : Sequence;
      Choice1       : Choice;
      All_Validator : XML_Type;
      Elem          : XML_Element;
      Gr            : XML_Group;
      Union, Union2 : XML_Validator;

      Annotation, Any          : XML_Element;
      Openattrs                : XML_Type;
      reducedDerivationControl : XML_Type;
      derivationControl        : XML_Type;
      NMTOKEN, NCNAME, QNAME   : XML_Type;
      Bool, nonNegativeInteger : XML_Type;
      uriReference             : XML_Type;
      Str                      : XML_Type;
      numFacet                 : XML_Type;
      Token                    : XML_Type;
      Annotated                : XML_Type;
      localSimpleType          : XML_Type;
      localComplexType         : XML_Type;
      derivationSet            : XML_Type;
      formChoice               : XML_Type;
      identityConstraint       : XML_Element;
      Facet, SimpleDerivation  : XML_Element;
      Sequence, Choice, All_E  : XML_Element;
      Facet_Type               : XML_Type;
      Redefinable, SchemaTop   : XML_Element;
      maxBound, minBound       : XML_Element;
      attrDecls                : XML_Group;
      typeDefParticle          : XML_Group;
      defRef, Occurs           : XML_Attribute_Group;
      complexTypeModel         : XML_Group;
      groupDefParticle         : XML_Group;
      simpleRestrictionModel   : XML_Group;

   begin
      Get_NS (R.Grammar, R.XML_Schema_URI,   Result => G);
      Get_NS (R.Grammar, R.XML_URI,          Result => XML_G);

      Create_UR_Type_Elements (R, G, R.Grammar);

      --  As per 3.4.7, ur-Type (ie anyType) uses a Lax processing for its
      --  children node (ie uses the grammar definition if one is found)
      Create_Global_Type
        (G, R, R.Ur_Type,
         Get_Validator
           (Get_Type (Get_UR_Type_Element (R.Grammar, Process_Lax))));

      Create_Global_Type
        (G, R, R.Anytype,
         Get_Validator
           (Get_Type (Get_UR_Type_Element (R.Grammar, Process_Lax))));

      Tmp2 := new Any_Simple_XML_Validator_Record;
      Create_Global_Type (G, R, R.Any_Simple_Type, Tmp2);

      Schema.Validators.Simple_Types.Register_Predefined_Types (G, XML_G, R);

      NMTOKEN            := Lookup (G, R, R.NMTOKEN);
      NCNAME             := Lookup (G, R, R.NCName);
      QNAME              := Lookup (G, R, R.QName);
      Str                := Lookup (G, R, R.S_String);
      localSimpleType    := Lookup (G, R, R.Local_Simple_Type);
      Bool               := Lookup (G, R, R.S_Boolean);
      nonNegativeInteger := Lookup (G, R, R.Non_Negative_Integer);
      Annotation  := Create_Global_Element (G, R, R.Annotation,  Qualified);
      Facet       := Create_Global_Element (G, R, R.Facet,       Qualified);
      Sequence    := Create_Global_Element (G, R, R.Sequence,    Qualified);
      Choice      := Create_Global_Element (G, R, R.Choice,      Qualified);
      All_E       := Create_Global_Element (G, R, R.S_All,       Qualified);
      Redefinable := Create_Global_Element (G, R, R.Redefinable, Qualified);
      SchemaTop   := Create_Global_Element (G, R, R.Schema_Top,  Qualified);
      Any         := Create_Global_Element (G, R, R.Any,         Qualified);
      maxBound    := Create_Global_Element (G, R, R.Max_Bound,   Qualified);
      minBound    := Create_Global_Element (G, R, R.Min_Bound,   Qualified);
      SimpleDerivation :=
        Create_Global_Element (G, R, R.Simple_Derivation, Qualified);
      attrDecls        := Create_Global_Group (G, R, R.Attr_Decls);
      complexTypeModel := Create_Global_Group (G, R, R.Complex_Type_Model);
      groupDefParticle := Create_Global_Group (G, R, R.Group_Def_Particle);
      simpleRestrictionModel :=
        Create_Global_Group (G, R, R.Simple_Restriction_Model);
      defRef      := Create_Global_Attribute_Group (G, R, R.Def_Ref);
      Occurs      := Create_Global_Attribute_Group (G, R, R.Occurs);

      --  The "formChoice" type of schema.xsd
      Typ := Restriction_Of (G, R, NMTOKEN);
      Add_Facet (Typ, R, R.Enumeration, "qualified");
      Add_Facet (Typ, R, R.Enumeration, "unqualified");
      formChoice := Create_Global_Type (G, R, R.Form_Choice, Typ);

      --  The "derivationControl" type
      Typ := Restriction_Of (G, R, NMTOKEN);
      Add_Facet (Typ, R, R.Enumeration, "substitution");
      Add_Facet (Typ, R, R.Enumeration, "extension");
      Add_Facet (Typ, R, R.Enumeration, "restriction");
      derivationControl :=
        Create_Global_Type (G, R, R.Derivation_Control, Typ);

      --  The "blockSet" type
      Token := Lookup (G, R, R.Token);
      Typ := Restriction_Of (G, R, Token);
      Add_Facet (Typ, R, R.Enumeration, "#all");
      All_Validator := Create_Local_Type (G, Typ);

      Union := Create_Union (G);
      Add_Union (Union, R, All_Validator);
      Add_Union (Union, R, List_Of (G, derivationControl));
      Create_Global_Type (G, R, R.Block_Set, Union);

      --  The "reducedDerivationControl" type
      Typ := Restriction_Of (G, R, derivationControl);
      Add_Facet (Typ, R, R.Enumeration, "extension");
      Add_Facet (Typ, R, R.Enumeration, "restriction");
      reducedDerivationControl :=
        Create_Global_Type (G, R, R.Reduced_Derivation_Control, Typ);

      --  The "derivationSet" type
      Union := Create_Union (G);
      Add_Union (Union, R, All_Validator);
      Add_Union (Union, R, List_Of (G, reducedDerivationControl));
      derivationSet := Create_Global_Type (G, R, R.Derivation_Set, Union);

      --  The "openAttrs" type
      Typ := Restriction_Of (G, R, Lookup (G, R, R.Anytype));
      Add_Attribute
        (Typ, Create_Any_Attribute (G, Process_Lax, Kind => Namespace_Other));
      Openattrs := Create_Global_Type (G, R, R.Open_Attrs, Typ);

      --  The "annotated" type
      Seq1 := Create_Sequence (G);
      Add_Particle (Seq1, R, Annotation, Min_Occurs => 0);
      Typ := Extension_Of (G, Openattrs, XML_Validator (Seq1));
      Add_Attribute
        (Typ, Create_Local_Attribute (R.Id, G, Lookup (G, R, R.UC_ID)));
      Annotated := Create_Global_Type (G, R, R.Annotated, Typ);

      --  The "schemaTop" element  ??? Missing abstract
      Set_Type (SchemaTop, R, Annotated);

      --  The "include" element
      uriReference := Lookup (G, R, R.URI_Reference);
      Typ := Restriction_Of (G, R, Annotated);
      Add_Attribute
        (Typ, Create_Local_Attribute
           (R.Schema_Location, G, uriReference, Attribute_Use => Required));
      Set_Type (Create_Global_Element (G, R, R.Include, Qualified), R,
                Create_Local_Type (G, Typ));

      --  The "import" element
      Typ := Restriction_Of (G, R, Annotated);
      Add_Attribute
        (Typ, Create_Local_Attribute (R.Namespace, G, uriReference));
      Add_Attribute
        (Typ, Create_Local_Attribute (R.Schema_Location, G, uriReference));
      Set_Type (Create_Global_Element (G, R, R.Import, Qualified), R,
                Create_Local_Type (G, Typ));

      --  The "schema" element
      Choice1 := Create_Choice (G);
      Add_Particle (Choice1, R, Lookup_Element (G, R, R.Include));
      Add_Particle (Choice1, R, Lookup_Element (G, R, R.Import));
      Add_Particle (Choice1, R, Lookup_Element (G, R, R.Redefine));
      Add_Particle (Choice1, R, Annotation);
      Seq1    := Create_Sequence (G);
      Add_Particle (Seq1, R, SchemaTop);
      Add_Particle (Seq1, R, Annotation,
                    Min_Occurs => 0, Max_Occurs => Unbounded);
      Seq2    := Create_Sequence (G);
      Add_Particle
        (Seq2, R, Choice1, Min_Occurs => 0, Max_Occurs => Unbounded);
      Add_Particle
        (Seq2, R, Seq1, Min_Occurs => 0, Max_Occurs => Unbounded);
      Add_Attribute
        (Seq2, Create_Local_Attribute (R.Namespace_Target, G, uriReference));
      Add_Attribute (Seq2, Create_Local_Attribute (R.Version, G, Token));
      Add_Attribute
        (Seq2, Create_Local_Attribute
           (R.Final_Default, G, derivationSet,
            Attribute_Use     => Default));
      Add_Attribute
        (Seq2, Create_Local_Attribute
           (R.Block_Default, G, Lookup (G, R, R.Block_Set),
            Attribute_Use     => Default));
      Add_Attribute
        (Seq2, Create_Local_Attribute
           (R.S_Attribute_Form_Default, G, formChoice,
            Attribute_Use => Default,
            Default       => R.Unqualified));
      Add_Attribute
        (Seq2, Create_Local_Attribute
           (R.S_Element_Form_Default, G, formChoice,
            Attribute_Use => Default,
            Default       => R.Unqualified));
      Add_Attribute
        (Seq2, Create_Local_Attribute (R.Id, G, Lookup (G, R, R.UC_ID)));
      Add_Attribute (Seq2, Lookup_Attribute
                     (XML_G, R, Local_Name => R.Lang));
      Set_Type (Create_Global_Element (G, R, R.S_Schema, Qualified), R,
                Create_Local_Type (G, Seq2));

      --  The "localComplexType" type
      Seq1 := Create_Sequence (G);
      Add_Particle (Seq1, R, Annotation, Min_Occurs => 0);
      Add_Particle (Seq1, R, complexTypeModel);
      Typ := Restriction_Of
        (G, R, Lookup (G, R, R.Complex_Type), XML_Validator (Seq1));
      Add_Attribute
        (Typ, Create_Local_Attribute (R.Name, G, Attribute_Use => Prohibited));
      localComplexType := Create_Global_Type (G, R, R.Local_Complex_Type, Typ);

      --  The "keybase" type
      Seq1 := Create_Sequence (G);
      Add_Particle (Seq1, R, Lookup_Element (G, R, R.Selector));
      Add_Particle (Seq1, R, Lookup_Element (G, R, R.Field),
                    Min_Occurs => 1, Max_Occurs => Unbounded);
      Typ := Extension_Of (G, Annotated, XML_Validator (Seq1));
      Add_Attribute
        (Typ, Create_Local_Attribute (R.Name, G, NCNAME,
                                      Attribute_Use => Required));
      Create_Global_Type (G, R, R.Keybase, Typ);

      --  The "identityConstraint" element  ??? abstract=true
      identityConstraint :=
        Create_Global_Element (G, R, R.Identity_Constraint, Qualified);
      Set_Type (identityConstraint, R, Lookup (G, R, R.Keybase));

      --  The "unique" element
      Elem := Create_Global_Element (G, R, R.Unique, Qualified);
      Set_Type (Elem, R, Get_Type (identityConstraint));
      Set_Substitution_Group (Elem, R, identityConstraint);

      --  The "keyref" element
      Typ := Extension_Of (G, Lookup (G, R, R.Keybase));
      Add_Attribute (Typ, Create_Local_Attribute
                       (R.Refer, G, QNAME, Attribute_Use => Required));
      Elem := Create_Global_Element (G, R, R.Keyref, Qualified);
      Set_Type (Elem, R, Create_Local_Type (G, Typ));
      Set_Substitution_Group (Elem, R, identityConstraint);

      --  The "key" element
      Elem := Create_Global_Element (G, R, R.Key, Qualified);
      Set_Type (Elem, R, Get_Type (identityConstraint));
      Set_Substitution_Group (Elem, R, identityConstraint);

      --  The "XPathExprApprox" type  Incorrect pattern
      Typ := Restriction_Of (G, R, Str);
--    Add_Facet (Typ, "pattern", "(/|//|\.|\.\.|:|::|\||(\w-[.:/|])+)+");
      Create_Global_Type (G, R, R.XPath_Expr_Approx, Typ);

      --  The "XPathSpec" type"
      Typ := Restriction_Of (G, R, Annotated);
      Add_Attribute (Typ, Create_Local_Attribute (R.XPath, G,
        Lookup (G, R, R.XPath_Expr_Approx)));
      Create_Global_Type (G, R, R.XPath_Spec, Typ);

      --  The "selector" element
      Set_Type (Create_Global_Element (G, R, R.Selector, Qualified), R,
                Lookup (G, R, R.XPath_Spec));

      --  The "field" element
      Set_Type (Create_Global_Element (G, R, R.Field, Qualified), R,
                Lookup (G, R, R.XPath_Spec));

      --  The "allNNI" type"
      Union := Create_Union (G);
      Add_Union (Union, R, nonNegativeInteger);
      Typ := Restriction_Of (G, R, NMTOKEN);
      Add_Facet (Typ, R, R.Enumeration, "unbounded");
      Add_Union (Union, R, Create_Local_Type (G, Typ));
      Create_Global_Type (G, R, R.All_NNI, Union);

      --  The "occurs" AttributeGroup
      Add_Attribute
        (Occurs,
         Create_Local_Attribute (R.MinOccurs, G,
           nonNegativeInteger, Attribute_Use => Default, Default => R.S_1));
      Add_Attribute
        (Occurs,
         Create_Local_Attribute (R.MaxOccurs, G,
           Lookup (G, R, R.All_NNI),
           Attribute_Use => Default, Default => R.S_1));

      --  From AttributeGroup "defRef"
      Add_Attribute (defRef, Create_Local_Attribute (R.Name, G, NCNAME));
      Add_Attribute (defRef, Create_Local_Attribute (R.Ref, G, QNAME));

      --  The R.Element type   ??? abstract=true
      Seq1 := Create_Sequence (G);
      Choice1 := Create_Choice (G);
      Add_Particle (Choice1, R, Create_Local_Element
                      (R.Simple_Type, G, localSimpleType, Qualified));
      Add_Particle (Choice1, R, Create_Local_Element
                      (R.Complex_Type, G, localComplexType, Qualified));
      Add_Particle (Seq1, R, Choice1, Min_Occurs => 0);
      Add_Particle (Seq1, R, identityConstraint,
                    Min_Occurs => 0, Max_Occurs => Unbounded);
      Typ := Extension_Of (G, Annotated, XML_Validator (Seq1));
      Create_Global_Type (G, R, R.Element, Typ);
      Add_Attribute_Group (Typ, R, Occurs);
      Add_Attribute_Group (Typ, R, defRef);
      Add_Attribute (Typ, Create_Local_Attribute (R.Typ, G, QNAME));
      Add_Attribute
        (Typ, Create_Local_Attribute (R.Substitution_Group, G, QNAME));
      Add_Attribute (Typ, Create_Local_Attribute (R.Default, G, Str));
      Add_Attribute (Typ, Create_Local_Attribute (R.Fixed, G, Str));
      Add_Attribute
        (Typ, Create_Local_Attribute (R.Nillable, G, Bool,
         Attribute_Use => Default, Default => R.S_False));
      Add_Attribute
        (Typ, Create_Local_Attribute (R.S_Abstract, G, Bool,
         Attribute_Use => Default, Default => R.S_False));
      Add_Attribute
        (Typ,
         Create_Local_Attribute (R.Final, G, derivationSet,
           Attribute_Use => Default));
      Add_Attribute
        (Typ,
         Create_Local_Attribute (R.Block, G, Lookup (G, R, R.Block_Set),
           Attribute_Use => Default));
      Add_Attribute (Typ, Create_Local_Attribute (R.Form, G, formChoice));

      --  The "appinfo" element"
      Seq1 := Create_Sequence (G);
      Seq2 := Create_Sequence (G);
      Add_Particle (Seq1, R, Seq2, Min_Occurs => 0, Max_Occurs => Unbounded);
      Add_Particle
        (Seq2, R,
         Create_Any (Process_Contents => Process_Lax,
                     Namespace        => R.Any_Namespace,
                     Target_NS        => XML_G));
      Add_Attribute
        (Seq1, Create_Local_Attribute (R.Source, G, uriReference));
      Set_Mixed_Content (Seq1, True);
      Set_Type (Create_Global_Element (G, R, R.Appinfo, Qualified), R,
                Create_Local_Type (G, Seq1));

      --  The "documentation" element
      Seq1 := Create_Sequence (G);
      Seq2 := Create_Sequence (G);
      Add_Particle (Seq1, R, Seq2, Min_Occurs => 0, Max_Occurs => Unbounded);
      Add_Particle
        (Seq2, R,
         Create_Any (Process_Contents => Process_Lax,
                     Namespace        => R.Any_Namespace,
                     Target_NS        => XML_G));
      Add_Attribute
        (Seq1, Create_Local_Attribute (R.Source, G, uriReference));
      Add_Attribute (Seq1, Lookup_Attribute (XML_G, R, R.Lang));
      Set_Mixed_Content (Seq1, True);
      Set_Type (Create_Global_Element (G, R, R.Documentation, Qualified), R,
                Create_Local_Type (G, Seq1));

      --  The "annotation" element  ??? invalid
      Seq1 := Create_Sequence (G);
      Choice1 := Create_Choice (G);
      Add_Particle
        (Seq1, R, Choice1, Min_Occurs => 0, Max_Occurs => Unbounded);
      Add_Particle (Choice1, R, Lookup_Element (G, R, R.Appinfo));
      Add_Particle (Choice1, R, Lookup_Element (G, R, R.Documentation));
      Typ := Extension_Of (G, Openattrs, XML_Validator (Seq1));
      Add_Attribute
        (Typ, Create_Local_Attribute (R.Id, G, Lookup (G, R, R.UC_ID)));
      Set_Type (Annotation, R, Create_Local_Type (G, Typ));

      --  The "topLevelElement" type
      Seq1 := Create_Sequence (G);
      Add_Particle (Seq1, R, Annotation, Min_Occurs => 0);
      Choice1 := Create_Choice (G);
      Add_Particle (Seq1, R, Choice1, Min_Occurs => 0);
      Add_Particle (Choice1, R, Create_Local_Element
                      (R.Simple_Type, G, localSimpleType, Qualified));
      Add_Particle (Choice1, R, Create_Local_Element
                      (R.Complex_Type, G, localComplexType, Qualified));
      Add_Particle (Seq1, R, identityConstraint,
                    Min_Occurs => 0, Max_Occurs => Unbounded);
      Typ := Restriction_Of
        (G, R, Lookup (G, R, R.Element), XML_Validator (Seq1));
      Add_Attribute
        (Typ, Create_Local_Attribute (R.Ref, G, Attribute_Use => Prohibited));
      Add_Attribute
        (Typ, Create_Local_Attribute (R.Form, G, Attribute_Use => Prohibited));
      Add_Attribute
        (Typ, Create_Local_Attribute
           (R.MinOccurs, G, Attribute_Use => Prohibited));
      Add_Attribute
        (Typ, Create_Local_Attribute
           (R.MaxOccurs, G, Attribute_Use => Prohibited));
      Add_Attribute
        (Typ, Create_Local_Attribute
           (R.Name, G, NCNAME, Attribute_Use => Required));
      Create_Global_Type (G, R, R.Top_Level_Element, Typ);

      --  The R.Element element
      Elem := Create_Global_Element (G, R, R.Element, Qualified);
      Set_Type (Elem, R, Lookup (G, R, R.Top_Level_Element));
      Set_Substitution_Group (Elem, R, SchemaTop);

      --  The "attribute" element
      Elem := Create_Global_Element (G, R, R.Attribute, Qualified);
      Set_Type (Elem, R, Lookup (G, R, R.Top_Level_Attribute));
      Set_Substitution_Group (Elem, R, SchemaTop);

      --  The "redefinable" element  --  abstract=true
      Set_Type (Redefinable, R, Get_Type (SchemaTop));
      Set_Substitution_Group (Redefinable, R, SchemaTop);

      --  The "all" element
      Seq1 := Create_Sequence (G);
      Add_Particle (Seq1, R, Annotation, Min_Occurs => 0);

      Seq2 := Create_Sequence (G);
      Add_Particle (Seq2, R, Annotation, Min_Occurs => 0);
      Choice1 := Create_Choice (G);
      Add_Particle (Seq2, R, Choice1, Min_Occurs => 0);
      Add_Particle (Choice1, R, Create_Local_Element
                      (R.Simple_Type, G, localSimpleType, Qualified));
      Add_Particle (Choice1, R, Create_Local_Element
                      (R.Complex_Type, G, localComplexType, Qualified));
      Add_Particle (Seq2, R, identityConstraint,
                    Min_Occurs => 0, Max_Occurs => Unbounded);
      Typ2 := Restriction_Of
        (G, R, Lookup (G, R, R.Local_Element), XML_Validator (Seq2));

      Typ := Restriction_Of (G, R, nonNegativeInteger);
      Add_Facet (Typ, R, R.Enumeration, "0");
      Add_Facet (Typ, R, R.Enumeration, "1");
      Add_Attribute
        (Typ2, Create_Local_Attribute
           (R.MinOccurs, G, Create_Local_Type (G, Typ),
            Attribute_Use => Default, Default => R.S_1));

      Typ := Restriction_Of (G, R, Lookup (G, R, R.All_NNI));
      Add_Facet (Typ, R, R.Enumeration, "0");
      Add_Facet (Typ, R, R.Enumeration, "1");
      Add_Attribute
        (Typ2, Create_Local_Attribute
           (R.MaxOccurs, G, Create_Local_Type (G, Typ),
            Attribute_Use => Default, Default => R.S_1));

      Add_Particle (Seq1, R,
                    Create_Local_Element
                      (R.Element, G, Create_Local_Type (G, Typ2), Qualified),
                    Min_Occurs => 0, Max_Occurs => Unbounded);

      Typ := Restriction_Of
        (G, R, Lookup (G, R, R.Explicit_Group), XML_Validator (Seq1));

      Typ2 := Restriction_Of (G, R, nonNegativeInteger);
      Add_Facet (Typ2, R, R.Enumeration, "1");
      Add_Attribute
        (Typ, Create_Local_Attribute
           (R.MinOccurs, G, Create_Local_Type (G, Typ2),
            Attribute_Use => Default, Default => R.S_1));

      Typ2 := Restriction_Of (G, R, Lookup (G, R, R.All_NNI));
      Add_Facet (Typ2, R, R.Enumeration, "1");
      Add_Attribute
        (Typ, Create_Local_Attribute
           (R.MaxOccurs, G, Create_Local_Type (G, Typ2),
            Attribute_Use => Default, Default => R.S_1));

      Set_Type (All_E, R, Create_Local_Type (G, Typ));

      --  The "localElement" type
      Seq1 := Create_Sequence (G);
      Add_Particle (Seq1, R, Annotation, Min_Occurs => 0);
      Choice1 := Create_Choice (G);
      Add_Particle (Seq1, R, Choice1, Min_Occurs => 0);
      Add_Particle
        (Choice1, R, Create_Local_Element
           (R.Simple_Type, G, localSimpleType, Qualified));
      Add_Particle
        (Choice1, R, Create_Local_Element
           (R.Complex_Type, G, localComplexType, Qualified));
      Add_Particle (Seq1, R, identityConstraint,
                    Min_Occurs => 0, Max_Occurs => Unbounded);
      Add_Attribute (Seq1, Create_Local_Attribute (R.Substitution_Group, G,
                                             Attribute_Use => Prohibited));
      Add_Attribute (Seq1, Create_Local_Attribute (R.Final, G,
                                             Attribute_Use => Prohibited));
      Typ := Restriction_Of
        (G, R, Lookup (G, R, R.Element), XML_Validator (Seq1));
      Create_Global_Type (G, R, R.Local_Element, Typ);

      --  The "particle" group
      Gr := Create_Global_Group (G, R, R.Particle);
      Choice1 := Create_Choice (G);
      Add_Particle (Gr, R, Choice1);
      Add_Particle
        (Choice1, R, Create_Local_Element
           (R.Element, G, Lookup (G, R, R.Local_Element), Qualified));
      Add_Particle
        (Choice1, R, Create_Local_Element
           (R.Group, G, Lookup (G, R, R.Group_Ref), Qualified));
      Add_Particle (Choice1, R, All_E);
      Add_Particle (Choice1, R, Choice);
      Add_Particle (Choice1, R, Sequence);
      Add_Particle (Choice1, R, Any);

      --  R.Group type
      Typ := Extension_Of
        (G, R, Annotated,
         Lookup_Group (G, R, R.Particle),
         Min_Occurs => 0, Max_Occurs => Unbounded);
      Create_Global_Type (G, R, R.Group, Typ);
      Add_Attribute_Group (Typ, R, defRef);
      Add_Attribute_Group (Typ, R, Occurs);

      --  The "nestedParticle" element
      Gr := Create_Global_Group (G, R, R.Nested_Particle);
      Choice1 := Create_Choice (G);
      Add_Particle (Gr, R, Choice1);
      Add_Particle
        (Choice1, R, Create_Local_Element
           (R.Element, G, Lookup (G, R, R.Local_Element), Qualified));
      Add_Particle
        (Choice1, R, Create_Local_Element
           (R.Group, G, Lookup (G, R, R.Group_Ref), Qualified));
      Add_Particle (Choice1, R, Choice);
      Add_Particle (Choice1, R, Sequence);
      Add_Particle (Choice1, R, Any);

      --  "explicitGroup" type
      Seq1 := Create_Sequence (G);
      Add_Particle (Seq1, R, Annotation, Min_Occurs => 0);
      Add_Particle (Seq1, R, Lookup_Group (G, R, R.Nested_Particle),
                    Min_Occurs => 0, Max_Occurs => Unbounded);
      Typ := Restriction_Of
        (G, R, Lookup (G, R, R.Group), XML_Validator (Seq1));
      Create_Global_Type (G, R, R.Explicit_Group, Typ);
      Add_Attribute
        (Typ, Create_Local_Attribute
           (R.Name, G, NCNAME, Attribute_Use => Prohibited));
      Add_Attribute
        (Typ, Create_Local_Attribute
           (R.Ref, G, QNAME, Attribute_Use => Prohibited));

      --  The "choice" element
      Set_Type (Choice, R, Lookup (G, R, R.Explicit_Group));

      --  The "sequence" element
      Set_Type (Sequence, R, Lookup (G, R, R.Explicit_Group));

      --  "groupDefParticle" group
      Choice1 := Create_Choice (G);
      Add_Particle (groupDefParticle, R, Choice1);
      Add_Particle (Choice1, R, All_E);
      Add_Particle (Choice1, R, Choice);
      Add_Particle (Choice1, R, Sequence);

      --  The "realGroup" type
      Seq1 := Create_Sequence (G);
      Add_Particle (Seq1, R, Annotation, Min_Occurs => 0);
      Add_Particle (Seq1, R, groupDefParticle,
                    Min_Occurs => 0, Max_Occurs => 1);
      Typ := Restriction_Of
        (G, R, Lookup (G, R, R.Group), XML_Validator (Seq1));
      Create_Global_Type (G, R, R.Real_Group, Typ);

      --  The "groupRef" type
      Seq1 := Create_Sequence (G);
      Add_Particle (Seq1, R, Annotation, Min_Occurs => 0);
      Typ := Restriction_Of
        (G, R, Lookup (G, R, R.Real_Group), XML_Validator (Seq1));
      Create_Global_Type (G, R, R.Group_Ref, Typ);
      Add_Attribute
        (Typ, Create_Local_Attribute
           (R.Ref, G, QNAME, Attribute_Use => Required));
      Add_Attribute
        (Typ, Create_Local_Attribute (R.Name, G, Attribute_Use => Prohibited));

      --  The R.Group element
      Elem := Create_Global_Element (G, R, R.Group, Qualified);
      Set_Type (Elem, R, Lookup (G, R, R.Named_Group));
      Set_Substitution_Group (Elem, R, Redefinable);

      --  The "namedGroup" type
      Seq1 := Create_Sequence (G);
      Add_Particle (Seq1, R, Annotation, Min_Occurs => 0);
      Add_Particle (Seq1, R, groupDefParticle);
      Typ := Restriction_Of
        (G, R, Lookup (G, R, R.Real_Group), XML_Validator (Seq1));
      Add_Attribute (Typ, Create_Local_Attribute
                       (R.Name, G, NCNAME, Attribute_Use => Required));
      Add_Attribute (Typ, Create_Local_Attribute
                       (R.Ref, G, Attribute_Use => Prohibited));
      Add_Attribute (Typ, Create_Local_Attribute
                       (R.MinOccurs, G, Attribute_Use => Prohibited));
      Add_Attribute (Typ, Create_Local_Attribute
                       (R.MaxOccurs, G, Attribute_Use => Prohibited));
      Create_Global_Type (G, R, R.Named_Group, Typ);

      --  The R.Attribute_Group type
      Seq1 := Create_Sequence (G);
      Add_Particle (Seq1, R, attrDecls);
      Typ := Extension_Of (G, Annotated, XML_Validator (Seq1));
      Add_Attribute_Group (Typ, R, defRef);
      Create_Global_Type (G, R, R.Attribute_Group, Typ);

      --  The R.Named_Attribute_Group type
      Seq1 := Create_Sequence (G);
      Add_Particle (Seq1, R, Annotation, Min_Occurs => 0);
      Add_Particle (Seq1, R, attrDecls);
      Typ := Restriction_Of
        (G, R, Lookup (G, R, R.Attribute_Group), XML_Validator (Seq1));
      Add_Attribute
        (Typ, Create_Local_Attribute (R.Name, G, NCNAME,
                                Attribute_Use => Required));
      Add_Attribute
        (Typ, Create_Local_Attribute (R.Ref, G, Attribute_Use => Prohibited));
      Create_Global_Type (G, R, R.Named_Attribute_Group, Typ);

      --  The R.Attribute_Group element
      Elem := Create_Global_Element (G, R, R.Attribute_Group, Qualified);
      Set_Type (Elem, R, Lookup (G, R, R.Named_Attribute_Group));
      Set_Substitution_Group (Elem, R, Redefinable);

      --  The "typeDefParticle" group
      typeDefParticle := Create_Global_Group (G, R, R.Type_Def_Particle);
      Choice1 := Create_Choice (G);
      Add_Particle (typeDefParticle, R, Choice1);
      Add_Particle (Choice1, R, Create_Local_Element
                      (R.Group, G, Lookup (G, R, R.Group_Ref), Qualified));
      Add_Particle (Choice1, R, All_E);
      Add_Particle (Choice1, R, Choice);
      Add_Particle (Choice1, R, Sequence);

      --  The "attribute" type
      Seq1 := Create_Sequence (G);
      Add_Particle (Seq1, R, Create_Local_Element
                      (R.Simple_Type, G, localSimpleType, Qualified),
                    Min_Occurs => 0);
      Typ := Extension_Of (G, Annotated, XML_Validator (Seq1));
      Create_Global_Type (G, R, R.Attribute, Typ);
      Add_Attribute (Typ, Create_Local_Attribute (R.Typ, G, QNAME));

      Typ2 := Restriction_Of (G, R, NMTOKEN);
      Add_Facet (Typ2, R, R.Enumeration, "prohibited");
      Add_Facet (Typ2, R, R.Enumeration, "optional");
      Add_Facet (Typ2, R, R.Enumeration, "required");
      Add_Attribute_Group (Typ, R, defRef);
      Add_Attribute (Typ, Create_Local_Attribute
                       (R.S_Use, G, Create_Local_Type (G, Typ2),
                        Attribute_Use => Default,
                        Default => R.Optional));
      Add_Attribute (Typ, Create_Local_Attribute
                       (R.Default, G, Str, Attribute_Use => Optional));
      Add_Attribute (Typ, Create_Local_Attribute
                       (R.Fixed, G, Str, Attribute_Use => Optional));
      Add_Attribute (Typ, Create_Local_Attribute (R.Form, G, formChoice));

      --  The "topLevelAttribute" type
      Seq1 := Create_Sequence (G);
      Add_Particle (Seq1, R, Annotation, Min_Occurs => 0);
      Add_Particle (Seq1, R, Create_Local_Element
                      (R.Simple_Type, G, localSimpleType, Qualified),
                    Min_Occurs => 0);
      Typ := Restriction_Of
        (G, R, Lookup (G, R, R.Attribute), XML_Validator (Seq1));
      Create_Global_Type (G, R, R.Top_Level_Attribute, Typ);
      Add_Attribute
        (Typ, Create_Local_Attribute (R.Ref, G, Attribute_Use => Prohibited));
      Add_Attribute
        (Typ, Create_Local_Attribute (R.Form, G, Attribute_Use => Prohibited));
      Add_Attribute
        (Typ,
         Create_Local_Attribute (R.S_Use, G, Attribute_Use => Prohibited));
      Add_Attribute
        (Typ, Create_Local_Attribute
           (R.Name, G, NCNAME, Attribute_Use => Required));

      --  The "anyAttributes" element
      Set_Type (Create_Global_Element (G, R, R.Any_Attribute, Qualified), R,
                Lookup (G, R, R.Wildcard));

      --  The "namespaceList" type   ??? Incomplete
      Union := Create_Union (G);
      Typ := Restriction_Of (G, R, Token);
      Add_Facet (Typ, R, R.Enumeration, "##any");
      Add_Facet (Typ, R, R.Enumeration, "##other");
      Add_Union (Union, R, Create_Local_Type (G, Typ));

      Union2 := Create_Union (G);
      Add_Union (Union, R, Create_Local_Type (G, Union2));
      Add_Union (Union2, R, uriReference);
      Typ := Restriction_Of (G, R, Token);
      Add_Facet (Typ, R, R.Enumeration, "##targetNamespace");
      Add_Facet (Typ, R, R.Enumeration, "##local");
      Add_Union (Union2, R, Create_Local_Type (G, Typ));

      Create_Global_Type (G, R, R.Namespace_List, Union);

      --  The "wildcard" type
      Typ := Extension_Of (G, Annotated);
      Add_Attribute (Typ, Create_Local_Attribute (R.Namespace, G,
                                            Lookup (G, R, R.Namespace_List),
                                            Attribute_Use => Default,
                                            Default => R.Any_Namespace));
      Typ2 := Restriction_Of (G, R, NMTOKEN);
      Add_Facet (Typ2, R, R.Enumeration, "skip");
      Add_Facet (Typ2, R, R.Enumeration, "lax");
      Add_Facet (Typ2, R, R.Enumeration, "strict");
      Add_Attribute (Typ, Create_Local_Attribute (R.Process_Contents, G,
                                            Create_Local_Type (G, Typ2),
                                            Attribute_Use => Default,
                                            Default => R.Strict));
      Create_Global_Type (G, R, R.Wildcard, Typ);

      --  The "any" element   ??? Error if you put before "wildcard"
      Typ := Extension_Of (G, Lookup (G, R, R.Wildcard));
      Add_Attribute_Group (Typ, R, Occurs);
      Set_Type (Any, R, Create_Local_Type (G, Typ));

      --  The "attributeGroupRef"  ??? invalid
      Seq1 := Create_Sequence (G);
      Add_Particle (Seq1, R, Annotation, Min_Occurs => 0);
      Typ := Restriction_Of
        (G, R, Lookup (G, R, R.Attribute_Group), XML_Validator (Seq1));
      Add_Attribute
        (Typ, Create_Local_Attribute
           (R.Ref, G, QNAME, Attribute_Use => Required));
      Add_Attribute
        (Typ, Create_Local_Attribute (R.Name, G, Attribute_Use => Prohibited));
      Create_Global_Type (G, R, R.Attribute_Group_Ref, Typ);

      --  The "attrDecls" group
      Seq1 := Create_Sequence (G);
      Add_Particle (attrDecls, R, Seq1);
      Choice1 := Create_Choice (G);
      Add_Particle
        (Seq1, R, Choice1, Min_Occurs => 0, Max_Occurs => Unbounded);
      Add_Particle
        (Choice1, R, Create_Local_Element
           (R.Attribute, G, Lookup (G, R, R.Attribute), Qualified));
      Add_Particle
        (Choice1, R, Create_Local_Element
           (R.Attribute_Group, G,
            Lookup (G, R, R.Attribute_Group_Ref), Qualified));
      Add_Particle
        (Seq1, R, Lookup_Element (G, R, R.Any_Attribute), Min_Occurs => 0);

      --  The "extensionType" type
      Seq1 := Create_Sequence (G);
      Add_Particle (Seq1, R, typeDefParticle, Min_Occurs => 0);
      Add_Particle (Seq1, R, attrDecls);
      Typ := Extension_Of (G, Annotated, XML_Validator (Seq1));
      Add_Attribute (Typ, Create_Local_Attribute (R.Base, G, QNAME));
      Create_Global_Type (G, R, R.Extension_Type, Typ);

      --  The "restrictionType" type
      Seq1 := Create_Sequence (G);
      Choice1 := Create_Choice (G);
      Add_Particle (Choice1, R, typeDefParticle, Min_Occurs => 0);
      Add_Particle (Choice1, R, simpleRestrictionModel, Min_Occurs => 0);
      Add_Particle (Seq1, R, Choice1);
      Add_Particle (Seq1, R, attrDecls);
      Typ := Extension_Of (G, Annotated, XML_Validator (Seq1));
      Add_Attribute (Typ, Create_Local_Attribute
                       (R.Base, G, QNAME, Attribute_Use => Required));
      Create_Global_Type (G, R, R.Restriction_Type, Typ);

      --  The "simpleRestrictionModel" group
      Seq1 := Create_Sequence (G);
      Add_Particle (Seq1, R, Create_Local_Element
                    (R.Simple_Type, G, localSimpleType, Qualified),
                    Min_Occurs => 0);
      Add_Particle (Seq1, R, Facet, Min_Occurs => 0, Max_Occurs => Unbounded);
      Add_Particle (simpleRestrictionModel, R, Seq1);

      --  The "simpleExtensionType"
      Seq1 := Create_Sequence (G);
      Add_Particle (Seq1, R, Annotation, Min_Occurs => 0);
      Add_Particle (Seq1, R, attrDecls);
      Create_Global_Type (G, R, R.Simple_Extension_Type,
                Restriction_Of (G, R, Lookup (G, R, R.Extension_Type),
                                XML_Validator (Seq1)));

      --  The "simpleRestrictionType"
      Seq1 := Create_Sequence (G);
      Add_Particle (Seq1, R, Annotation, Min_Occurs => 0);
      Add_Particle (Seq1, R, simpleRestrictionModel, Min_Occurs => 0);
      Add_Particle (Seq1, R, attrDecls);
      Create_Global_Type (G, R, R.Simple_Restriction_Type,
                Restriction_Of (G, R, Lookup (G, R, R.Restriction_Type),
                                XML_Validator (Seq1)));

      --  The "simpleContent" element
      Choice1 := Create_Choice (G);
      Add_Particle (Choice1, R, Create_Local_Element
                      (R.Restriction, G,
                       Lookup (G, R, R.Simple_Restriction_Type),
                       Qualified));
      Add_Particle (Choice1, R, Create_Local_Element
                      (R.Extension, G,
                       Lookup (G, R, R.Simple_Extension_Type),
                       Qualified));
      Typ := Extension_Of (G, Annotated, XML_Validator (Choice1));
      Set_Type (Create_Global_Element (G, R, R.Simple_Content, Qualified), R,
                Create_Local_Type (G, Typ));

      --  The "complexRestrictionType" type
      Seq1 := Create_Sequence (G);
      Add_Particle (Seq1, R, Annotation, Min_Occurs => 0);
      Add_Particle (Seq1, R, typeDefParticle, Min_Occurs => 0);
      Add_Particle (Seq1, R, attrDecls);
      Typ := Restriction_Of (G, R, Lookup (G, R, R.Restriction_Type),
                             XML_Validator (Seq1));
      Create_Global_Type (G, R, R.Complex_Restriction_Type, Typ);

      --  The "complexContent" element
      Choice1 := Create_Choice (G);
      Add_Particle
        (Choice1, R, Create_Local_Element
           (R.Restriction, G, Lookup (G, R, R.Complex_Restriction_Type),
            Qualified));
      Add_Particle
        (Choice1, R, Create_Local_Element
           (R.Extension, G, Lookup (G, R, R.Extension_Type), Qualified));
      Add_Attribute (Choice1, Create_Local_Attribute (R.Mixed, G, Bool));
      Typ := Extension_Of (G, Annotated, XML_Validator (Choice1));
      Set_Type (Create_Global_Element (G, R, R.Complex_Content, Qualified), R,
                Create_Local_Type (G, Typ));

      --  The "complexTypeModel" group
      Choice1 := Create_Choice (G);
      Add_Particle (complexTypeModel, R, Choice1);
      Add_Particle (Choice1, R, Lookup_Element (G, R, R.Simple_Content));
      Add_Particle (Choice1, R, Lookup_Element (G, R, R.Complex_Content));
      Seq1 := Create_Sequence (G);
      Add_Particle (Choice1, R, Seq1);
      Add_Particle (Seq1, R, typeDefParticle, Min_Occurs => 0);
      Add_Particle (Seq1, R, attrDecls);

      --  The R.Complex_Type type  ??? abstract=true
      Typ := Extension_Of (G, R, Annotated, complexTypeModel);
      Create_Global_Type (G, R, R.Complex_Type, Typ);
      Add_Attribute (Typ, Create_Local_Attribute (R.Name, G, NCNAME));
      Add_Attribute (Typ, Create_Local_Attribute
                       (R.Mixed, G, Bool, Attribute_Use => Default,
                        Default => R.S_False));
      Add_Attribute (Typ, Create_Local_Attribute
                       (R.S_Abstract, G, Bool, Attribute_Use => Default,
                        Default => R.S_False));
      Add_Attribute (Typ, Create_Local_Attribute (R.Final, G, derivationSet));
      Add_Attribute
        (Typ,
         Create_Local_Attribute (R.Block, G, derivationSet,
                                 Attribute_Use => Default));

      --  The "topLevelComplexType" type
      Seq1 := Create_Sequence (G);
      Add_Particle (Seq1, R, Annotation, Min_Occurs => 0);
      Add_Particle (Seq1, R, complexTypeModel);
      Typ := Restriction_Of (G, R, Lookup (G, R, R.Complex_Type),
                             XML_Validator (Seq1));
      Add_Attribute (Typ, Create_Local_Attribute
                       (R.Name, G, NCNAME, Attribute_Use => Required));
      Create_Global_Type (G, R, R.Top_Level_Complex_Type, Typ);

      --  The R.Complex_Type element
      Elem := Create_Global_Element (G, R, R.Complex_Type, Qualified);
      Set_Type (Elem, R, Lookup (G, R, R.Top_Level_Complex_Type));
      Set_Substitution_Group (Elem, R, Redefinable);

      --  The "notation" element
      Typ := Restriction_Of (G, R, Annotated);
      Add_Attribute (Typ, Create_Local_Attribute
                       (R.Name, G, NCNAME, Attribute_Use => Required));
      Add_Attribute (Typ, Create_Local_Attribute
                       (R.Public, G, Lookup (G, R, R.Public),
                        Attribute_Use => Required));
      Add_Attribute (Typ, Create_Local_Attribute (R.System, G, uriReference));
      Elem := Create_Global_Element (G, R, R.Notation, Qualified);
      Set_Type (Elem, R, Create_Local_Type (G, Typ));
      Set_Substitution_Group (Elem, R, SchemaTop);

      --  The "public" type
      Create_Global_Type (G, R, R.Public, Get_Validator (Token));

      --  The "redefine" element
      Seq1 := Create_Sequence (G);
      Choice1 := Create_Choice (G);
      Add_Particle
        (Seq1, R, Choice1, Min_Occurs => 0, Max_Occurs => Unbounded);
      Add_Particle (Choice1, R, Annotation);
      Add_Particle (Choice1, R, Redefinable);
      Add_Attribute
        (Seq1, Create_Local_Attribute
           (R.Schema_Location, G, uriReference, Attribute_Use => Required));
      Typ := Extension_Of (G, Openattrs, XML_Validator (Seq1));
      Set_Type (Create_Global_Element (G, R, R.Redefine, Qualified), R,
                Create_Local_Type (G, Typ));

      --  From datatypes.xsd

      --  The "localSimpleType" type
      Seq1 := Create_Sequence (G);
      Add_Particle (Seq1, R, Annotation, Min_Occurs => 0);
      Add_Particle (Seq1, R, SimpleDerivation);
      Typ := Restriction_Of (G, R, Lookup (G, R, R.Simple_Type),
                             XML_Validator (Seq1));
      Add_Attribute (Typ, Create_Local_Attribute
                       (R.Name, G, Attribute_Use => Prohibited));
      localSimpleType := Create_Global_Type (G, R, R.Local_Simple_Type, Typ);

      --  The "simpleDerivation" element  ??? abstract=true
      Set_Type (SimpleDerivation, R, Annotated);

      --  The "simpleDerivationSet" type
      Union := Create_Union (G);
      Typ := Restriction_Of (G, R, Token);
      Add_Facet (Typ, R, R.Enumeration, "#all");
      Add_Union (Union, R, Create_Local_Type (G, Typ));
      Typ := Restriction_Of (G, R, derivationControl);
      Add_Facet (Typ, R, R.Enumeration, "list");
      Add_Facet (Typ, R, R.Enumeration, "union");
      Add_Facet (Typ, R, R.Enumeration, "restriction");
      Add_Facet (Typ, R, R.Enumeration, "extension");
      Add_Union (Union, R, List_Of (G, Create_Local_Type (G, Typ)));
      Create_Global_Type (G, R, R.Simple_Derivation_Set, Union);

      --  The R.Simple_Type type  ??? abstract=true
      Seq1 := Create_Sequence (G);
      Add_Particle (Seq1, R, SimpleDerivation);
      Typ := Extension_Of (G, Annotated, XML_Validator (Seq1));
      Add_Attribute (Typ, Create_Local_Attribute (R.Name, G, NCNAME));
      Add_Attribute
        (Typ, Create_Local_Attribute
           (R.Final, G, Lookup (G, R, R.Simple_Derivation_Set)));
      Create_Global_Type (G, R, R.Simple_Type, Typ);

      --  The "topLevelSimpleType" type
      Seq1 := Create_Sequence (G);
      Add_Particle (Seq1, R, Annotation, Min_Occurs => 0);
      Add_Particle (Seq1, R, SimpleDerivation);
      Typ := Restriction_Of (G, R, Lookup (G, R, R.Simple_Type),
                             XML_Validator (Seq1));
      Create_Global_Type (G, R, R.Top_Level_Simple_Type, Typ);
      Add_Attribute
        (Typ, Create_Local_Attribute
           (R.Name, G, NCNAME, Attribute_Use => Required));
      Add_Attribute
        (Typ, Create_Any_Attribute (G, Process_Lax, Kind => Namespace_Other));

      --  The R.Simple_Type element
      Elem := Create_Global_Element (G, R, R.Simple_Type, Qualified);
      Set_Type (Elem, R, Lookup (G, R, R.Top_Level_Simple_Type));
      Set_Substitution_Group (Elem, R, Redefinable);

      --  The "restriction" element
      Typ := Extension_Of (G, R, Annotated, simpleRestrictionModel);
      Add_Attribute
        (Typ, Create_Local_Attribute (R.Base, G, QNAME,
                                      Attribute_Use => Optional));
      Elem := Create_Global_Element (G, R, R.Restriction, Qualified);
      Set_Type (Elem, R, Create_Local_Type (G, Typ));
      Set_Substitution_Group (Elem, R, SimpleDerivation);

      --  The "union" element
      Seq1 := Create_Sequence (G);
      Add_Particle (Seq1, R,
                    Create_Local_Element
                      (R.Simple_Type, G, localSimpleType, Qualified),
                    Min_Occurs => 0, Max_Occurs => Unbounded);
      Typ := Extension_Of (G, Annotated, XML_Validator (Seq1));
      Add_Attribute
        (Typ, Create_Local_Attribute (R.Member_Types, G,
                                List_Of (G, QNAME),
                                Attribute_Use => Optional));
      Elem := Create_Global_Element (G, R, R.Union, Qualified);
      Set_Type (Elem, R, Create_Local_Type (G, Typ));
      Set_Substitution_Group (Elem, R, SimpleDerivation);

      --  The "list" element
      Seq1 := Create_Sequence (G);
      Add_Particle (Seq1, R, Create_Local_Element
                      (R.Simple_Type, G, localSimpleType, Qualified),
                    Min_Occurs => 0);
      Typ := Extension_Of (G, Annotated, XML_Validator (Seq1));
      Add_Attribute
        (Typ, Create_Local_Attribute (R.Item_Type, G, QNAME,
         Attribute_Use => Optional));
      Elem := Create_Global_Element (G, R, R.List, Qualified);
      Set_Type (Elem, R, Create_Local_Type (G, Typ));
      Set_Substitution_Group (Elem, R, SimpleDerivation);

      --  The "facet" type
      Typ := Restriction_Of (G, R, Annotated);
      Add_Attribute
        (Typ, Create_Local_Attribute (R.Value, G,
                                Lookup (G, R, R.Any_Simple_Type),
                                Attribute_Use => Required));
      Add_Attribute
        (Typ, Create_Local_Attribute (R.Fixed, G, Bool,
                                Attribute_Use => Optional));
      Facet_Type := Create_Global_Type (G, R, R.Facet, Typ);

      --  The "numFacet" type
      Seq1 := Create_Sequence (G);
      Add_Particle (Seq1, R, Annotation, Min_Occurs => 0);
      Typ := Restriction_Of (G, R, Facet_Type, XML_Validator (Seq1));
      Add_Attribute
        (Typ, Create_Local_Attribute (R.Value, G, nonNegativeInteger));
      numFacet := Create_Global_Type (G, R, R.Num_Facet, Typ);

      --  The "facet" element  ??? abstract=true
      Set_Type (Facet, R, Facet_Type);

      --  The R.Enumeration element
      Elem := Create_Global_Element (G, R, R.Enumeration, Qualified);
      Set_Type (Elem, R, Get_Type (Facet));
      Set_Substitution_Group (Elem, R, Facet);

      --  The "pattern" element
      Elem := Create_Global_Element (G, R, R.Pattern, Qualified);
      Set_Type (Elem, R, Get_Type (Facet));
      Set_Substitution_Group (Elem, R, Facet);

      --  The "maxLength" element
      Elem := Create_Global_Element (G, R, R.Maxlength, Qualified);
      Set_Type (Elem, R, numFacet);
      Set_Substitution_Group (Elem, R, Facet);

      --  The "minLength" element
      Elem := Create_Global_Element (G, R, R.Minlength, Qualified);
      Set_Type (Elem, R, numFacet);
      Set_Substitution_Group (Elem, R, Facet);

      --  The "length" element
      Elem := Create_Global_Element (G, R, R.Length, Qualified);
      Set_Type (Elem, R, numFacet);
      Set_Substitution_Group (Elem, R, Facet);

      --  The "minBound" element
      Set_Type (minBound, R, Facet_Type);
      Set_Abstract (minBound, True);
      Set_Substitution_Group (minBound, R, Facet);

      --  The "minExclusive" element
      Elem := Create_Global_Element (G, R, R.MinExclusive, Qualified);
      Set_Type (Elem, R, Facet_Type);
      Set_Substitution_Group (Elem, R, minBound);

      --  The "minInclusive" element
      Elem := Create_Global_Element (G, R, R.MinInclusive, Qualified);
      Set_Type (Elem, R, Facet_Type);
      Set_Substitution_Group (Elem, R, minBound);

      --  The "maxBound" element
      Set_Type (maxBound, R, Facet_Type);
      Set_Abstract (maxBound, True);
      Set_Substitution_Group (maxBound, R, Facet);

      --  The "maxExclusive" element
      Elem := Create_Global_Element (G, R, R.MaxExclusive, Qualified);
      Set_Type (Elem, R, Facet_Type);
      Set_Substitution_Group (Elem, R, maxBound);

      --  The "maxInclusive" element
      Elem := Create_Global_Element (G, R, R.MaxInclusive, Qualified);
      Set_Type (Elem, R, Facet_Type);
      Set_Substitution_Group (Elem, R, maxBound);

      --  The "whiteSpace" element
      Elem := Create_Global_Element (G, R, R.Whitespace, Qualified);
      Set_Substitution_Group (Elem, R, Facet);
      Seq1 := Create_Sequence (G);
      Add_Particle (Seq1, R, Annotation, Min_Occurs => 0);
      Typ := Restriction_Of (G, R, Facet_Type, XML_Validator (Seq1));
      Typ2 := Restriction_Of (G, R, NMTOKEN);
      Add_Facet (Typ2, R, R.Enumeration, "preserve");
      Add_Facet (Typ2, R, R.Enumeration, "replace");
      Add_Facet (Typ2, R, R.Enumeration, "collapse");
      Add_Attribute
        (Typ, Create_Local_Attribute (R.Value, G,
                                      Create_Local_Type (G, Typ2)));
      Set_Type (Elem, R, Create_Local_Type (G, Typ));

      --  The "totalDigits" element
      Elem := Create_Global_Element (G, R, R.Total_Digits, Qualified);
      Set_Substitution_Group (Elem, R, Facet);
      Seq1 := Create_Sequence (G);
      Add_Particle (Seq1, R, Annotation, Min_Occurs => 0);
      Typ := Restriction_Of (G, R, numFacet, XML_Validator (Seq1));
      Add_Attribute
        (Typ, Create_Local_Attribute
           (R.Value, G, Lookup (G, R, R.Positive_Integer),
           Attribute_Use => Required));
      Add_Attribute
        (Typ, Create_Any_Attribute (G, Process_Lax, Kind => Namespace_Other));
      Set_Type (Elem, R, Create_Local_Type (G, Typ));

      --  The "fractionDigits" element
      Elem := Create_Global_Element (G, R, R.Fraction_Digits, Qualified);
      Set_Type (Elem, R, numFacet);
      Set_Substitution_Group (Elem, R, Facet);

      --  The namespace schema

      Create_Global_Attribute (XML_G, R, R.Base, Str);

      Global_Check (R, G);
   end Add_Schema_For_Schema;

end Schema.Validators.XSD_Grammar;
