defmodule Absinthe.SchemaDiff.ReportTest do
  use ExUnit.Case

  alias Absinthe.SchemaDiff.{
    Diff,
    Diff.DiffSet,
    Report
  }

  alias Absinthe.SchemaDiff.Introspection.{
    Deprecation,
    Enumeration,
    Field,
    InputObject,
    Object,
    Scalar,
    Type,
    Union
  }

  @nullable_string %Type{kind: "SCALAR", name: "String"}
  @required_string %Type{kind: "NON_NULL", of_type: %Type{kind: "SCALAR", name: "String"}}

  describe "diff/2" do
    test "empty diffset reports 'no changes'" do
      assert_report_output(%DiffSet{}, "no changes")
    end

    test "reporting added enum" do
      diff_set = %DiffSet{
        additions: [
          %Enumeration{
            name: "Shapes",
            values: [
              %Field{name: "Square", type: nil},
              %Field{name: "Circle", type: nil},
              %Field{name: "Triangle", type: nil}
            ]
          }
        ]
      }

      assert_report_output(
        diff_set,
        """
        Additions:
          Enum Shapes
            Values:
              Square
              Circle
              Triangle
        """
      )
    end

    test "reporting removed enum" do
      diff_set = %DiffSet{
        removals: [
          %Enumeration{
            name: "Shapes",
            values: [
              %Field{name: "Square", type: nil},
              %Field{name: "Circle", type: nil},
              %Field{name: "Triangle", type: nil}
            ]
          }
        ]
      }

      assert_report_output(
        diff_set,
        """
        Removals:
          Enum Shapes
            Values:
              Square
              Circle
              Triangle
        """
      )
    end

    test "reporting added enum member" do
      diff_set = %DiffSet{
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
      }

      assert_report_output(
        diff_set,
        """
        Changes:
          Enum Colors
            Additions:
              Violet
        """
      )
    end

    test "reporting removed enum member" do
      diff_set = %DiffSet{
        changes: [
          %Diff{
            type: Enumeration,
            name: "Colors",
            changes: %DiffSet{
              removals: [
                %Field{name: "Red", type: nil}
              ]
            }
          }
        ]
      }

      assert_report_output(
        diff_set,
        """
        Changes:
          Enum Colors
            Removals:
              Red
        """
      )
    end

    test "reporting added objects" do
      diff_set = %DiffSet{
        additions: [
          %Object{
            name: "Movie",
            fields: [
              %Field{name: "Year", type: @required_string},
              %Field{name: "Title", type: @nullable_string},
              %Field{name: "Genre", type: @nullable_string}
            ]
          }
        ]
      }

      assert_report_output(
        diff_set,
        """
        Additions:
          Object Movie
            Fields:
              Year non_null(String)
              Title String
              Genre String
        """
      )
    end

    test "reporting removed objects" do
      diff_set = %DiffSet{
        removals: [
          %Object{
            name: "Movie",
            fields: [
              %Field{
                name: "Year",
                type: %Type{kind: "NON_NULL", of_type: %Type{kind: "SCALAR", name: "String"}}
              },
              %Field{name: "Title", type: %Type{kind: "SCALAR", name: "String"}},
              %Field{name: "Genre", type: %Type{kind: "SCALAR", name: "String"}}
            ]
          }
        ]
      }

      assert_report_output(
        diff_set,
        """
        Removals:
          Object Movie
            Fields:
              Year non_null(String)
              Title String
              Genre String
        """
      )
    end

    test "reporting removed object fields" do
      diff_set = %DiffSet{
        changes: [
          %Diff{
            type: Object,
            name: "Car",
            changes: %DiffSet{
              removals: [
                %Field{
                  name: "Year",
                  type: %Type{kind: "NON_NULL", of_type: %Type{kind: "SCALAR", name: "String"}}
                }
              ]
            }
          }
        ]
      }

      assert_report_output(
        diff_set,
        """
        Changes:
          Object Car
            Removals:
              Year non_null(String)
        """
      )
    end

    test "changed object fields are reported" do
      diff_set = %DiffSet{
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
      }

      assert_report_output(
        diff_set,
        """
        Changes:
          Object Car
            Changes:
              Field Year
                Changes:
                  type changed from "non_null(String)" to "Int"
        """
      )
    end

    test "reporting deprecations to object fields" do
      diff_set = %DiffSet{
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
                        reason: "old and busted"
                      }
                    ]
                  }
                }
              ]
            }
          }
        ]
      }

      assert_report_output(
        diff_set,
        """
        Changes:
          Object Car
            Changes:
              Field Year
                Additions:
                  DEPRECATED - old and busted
        """
      )
    end

    test "reporting deprecation removal from object fields" do
      diff_set = %DiffSet{
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
                    removals: [
                      %Deprecation{
                        reason: "old and busted"
                      }
                    ]
                  }
                }
              ]
            }
          }
        ]
      }

      assert_report_output(
        diff_set,
        """
        Changes:
          Object Car
            Changes:
              Field Year
                Removals:
                  DEPRECATED - old and busted
        """
      )
    end

    test "reporting added input objects" do
      diff_set = %DiffSet{
        additions: [
          %InputObject{
            name: "Movie",
            fields: [
              %Field{name: "Year", type: @required_string},
              %Field{name: "Title", type: @nullable_string},
              %Field{name: "Genre", type: @nullable_string}
            ]
          }
        ]
      }

      assert_report_output(
        diff_set,
        """
        Additions:
          InputObject Movie
            Fields:
              Year non_null(String)
              Title String
              Genre String
        """
      )
    end

    test "reporting removed input objects" do
      diff_set = %DiffSet{
        removals: [
          %InputObject{
            name: "Movie",
            fields: [
              %Field{name: "Year", type: @required_string},
              %Field{name: "Title", type: @nullable_string},
              %Field{name: "Genre", type: @nullable_string}
            ]
          }
        ]
      }

      assert_report_output(
        diff_set,
        """
        Removals:
          InputObject Movie
            Fields:
              Year non_null(String)
              Title String
              Genre String
        """
      )
    end

    test "reporting added input object fields" do
      diff_set = %DiffSet{
        changes: [
          %Diff{
            type: InputObject,
            name: "FormInput",
            changes: %DiffSet{
              additions: [
                %Field{name: "Color", type: @nullable_string}
              ]
            }
          }
        ]
      }

      assert_report_output(
        diff_set,
        """
        Changes:
          InputObject FormInput
            Additions:
              Color String
        """
      )
    end

    test "reporting removed input object fields" do
      diff_set = %DiffSet{
        changes: [
          %Diff{
            type: InputObject,
            name: "FormInput",
            changes: %DiffSet{
              removals: [
                %Field{name: "Color", type: @nullable_string}
              ]
            }
          }
        ]
      }

      assert_report_output(
        diff_set,
        """
        Changes:
          InputObject FormInput
            Removals:
              Color String
        """
      )
    end

    test "reporting added scalars" do
      diff_set = %DiffSet{
        additions: [
          %Scalar{name: "Email"}
        ]
      }

      assert_report_output(
        diff_set,
        """
        Additions:
          Email Scalar
        """
      )
    end

    test "reporting added unions" do
      diff_set = %DiffSet{
        additions: [
          %Union{
            name: "Life",
            possible_types: [
              %Type{kind: "OBJECT", name: "Plant"},
              %Type{kind: "OBJECT", name: "Animal"}
            ]
          }
        ]
      }

      assert_report_output(
        diff_set,
        """
        Additions:
          Union Life
            Possible Types:
              Plant object
              Animal object
        """
      )
    end

    test "reporting removed unions" do
      diff_set = %DiffSet{
        removals: [
          %Union{
            name: "Life",
            possible_types: [
              %Type{kind: "OBJECT", name: "Plant"},
              %Type{kind: "OBJECT", name: "Animal"}
            ]
          }
        ]
      }

      assert_report_output(
        diff_set,
        """
        Removals:
          Union Life
            Possible Types:
              Plant object
              Animal object
        """
      )
    end

    test "reporting added typs in unions" do
      diff_set = %DiffSet{
        changes: [
          %Diff{
            type: Union,
            name: "SearchResult",
            changes: %DiffSet{
              additions: [
                %Type{kind: "OBJECT", name: "Guitar"}
              ]
            }
          }
        ]
      }

      assert_report_output(
        diff_set,
        """
        Changes:
          Union SearchResult
            Additions:
              Guitar object
        """
      )
    end

    test "reporting removed types in unions" do
      diff_set = %DiffSet{
        changes: [
          %Diff{
            type: Union,
            name: "SearchResult",
            changes: %DiffSet{
              removals: [
                %Type{kind: "OBJECT", name: "Guitar"}
              ]
            }
          }
        ]
      }

      assert_report_output(
        diff_set,
        """
        Changes:
          Union SearchResult
            Removals:
              Guitar object
        """
      )
    end

    test "reporting changed types in unions" do
      diff_set = %DiffSet{
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
      }

      assert_report_output(
        diff_set,
        """
        Changes:
          Union SearchResult
            Changes:
              Car type changed from "object" to "other"
        """
      )
    end
  end

  defp assert_report_output(diff_set, expected_output) do
    color_output =
      diff_set
      |> Report.report()
      |> Enum.join()

    plain_output =
      diff_set
      |> Report.report(%Report.Formatter{color: false})
      |> Enum.join()

    assert remove_ansi_sequences(color_output) == plain_output

    regex =
      expected_output
      |> String.replace("(", "\\(")
      |> String.replace(")", "\\)")
      |> Regex.compile!()

    assert plain_output =~ regex
  end

  @ansi_regex [
                IO.ANSI.cyan(),
                IO.ANSI.green(),
                IO.ANSI.light_black(),
                IO.ANSI.magenta(),
                IO.ANSI.red(),
                IO.ANSI.reset(),
                IO.ANSI.yellow()
              ]
              |> Enum.map_join("|", &Regex.escape/1)
              |> Regex.compile!()

  defp remove_ansi_sequences(string) do
    Regex.replace(@ansi_regex, string, "")
  end
end
