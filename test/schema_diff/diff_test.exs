defmodule Absinthe.SchemaDiff.DiffTest do
  use ExUnit.Case

  alias Absinthe.SchemaDiff.{
    Diff,
    Diff.DiffSet
  }

  alias Absinthe.SchemaDiff.Introspection.{
    Deprecation,
    Enumeration,
    Field,
    InputObject,
    Object,
    Scalar,
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

  @int %Type{kind: "SCALAR", name: "Int"}
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

  @scalar %Scalar{
    name: "Money"
  }

  @schema %Schema{
    enums: [@enum],
    input_objects: [@input_object],
    objects: [@object],
    scalars: [@scalar],
    unions: [@union]
  }

  describe "diff/2" do
    test "identical structures return an empty diff" do
      assert %DiffSet{} == Diff.diff(@schema, @schema)
      assert %DiffSet{} == Diff.diff(@enum, @enum)
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

    test "changed object fields are reported" do
      %Object{fields: [field | fields]} = existing_object = @object
      new_field = %{field | type: @int}
      new_object = %{existing_object | fields: [new_field | fields]}

      existing_schema = @schema
      new_schema = %{existing_schema | objects: [new_object]}

      assert %DiffSet{
               changes: [
                 %Diff{
                   type: Object,
                   name: "Car",
                   changes: %DiffSet{
                     changes: [
                       %Diff{
                         type: Field,
                         name: "Year",
                         changes: %DiffSet{
                           changes: [
                             %Diff{
                               type: Type,
                               changes: %DiffSet{
                                 additions: ["Int"],
                                 removals: ["non_null(String)"]
                               }
                             }
                           ]
                         }
                       }
                     ]
                   }
                 }
               ]
             } == Diff.diff(@schema, new_schema)

      existing = %Object{
        name: "RootObject",
        fields: [
          %Field{
            name: "myField",
            type: %Type{
              kind: "OBJECT",
              name: "Foo",
              of_type: nil
            }
          }
        ]
      }

      new = %Object{
        name: "RootObject",
        fields: [
          %Field{
            name: "myField",
            type: %Type{
              kind: "OBJECT",
              name: "WrappedFoo",
              of_type: nil
            }
          }
        ]
      }

      assert %DiffSet{
               changes: [
                 %Diff{
                   type: Object,
                   name: "RootObject",
                   changes: %DiffSet{
                     changes: [
                       %Diff{
                         type: Field,
                         name: "myField",
                         changes: %DiffSet{
                           changes: [
                             %Diff{
                               type: Type,
                               name: "Foo",
                               changes: %DiffSet{
                                 additions: ["WrappedFoo"],
                                 removals: ["Foo"]
                               }
                             }
                           ]
                         }
                       }
                     ]
                   }
                 }
               ]
             } == Diff.diff(existing, new)
    end

    test "changes to object field deprecations are reported" do
      %Object{fields: [field | fields]} = existing_object = @object
      new_field = %{field | deprecation: %Deprecation{reason: "old and busted"}}
      new_object = %{existing_object | fields: [new_field | fields]}

      existing_schema = @schema
      new_schema = %{existing_schema | objects: [new_object]}

      assert %DiffSet{
               changes: [
                 %Diff{
                   type: Object,
                   name: "Car",
                   changes: %DiffSet{
                     changes: [
                       %Diff{
                         type: Field,
                         name: "Year",
                         changes: %DiffSet{
                           additions: [
                             %Deprecation{
                               reason: "old and busted",
                             }
                           ]
                         }
                       }
                     ]
                   }
                 }
               ]
             } == Diff.diff(@schema, new_schema)
    end

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

    test "added scalars are reported" do
      new_scalar = %Scalar{name: "Email"}
      existing_schema = @schema
      new_schema = %{existing_schema | scalars: [new_scalar | existing_schema.scalars]}

      assert %DiffSet{
               additions: [
                 %Scalar{name: "Email"}
               ]
             } == Diff.diff(@schema, new_schema)
    end

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
                 %Diff{
                   type: Union,
                   name: "SearchResult",
                   changes: %DiffSet{
                     changes: [
                       %Diff{
                         name: "Car",
                         type: Type,
                         changes: %DiffSet{
                           additions: ["other"],
                           removals: ["object"]
                         }
                       }
                     ]
                   }
                 }
               ]
             } == Diff.diff(@schema, new_schema)
    end
  end
end
