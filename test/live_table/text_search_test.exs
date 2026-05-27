defmodule LiveTable.FilterTest do
  use LiveTable.DataCase
  alias LiveTable.{Catalog.Product, Filter}

  describe "apply_filters/4 text search" do
    test "returns true condition when search term is empty" do
      fields = %{name: %{searchable: true}}
      query = from(p in "products")

      result = Filter.apply_filters(query, %{"search" => ""}, fields)

      assert result == query
    end

    test "applies text search to query in base schema" do
      fields = [
        name: %{searchable: true},
        description: %{searchable: true}
      ]

      query = from(p in "products")
      result = Filter.apply_filters(query, %{"search" => "search term"}, fields)

      assert inspect(result) =~ "ilike(p0.name, ^\"%search term%\")"
      assert inspect(result) =~ "ilike(p0.description, ^\"%search term%\")"
    end

    test "supports lower-like mode for case-insensitive search" do
      fields = [
        name: %{searchable: true}
      ]

      query = from(p in "products")
      result = Filter.apply_filters(query, %{"search" => "Search Term"}, fields, :like_lower)
      inspected = inspect(result)

      assert inspected =~ "lower(?) LIKE ?"
      assert inspected =~ "%search term%"
    end

    test "applies text search to joined query" do
      query =
        from p0 in Product,
          as: :resource,
          left_join: s1 in assoc(p0, :suppliers),
          as: :suppliers,
          left_join: c2 in assoc(p0, :category),
          as: :category,
          select: %{
            name: p0.name,
            supplier_name: s1.name,
            category_name: c2.name
          }

      fields = [
        name: %{searchable: true},
        supplier_name: %{assoc: {:suppliers, :name}, searchable: true},
        category_name: %{assoc: {:category, :name}, searchable: true}
      ]

      filters = %{"search" => "search term"}
      result = Filter.apply_filters(query, filters, fields)

      assert inspect(result) =~ "ilike(p0.name, ^\"%search term%\")"
      assert inspect(result) =~ "ilike(s1.name, ^\"%search term%\")"
      assert inspect(result) =~ "ilike(c2.name, ^\"%search term%\")"
    end

    test "doesn't apply search to non-searchable column" do
      fields = [
        name: %{searchable: true},
        description: %{searchable: false}
      ]

      query = from(p in "products")
      result = Filter.apply_filters(query, %{"search" => "search term"}, fields)

      assert inspect(result) =~ "ilike(p0.name, ^\"%search term%\")"
      refute inspect(result) =~ "ilike(p0.description, ^\"%search term%\")"
    end
  end
end
