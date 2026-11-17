defmodule OstaraTest do
  use ExUnit.Case
  alias Ostara.Schemas.{Product, Sheet}

  doctest Ostara

  # Test schema based on https://json-schema.org/learn/getting-started-step-by-step.html
  describe "transmute/1" do
    test "produces the correct schema" do
      assert %{
               "$schema" => "https://json-schema.org/draft/2020-12/schema",
               "$id" => "product",
               "title" => "Product",
               "type" => "object",
               "description" => "A product from Acme's catalog",
               "properties" => %{
                 "product_id" => %{
                   "type" => "integer"
                 },
                 "product_name" => %{
                   "type" => "string"
                 },
                 "price" => %{
                   "type" => "number",
                   "exclusiveMinimum" => 0
                 },
                 "tags" => %{
                   "type" => "array",
                   "items" => %{
                     "type" => "string"
                   },
                   "minItems" => 1
                 },
                 "dimensions" => %{
                   "title" => "Dimensions",
                   "type" => "object",
                   "properties" => %{
                     "length" => %{
                       "type" => "number"
                     },
                     "width" => %{
                       "type" => "number"
                     },
                     "height" => %{
                       "type" => "number"
                     }
                   },
                   "required" => Enum.sort(["length", "width", "height"])
                 },
                 "reviews" => %{
                   "type" => "array",
                   "items" => %{
                     "title" => "Review",
                     "type" => "object",
                     "properties" => %{
                       "author" => %{
                         "type" => "string"
                       },
                       "rating" => %{
                         "type" => "integer",
                         "exclusiveMinimum" => 0,
                         "maximum" => 5
                       }
                     },
                     "required" => ["rating"]
                   }
                 }
               },
               "required" => Enum.sort(["dimensions", "product_id", "product_name", "price"])
             } == Ostara.transmute(Product)
    end

    # test "generates JSON data" do
    #   assert Ostara.transmute(Product, format: :json) =~ ~s("title": "Product")
    # end
  end

  describe "transmute/2 with refs: true" do
    test "replaces embeds_one with a $ref pointer" do
      schema = Ostara.transmute(Product, refs: true)
      assert %{"$ref" => "#/$defs/Dimensions"} == get_in(schema, ["properties", "dimensions"])
    end

    test "replaces embeds_many items with a $ref pointer" do
      schema = Ostara.transmute(Product, refs: true)

      assert %{"type" => "array", "items" => %{"$ref" => "#/$defs/Review"}} ==
               get_in(schema, ["properties", "reviews"])
    end

    test "collects embedded schemas into $defs" do
      schema = Ostara.transmute(Product, refs: true)
      defs = Map.fetch!(schema, "$defs")

      assert %{"title" => "Dimensions", "type" => "object"} = defs["Dimensions"]
      assert %{"title" => "Review", "type" => "object"} = defs["Review"]
    end

    test "does not add $defs when there are no embedded schemas" do
      schema = Ostara.transmute(Ostara.Schemas.Dimensions, refs: true)
      refute Map.has_key?(schema, "$defs")
    end
  end

  describe "transmute/2 with :only / :except" do
    test ":only keeps just the whitelisted properties and required entries" do
      schema = Ostara.transmute(Product, only: [:product_name, :price])
      assert Enum.sort(Map.keys(schema["properties"])) == ["price", "product_name"]
      assert Enum.all?(schema["required"] || [], &(&1 in ["price", "product_name"]))
    end

    test ":only accepts strings" do
      schema = Ostara.transmute(Product, only: ["product_name"])
      assert Map.keys(schema["properties"]) == ["product_name"]
    end

    test "excluded embeds do not appear in $defs" do
      schema = Ostara.transmute(Product, only: [:product_name, :dimensions], refs: true)
      assert Map.keys(schema["$defs"]) == ["Dimensions"]
    end

    test ":except removes properties" do
      schema = Ostara.transmute(Product, except: [:dimensions, :reviews], refs: true)
      refute Map.has_key?(schema["properties"], "dimensions")
      refute Map.has_key?(schema, "$defs")
    end

    test ":only raises on unknown fields" do
      assert_raise ArgumentError, ~r/unknown fields/, fn ->
        Ostara.transmute(Product, only: [:nope])
      end
    end
  end

  describe "transmute/1 with Veilgen resources" do
    test "it works with a sheet" do
      assert %{
               "$id" => "sheet",
               "$schema" => "https://json-schema.org/draft/2020-12/schema",
               "description" => "A Character Sheet that we can save.",
               "properties" => %{
                 "alignment" => %{"type" => "string"},
                 "background_key" => %{"type" => "string"},
                 "character_class" => %{
                   "description" =>
                     "Embedded schema for storing a character's class information.",
                   "properties" => %{
                     "ability_proficiency" => %{"type" => "string"},
                     "class_key" => %{"type" => "string"},
                     "level" => %{"type" => "integer"},
                     "proficiency_bonus" => %{"type" => "string"},
                     "save_proficiency" => %{"type" => "string"},
                     "subclass_key" => %{"type" => "string"}
                   },
                   "required" => ["class_key", "level"],
                   "title" => "CharacterClass",
                   "type" => "object"
                 },
                 "class_key" => %{"type" => "string"},
                 "created_at" => %{"format" => "date-time", "type" => "string"},
                 "gender" => %{"type" => "string"},
                 "name" => %{"maxLength" => 20, "minLength" => 1, "type" => "string"},
                 "player_name" => %{"maxLength" => 40, "minLength" => 1, "type" => "string"},
                 "race_key" => %{"type" => "string"},
                 "revision" => %{"type" => "integer"},
                 "sheet_id" => %{"type" => "string"},
                 "tags" => %{"items" => %{"type" => "string"}, "type" => "array"},
                 "transforms" => %{"items" => %{}, "type" => "array"},
                 "type" => %{"const" => "sheet", "type" => "string"},
                 "updated_at" => %{"format" => "date-time", "type" => "string"}
               },
               "required" => ["sheet_id"],
               "title" => "Sheet",
               "type" => "object"
             } = Ostara.transmute(Sheet)
    end
  end
end
