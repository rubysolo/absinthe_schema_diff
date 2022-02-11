defmodule Absinthe.SchemaDiff.DiffTest do
  use ExUnit.Case

  alias Absinthe.SchemaDiff.{
    Diff,
    Diff.DiffSet
  }

  alias Absinthe.SchemaDiff.Introspection.{
    Enumeration,
    Field,
    InputObject,
    Object,
    Schema,
    Type,
    Union
  }

  @enum %Enumeration{
    name: "Colors",
    values: [
      %Field{name: "Red", type: nil},
      %Field{name: "Green", type: nil},
      %Field{name: "Blue", type: nil}
    ]
  }

  @nullable_string %Type{kind: "SCALAR", name: "String"}
  @required_string %Type{kind: "NON_NULL", of_type: %Type{kind: "SCALAR", name: "String"}}

  @input_object %InputObject{
    name: "FormInput",
    fields: [
      %Field{name: "Name", type: @required_string},
      %Field{name: "Birthday", type: %Type{kind: "SCALAR", name: "Date"}}
    ]
  }

  @object %Object{
    name: "Car",
    fields: [
      %Field{name: "Year", type: @required_string},
      %Field{name: "Make", type: @nullable_string},
      %Field{name: "Model", type: @nullable_string}
    ]
  }

  @union %Union{
    name: "SearchResult",
    possible_types: [
      %Type{kind: "OBJECT", name: "Car"},
      %Type{kind: "OBJECT", name: "Movie"}
    ]
  }

  @schema %Schema{
    enums: [@enum],
    input_objects: [@input_object],
    objects: [@object],
    unions: [@union]
  }

  describe "diff/2" do
    test "identical structures return an empty diff" do
      assert [] == Diff.diff(@schema, @schema)
      assert [] == Diff.diff(@enum, @enum)
    end

    test "added enums are reported" do
      new_enum = %Enumeration{
        name: "Shapes",
        values: [
          %Field{name: "Square", type: nil},
          %Field{name: "Circle", type: nil},
          %Field{name: "Triangle", type: nil}
        ]
      }

      existing_schema = @schema
      new_schema = %{existing_schema | enums: [@enum, new_enum]}

      assert %DiffSet{additions: [new_enum]} == Diff.diff(@schema, new_schema)
    end

    test "removed enums are reported" do
      existing_schema = @schema
      new_schema = %{existing_schema | enums: []}

      assert %DiffSet{removals: [@enum]} == Diff.diff(@schema, new_schema)
    end

    test "added enum members are reported" do
      new_enum = %Enumeration{
        name: "Colors",
        values: [
          %Field{name: "Red", type: nil},
          %Field{name: "Green", type: nil},
          %Field{name: "Blue", type: nil},
          %Field{name: "Violet", type: nil}
        ]
      }

      existing_schema = @schema
      new_schema = %{existing_schema | enums: [new_enum]}

      assert %DiffSet{
               changes: [
                 %Diff{
                   type: Enumeration,
                   name: "Colors",
                   changes: %DiffSet{
                     additions: [
                       %Field{name: "Violet", type: nil}
                     ]
                   }
                 }
               ]
             } == Diff.diff(@schema, new_schema)
    end

    test "removed enum members are reported" do
      new_enum = %Enumeration{
        name: "Colors",
        values: [
          %Field{name: "Red", type: nil},
          %Field{name: "Green", type: nil}
        ]
      }

      existing_schema = @schema
      new_schema = %{existing_schema | enums: [new_enum]}

      assert %DiffSet{
               changes: [
                 %Diff{
                   type: Enumeration,
                   name: "Colors",
                   changes: %DiffSet{
                     removals: [
                       %Field{name: "Blue", type: nil}
                     ]
                   }
                 }
               ]
             } == Diff.diff(@schema, new_schema)
    end

    test "added objects are reported" do
      new_object = %Object{
        name: "Movie",
        fields: [
          %Field{name: "Year", type: @required_string},
          %Field{name: "Title", type: @nullable_string},
          %Field{name: "Genre", type: @nullable_string}
        ]
      }

      existing_schema = @schema
      new_schema = %{existing_schema | objects: [@object, new_object]}

      assert %DiffSet{additions: [new_object]} == Diff.diff(@schema, new_schema)
    end

    test "removed objects are reported" do
      existing_schema = @schema
      new_schema = %{existing_schema | objects: []}

      assert %DiffSet{removals: [@object]} == Diff.diff(@schema, new_schema)
    end

    test "added object fields are reported" do
      new_field = %Field{name: "Color", type: "String"}
      existing_object = @object
      new_object = %{existing_object | fields: [new_field | existing_object.fields]}

      existing_schema = @schema
      new_schema = %{existing_schema | objects: [new_object]}

      assert %DiffSet{
               changes: [
                 %Diff{type: Object, name: "Car", changes: %DiffSet{additions: [new_field]}}
               ]
             } == Diff.diff(@schema, new_schema)
    end

    test "removed object fields are reported" do
      %Object{fields: [field | fields]} = existing_object = @object
      new_object = %{existing_object | fields: fields}

      existing_schema = @schema
      new_schema = %{existing_schema | objects: [new_object]}

      assert %DiffSet{
               changes: [
                 %Diff{type: Object, name: "Car", changes: %DiffSet{removals: [field]}}
               ]
             } == Diff.diff(@schema, new_schema)
    end

    # TODO: object field type changes
    # TODO: object field deprecation changes

    test "added input objects are reported" do
      new_input_object = %InputObject{
        name: "Movie",
        fields: [
          %Field{name: "Year", type: @required_string},
          %Field{name: "Title", type: @nullable_string},
          %Field{name: "Genre", type: @nullable_string}
        ]
      }

      existing_schema = @schema

      new_schema = %{
        existing_schema
        | input_objects: [
            @input_object,
            new_input_object
          ]
      }

      assert %DiffSet{additions: [new_input_object]} == Diff.diff(@schema, new_schema)
    end

    test "removed input objects are reported" do
      existing_schema = @schema
      new_schema = %{existing_schema | input_objects: []}

      assert %DiffSet{removals: [@input_object]} == Diff.diff(@schema, new_schema)
    end

    test "added input object fields are reported" do
      new_field = %Field{name: "Color", type: @nullable_string}
      existing_input_object = @input_object

      new_input_object = %{
        existing_input_object
        | fields: [new_field | existing_input_object.fields]
      }

      existing_schema = @schema
      new_schema = %{existing_schema | input_objects: [new_input_object]}

      assert %DiffSet{
               changes: [
                 %Diff{
                   type: InputObject,
                   name: "FormInput",
                   changes: %DiffSet{additions: [new_field]}
                 }
               ]
             } == Diff.diff(@schema, new_schema)
    end

    test "removed input object fields are reported" do
      %InputObject{fields: [field | fields]} = existing_input_object = @input_object
      new_input_object = %{existing_input_object | fields: fields}

      existing_schema = @schema
      new_schema = %{existing_schema | input_objects: [new_input_object]}

      assert %DiffSet{
               changes: [
                 %Diff{type: InputObject, name: "FormInput", changes: %DiffSet{removals: [field]}}
               ]
             } == Diff.diff(@schema, new_schema)
    end

    # TODO: input object field type changes
    # TODO: input object field deprecation changes

    test "added unions are reported" do
      new_union = %Union{
        name: "Life",
        possible_types: [
          %Type{kind: "OBJECT", name: "Plant"},
          %Type{kind: "OBJECT", name: "Animal"}
        ]
      }

      existing_schema = @schema
      new_schema = %{existing_schema | unions: [@union, new_union]}

      assert %DiffSet{additions: [new_union]} == Diff.diff(@schema, new_schema)
    end

    test "removed unions are reported" do
      existing_schema = @schema
      new_schema = %{existing_schema | unions: []}

      assert %DiffSet{removals: [@union]} == Diff.diff(@schema, new_schema)
    end

    test "added union types are reported" do
      new_type = %Type{kind: "OBJECT", name: "Guitar"}
      existing_union = @union
      new_union = %{existing_union | possible_types: [new_type | existing_union.possible_types]}

      existing_schema = @schema
      new_schema = %{existing_schema | unions: [new_union]}

      assert %DiffSet{
               changes: [
                 %Diff{
                   type: Union,
                   name: "SearchResult",
                   changes: %DiffSet{additions: [new_type]}
                 }
               ]
             } == Diff.diff(@schema, new_schema)
    end

    test "removed union types are reported" do
      %Union{possible_types: [type | types]} = existing_union = @union
      new_union = %{existing_union | possible_types: types}

      existing_schema = @schema
      new_schema = %{existing_schema | unions: [new_union]}

      assert %DiffSet{
               changes: [
                 %Diff{type: Union, name: "SearchResult", changes: %DiffSet{removals: [type]}}
               ]
             } == Diff.diff(@schema, new_schema)
    end

    test "changed union types are reported" do
      %Union{possible_types: [type | types]} = existing_union = @union
      new_type = %{type | kind: "OTHER"}
      new_union = %{existing_union | possible_types: [new_type | types]}

      existing_schema = @schema
      new_schema = %{existing_schema | unions: [new_union]}

      assert %DiffSet{
               changes: [
                 %Diff{type: Union, name: "SearchResult", changes: %DiffSet{
                   changes: [
                     %Diff{
                       name: "Car",
                       type: Type,
                       changes: %DiffSet{
                         additions: ["other"],
                         removals: ["object"],
                       }
                     }
                   ]
                 }}
               ]
             } == Diff.diff(@schema, new_schema)
    end
  end
end