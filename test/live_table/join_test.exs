defmodule LiveTable.JoinTest do
  use LiveTable.DataCase
  alias LiveTable.Join
  alias LiveTable.Catalog.Product
  import Ecto.Query

  describe "primary_key/1" do
    test "comes from the query's root schema" do
      assert Join.primary_key(from(p in Product)) == [:id]
      assert Join.primary_key(from(p in "products")) == [:id]
    end
  end

  describe "join_associations/2" do
    test "adds no joins when filters have no associations" do
      filters = %{
        "name" => %{field: :name},
        "price" => %{field: :price}
      }

      query = from(p in Product, as: :resource)
      result = Join.join_associations(query, filters)

      # Should have no joins
      refute inspect(result) =~ "join:"
    end

    test "adds single join for association field" do
      filters = %{
        "category_name" => %{field: {:category, :name}}
      }

      query = from(p in Product, as: :resource)
      result = Join.join_associations(query, filters)

      assert inspect(result) =~ "left_join:"
      assert inspect(result) =~ "assoc(p0, :category)"
      assert inspect(result) =~ "as: :category"
    end

    test "adds multiple joins for different associations" do
      filters = %{
        "category_name" => %{field: {:category, :name}},
        "supplier_name" => %{field: {:suppliers, :name}}
      }

      query = from(p in Product, as: :resource)
      result = Join.join_associations(query, filters)

      assert inspect(result) =~ "assoc(p0, :category)"
      assert inspect(result) =~ "as: :category"
      assert inspect(result) =~ "assoc(p0, :suppliers)"
      assert inspect(result) =~ "as: :suppliers"
    end

    test "doesn't duplicate joins for same association" do
      filters = %{
        "supplier_name" => %{field: {:suppliers, :name}},
        "supplier_contact" => %{field: {:suppliers, :contact_info}}
      }

      query = from(p in Product, as: :resource)
      result = Join.join_associations(query, filters)

      # Count occurrences of supplier join
      query_string = inspect(result)

      supplier_join_count =
        query_string
        |> String.split("assoc(p0, :suppliers)")
        |> length()
        |> Kernel.-(1)

      # Should only have one join for suppliers
      assert supplier_join_count == 1
    end

    test "handles mixed regular and association fields" do
      filters = %{
        "name" => %{field: :name},
        "category_name" => %{field: {:category, :name}},
        "price" => %{field: :price},
        "supplier_name" => %{field: {:suppliers, :name}}
      }

      query = from(p in Product, as: :resource)
      result = Join.join_associations(query, filters)

      assert inspect(result) =~ "assoc(p0, :category)"
      assert inspect(result) =~ "assoc(p0, :suppliers)"
    end

    test "handles nil and invalid filter structures gracefully" do
      filters = %{
        "name" => %{field: :name},
        "invalid" => %{},
        "nil_field" => nil,
        "category_name" => %{field: {:category, :name}}
      }

      query = from(p in Product, as: :resource)
      result = Join.join_associations(query, filters)

      # Should only add join for category
      assert inspect(result) =~ "assoc(p0, :category)"
      refute inspect(result) =~ "assoc(p0, :invalid)"
    end

    test "preserves existing query conditions" do
      filters = %{
        "category_name" => %{field: {:category, :name}}
      }

      query = from(p in Product, as: :resource, where: p.price > 100)
      result = Join.join_associations(query, filters)

      # Should preserve the where clause
      assert inspect(result) =~ "where:"
      assert inspect(result) =~ "price > 100"
      # And add the join
      assert inspect(result) =~ "assoc(p0, :category)"
    end

    test "works with string-based schema references" do
      filters = %{
        "category_name" => %{field: {:category, :name}}
      }

      query = from(p in "products", as: :resource)
      result = Join.join_associations(query, filters)

      assert inspect(result) =~ "left_join:"
      assert inspect(result) =~ "assoc(p0, :category)"
    end
  end

  describe "select_columns/2" do
    test "selects regular fields without associations" do
      fields = %{
        name: %{},
        price: %{}
      }

      query = from(p in Product, as: :resource)
      result = Join.select_columns(query, fields)

      assert inspect(result) =~ "select:"
      assert inspect(result) =~ "%{"
      assert inspect(result) =~ "name: "
      assert inspect(result) =~ "price: "
    end

    test "selects computed fields using dynamic expressions" do
      fields = %{
        name: %{},
        total_value: %{
          computed: dynamic([resource: r], r.price * r.stock_quantity)
        }
      }

      query = from(p in Product, as: :resource)
      result = Join.select_columns(query, fields)

      assert inspect(result) =~ "select:"
      assert inspect(result) =~ "name: "
      assert inspect(result) =~ "total_value: "
    end

    test "handles empty fields map" do
      fields = %{}

      query = from(p in Product, as: :resource)
      result = Join.select_columns(query, fields)

      assert inspect(result) =~ "select: %{id: p0.id}"
    end

    test "preserves field order in select" do
      fields = %{
        zebra: %{},
        alpha: %{},
        beta: %{}
      }

      query = from(p in Product, as: :resource)
      result = Join.select_columns(query, fields)

      # The fields should be in the select
      assert inspect(result) =~ "zebra:"
      assert inspect(result) =~ "alpha:"
      assert inspect(result) =~ "beta:"
    end

    test "handles mixed regular and computed fields" do
      fields = %{
        name: %{},
        price: %{},
        discounted_price: %{
          computed: dynamic([resource: r], r.price * 0.9)
        },
        in_stock: %{
          computed: dynamic([resource: r], r.stock_quantity > 0)
        }
      }

      query = from(p in Product, as: :resource)
      result = Join.select_columns(query, fields)

      assert inspect(result) =~ "name:"
      assert inspect(result) =~ "price:"
      assert inspect(result) =~ "discounted_price:"
      assert inspect(result) =~ "in_stock:"
    end

    test "works with existing where clauses" do
      fields = %{
        name: %{},
        price: %{}
      }

      query = from(p in Product, as: :resource, where: p.price > 50)
      result = Join.select_columns(query, fields)

      # Should preserve the where clause
      assert inspect(result) =~ "where:"
      # And add the select
      assert inspect(result) =~ "select:"
    end

    test "handles nil and invalid field configurations" do
      fields = %{
        name: %{},
        nil_field: nil,
        empty_field: %{},
        computed_field: %{computed: dynamic([resource: r], r.price * 2)}
      }

      query = from(p in Product, as: :resource)
      # Should not raise an error
      result = Join.select_columns(query, fields)

      assert inspect(result) =~ "name:"
      assert inspect(result) =~ "computed_field:"
    end
  end

  describe "integration scenarios" do
    test "handles complex query with multiple associations and computed fields" do
      # This simulates how the functions work together in LiveTable
      filters = %{
        "category_filter" => %{field: {:category, :name}},
        "supplier_filter" => %{field: {:suppliers, :name}}
      }

      fields = %{
        name: %{},
        price: %{},
        total_value: %{
          computed: dynamic([resource: r], r.price * r.stock_quantity)
        }
      }

      query = from(p in Product, as: :resource)

      result =
        query
        |> Join.join_associations(filters)
        |> Join.select_columns(fields)

      # Should have both joins
      assert inspect(result) =~ "assoc(p0, :category)"
      assert inspect(result) =~ "assoc(p0, :suppliers)"

      # Should have all fields in select
      assert inspect(result) =~ "name:"
      assert inspect(result) =~ "price:"
      assert inspect(result) =~ "total_value:"
    end

    test "handles query with no associations needed" do
      filters = %{
        "name" => %{field: :name},
        "price" => %{field: :price}
      }

      fields = %{
        id: %{},
        name: %{},
        price: %{}
      }

      query = from(p in Product, as: :resource, where: p.active == true)

      result =
        query
        |> Join.join_associations(filters)
        |> Join.select_columns(fields)

      # Should have no joins
      refute inspect(result) =~ "join:"

      # Should have select
      assert inspect(result) =~ "select:"
      assert inspect(result) =~ "id:"
      assert inspect(result) =~ "name:"
      assert inspect(result) =~ "price:"

      # Should preserve where clause
      assert inspect(result) =~ "where:"
      assert inspect(result) =~ "active == true"
    end

    test "works with limit and order_by clauses" do
      filters = %{
        "category_name" => %{field: {:category, :name}}
      }

      fields = %{
        name: %{},
        price: %{}
      }

      query =
        from(p in Product,
          as: :resource,
          order_by: [desc: p.created_at],
          limit: 10
        )

      result =
        query
        |> Join.join_associations(filters)
        |> Join.select_columns(fields)

      # Should preserve all query parts
      assert inspect(result) =~ "order_by:"
      assert inspect(result) =~ "limit:"
      assert inspect(result) =~ "join:"
      assert inspect(result) =~ "select:"
    end
  end

  describe "edge cases" do
    test "handles deeply nested field names" do
      filters = %{
        "very_long_association_field_name" => %{field: {:category, :very_long_field_name}}
      }

      query = from(p in Product, as: :resource)
      result = Join.join_associations(query, filters)

      assert inspect(result) =~ "assoc(p0, :category)"
    end

    test "handles atom field names" do
      fields = %{
        field_with_underscore: %{},
        field_with_number_123: %{}
      }

      query = from(p in Product, as: :resource)
      # Should not raise an error
      result = Join.select_columns(query, fields)

      assert result
    end

    test "empty filters and fields" do
      query = from(p in Product, as: :resource)

      # Should not modify query with empty filters
      result1 = Join.join_associations(query, %{})
      refute inspect(result1) =~ "join:"

      # Selects only the primary key with empty fields
      result2 = Join.select_columns(query, %{})
      assert inspect(result2) =~ "select: %{id: p0.id}"
    end
  end
end
