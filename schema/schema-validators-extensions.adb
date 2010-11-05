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

package body Schema.Validators.Extensions is

   type Extension_XML_Validator is new XML_Validator_Record with record
      Base      : XML_Type;
      Extension : XML_Validator;
      Facets_Merged : Boolean := False;
   end record;
   type Extension_Type is access Extension_XML_Validator'Class;

   overriding procedure Validate_Characters
     (Validator     : access Extension_XML_Validator;
      Reader        : access Abstract_Validation_Reader'Class;
      Ch            : Unicode.CES.Byte_Sequence;
      Empty_Element : Boolean;
      Mask          : in out Facets_Mask);
   overriding function Is_Extension_Of
     (Validator : Extension_XML_Validator;
      Base      : access XML_Validator_Record'Class) return Boolean;
   overriding function Get_Mixed_Content
     (Validator : access Extension_XML_Validator) return Boolean;
   overriding function Get_Facets
     (Validator : access Extension_XML_Validator;
      Reader : access Abstract_Validation_Reader'Class)
      return Facets_Description;
   overriding function Equal
     (Validator : access Extension_XML_Validator;
      Reader : access Abstract_Validation_Reader'Class;
      Value1, Value2 : Unicode.CES.Byte_Sequence) return Boolean;
   --  See doc from inherited subprograms

   ----------------
   -- Get_Facets --
   ----------------

   function Get_Facets
     (Validator : access Extension_XML_Validator;
      Reader : access Abstract_Validation_Reader'Class)
      return Facets_Description is
   begin
      if Validator.Base.Validator /= null then
         return Get_Facets (Validator.Base.Validator, Reader);
      end if;

      return null;
   end Get_Facets;

   -----------------------
   -- Get_Mixed_Content --
   -----------------------

   overriding function Get_Mixed_Content
     (Validator : access Extension_XML_Validator) return Boolean is
   begin
      return Get_Mixed_Content (XML_Validator_Record (Validator.all)'Access)
        or else Get_Mixed_Content (Get_Validator (Validator.Base));
   end Get_Mixed_Content;

   -------------------------
   -- Validate_Characters --
   -------------------------

   overriding procedure Validate_Characters
     (Validator     : access Extension_XML_Validator;
      Reader        : access Abstract_Validation_Reader'Class;
      Ch            : Unicode.CES.Byte_Sequence;
      Empty_Element : Boolean;
      Mask          : in out Facets_Mask) is
   begin
      if Debug then
         Debug_Push_Prefix
           ("Validate_Characters (ext) " & Get_Name (Validator));
      end if;

      if Validator.Extension /= null then
         Validate_Characters
           (Validator.Extension, Reader, Ch, Empty_Element, Mask);
      else
         if Debug then
            Debug_Output ("Validate_Characters (ext), testing base "
                          & Get_Name (Validator));
         end if;

         Validate_Characters
           (Get_Validator (Validator.Base), Reader, Ch, Empty_Element, Mask);
      end if;

      Debug_Pop_Prefix;

   exception
      when XML_Validation_Error =>
         --  If null, we have already tested
         if Validator.Extension /= null then
            if Debug then
               Debug_Output ("Validation error (ext), testing base");
            end if;
            Validate_Characters
              (Get_Validator (Validator.Base), Reader,
               Ch, Empty_Element, Mask);
            Debug_Pop_Prefix;

         else
            Debug_Pop_Prefix;
            raise;
         end if;

      when others =>
         Debug_Pop_Prefix;
         raise;
   end Validate_Characters;

   -----------
   -- Equal --
   -----------

   overriding function Equal
     (Validator : access Extension_XML_Validator;
      Reader : access Abstract_Validation_Reader'Class;
      Value1, Value2 : Unicode.CES.Byte_Sequence) return Boolean is
   begin
      return Equal (Get_Validator (Validator.Base), Reader, Value1, Value2);
   end Equal;

   -----------------------
   -- Check_Replacement --
   -----------------------

--     overriding procedure Check_Replacement
--       (Validator       : access Extension_XML_Validator;
--        Element         : XML_Element;
--        Typ             : XML_Type;
--        Valid           : out Boolean;
--        Had_Restriction : in out Boolean;
--        Had_Extension   : in out Boolean)
--     is
--        B : constant XML_Validator := Get_Validator (Typ);
--     begin
--        --  From 3.4.6.5 "Type Derivation OK (Complex)".
--       --  D is "Validator", B is "Typ" (not necessarily the base type of D).
--        --  All of the following must be true.
--     --  1. If B /= D, then the {derivation method} of D is not in the subset
--        --  2 One or more of the following is true:
--        --  2.1 B = D
--        --  2.2 B = D.base
--        --  2.3 All of the following are true:
--        --  2.3.1 D.{base type definition} /= xs:anyType
--        --  2.3.2 D.Base is validly derived from B
--
--        Valid := (XML_Validator (Validator) = B    --  1
--                  or else not Typ.Blocks (Block_Extension));
--        if Valid then
--           Valid := XML_Validator (Validator) = B        --  2.1
--             or else Get_Validator (Validator.Base) = B; --  2.2
--
--           if not Valid
--         and then not Is_Wildcard (Get_Validator (Validator.Base)) --  2.3.1
--           then
--              Check_Replacement                       --  2.3.2
--                (Get_Validator (Validator.Base), Element,
--                 Typ, Valid, Had_Restriction, Had_Extension);
--           end if;
--        end if;
--
--        Had_Extension := True;
--     end Check_Replacement;

   -------------------------
   -- Create_Extension_Of --
   -------------------------

   function Create_Extension_Of
     (G         : XML_Grammar_NS;
      Base      : XML_Type;
      Extension : XML_Validator := null) return XML_Validator
   is
      pragma Unreferenced (G);
      Result : constant Extension_Type := new Extension_XML_Validator;
   begin
      Result.Base      := Base;
      Result.Extension := Extension;
      return XML_Validator (Result);
   end Create_Extension_Of;

   ---------------------
   -- Is_Extension_Of --
   ---------------------

   overriding function Is_Extension_Of
     (Validator : Extension_XML_Validator;
      Base      : access XML_Validator_Record'Class) return Boolean
   is
   begin
      return Validator.Base.Validator = XML_Validator (Base)
        or else Is_Extension_Of
          (Validator.Base.Validator.all, Base => Base);
   end Is_Extension_Of;

end Schema.Validators.Extensions;
