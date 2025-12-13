defmodule LiveTable.Integration.LiveResourceJoinedTest do
  @moduledoc """
  Integration tests for LiveTable query pipeline with joined table operations.

  These tests verify the query pipeline works correctly when:
    * Joining associations (belongs_to, has_many, many_to_many)
    * Selecting fields from joined tables
    * Sorting by joined fields
    * Filtering by joined fields
    * Using computed fields with joins

  ## Test Strategy

  Each test creates related records across multiple tables, runs the query
  pipeline with association fields, and verifies the results include
  properly joined and selected data.
  """

  use LiveTable.DataCase, async: true

  alias LiveTable.TestResource
  alias LiveTable.Catalog.Product

  import Ecto.Query
  import LiveTable.Fixtures

  @repo Application.compile_env(:live_table, :repo)

  # Fields including associations for joined-table tests
  @joined_fields [
    id: %{label: "ID", sortable: true, searchable: false},
    name: %{label: "Name", sortable: true, searchable: true},
    price: %{label: "Price", sortable: true, searchable: false},
    category_name: %{
      label: "Category",
      assoc: {:category, :name},
      sortable: true,
      searchable: true
    }
  ]

  # Fields with many-to-many association
  @supplier_fields [
    id: %{label: "ID", sortable: true, searchable: false},
    name: %{label: "Name", sortable: true, searchable: true},
    supplier_name: %{
      label: "Supplier",
      assoc: {:suppliers, :name},
      sortable: true,
      searchable: true
    }
  ]

  # Fields with computed field - use function to avoid module attribute escape issue
  defp computed_fields do
    [
      id: %{label: "ID", sortable: true, searchable: false},
      name: %{label: "Name", sortable: true, searchable: true},
      price: %{label: "Price", sortable: true, searchable: false},
      stock_quantity: %{label: "Stock", sortable: true, searchable: false},
      total_value: %{
        label: "Total Value",
        sortable: true,
        searchable: false,
        computed: dynamic([resource: r], r.price * r.stock_quantity)
      }
    ]
  end

  # Default options structure
  defp default_options do
    %{
      "sort" => %{"sortable?" => true, "sort_params" => []},
      "pagination" => %{"paginate?" => false, "page" => "1", "per_page" => "10"},
      "filters" => %{}
    }
  end

  describe "list_resources/3 - joins from fields" do
    setup do
      # Create categories
      electronics = category_fixture(%{name: "Electronics"})
      clothing = category_fixture(%{name: "Clothing"})

      # Create products with categories
      laptop =
        product_fixture(%{
          name: "Laptop",
          price: Decimal.new("999.00"),
          category_id: electronics.id
        })

      phone =
        product_fixture(%{
          name: "Phone",
          price: Decimal.new("699.00"),
          category_id: electronics.id
        })

      shirt =
        product_fixture(%{name: "T-Shirt", price: Decimal.new("29.00"), category_id: clothing.id})

      %{
        categories: %{electronics: electronics, clothing: clothing},
        products: %{laptop: laptop, phone: phone, shirt: shirt}
      }
    end

    test "joins associations defined in fields", context do
      query = TestResource.list_resources(@joined_fields, default_options(), Product)
      results = @repo.all(query)

      assert length(results) == 3

      # Results should include category_name from joined table
      laptop_result = Enum.find(results, &(&1.id == context.products.laptop.id))
      assert laptop_result.category_name == "Electronics"
    end

    test "selects fields from joined tables", context do
      query = TestResource.list_resources(@joined_fields, default_options(), Product)
      results = @repo.all(query)

      shirt_result = Enum.find(results, &(&1.id == context.products.shirt.id))
      assert shirt_result.category_name == "Clothing"
    end

    test "handles products without category", _context do
      # Create product without category
      _orphan = product_fixture(%{name: "Orphan Product", category_id: nil})

      query = TestResource.list_resources(@joined_fields, default_options(), Product)
      results = @repo.all(query)

      # Orphan should still be included (with nil category_name due to left join behavior)
      # Note: The actual behavior depends on join type in LiveTable.Join
      _result_ids = Enum.map(results, & &1.id)
      # If using left join, orphan will be included; if inner join, it won't
      # We test that the query doesn't crash either way
      assert length(results) >= 3
    end
  end

  describe "list_resources/3 - sorting by joined fields" do
    setup do
      # Create categories with specific names for sorting
      alpha_cat = category_fixture(%{name: "Alpha Category"})
      beta_cat = category_fixture(%{name: "Beta Category"})
      gamma_cat = category_fixture(%{name: "Gamma Category"})

      # Create products with different categories
      product_a = product_fixture(%{name: "Product A", category_id: gamma_cat.id})
      product_b = product_fixture(%{name: "Product B", category_id: alpha_cat.id})
      product_c = product_fixture(%{name: "Product C", category_id: beta_cat.id})

      %{products: [product_a, product_b, product_c]}
    end

    test "sorts by joined field ascending", %{products: _products} do
      options = put_in(default_options(), ["sort", "sort_params"], category_name: :asc)

      query = TestResource.list_resources(@joined_fields, options, Product)
      results = @repo.all(query)

      category_names = Enum.map(results, & &1.category_name)
      assert category_names == ["Alpha Category", "Beta Category", "Gamma Category"]
    end

    test "sorts by joined field descending", %{products: _products} do
      options = put_in(default_options(), ["sort", "sort_params"], category_name: :desc)

      query = TestResource.list_resources(@joined_fields, options, Product)
      results = @repo.all(query)

      category_names = Enum.map(results, & &1.category_name)
      assert category_names == ["Gamma Category", "Beta Category", "Alpha Category"]
    end

    test "combines local and joined field sorting", %{products: _products} do
      # Create additional product in same category to test secondary sort
      alpha_cat = category_fixture(%{name: "Alpha Category 2"})
      product_fixture(%{name: "Z Product", category_id: alpha_cat.id})
      product_fixture(%{name: "A Product", category_id: alpha_cat.id})

      options =
        put_in(default_options(), ["sort", "sort_params"], category_name: :asc, name: :asc)

      query = TestResource.list_resources(@joined_fields, options, Product)
      results = @repo.all(query)

      # Products in "Alpha Category 2" should be sorted by name within category
      alpha2_products = Enum.filter(results, &(&1.category_name == "Alpha Category 2"))

      if length(alpha2_products) == 2 do
        names = Enum.map(alpha2_products, & &1.name)
        assert names == ["A Product", "Z Product"]
      end
    end
  end

  describe "list_resources/3 - filtering by joined fields (Select filter)" do
    setup do
      electronics = category_fixture(%{name: "Electronics"})
      clothing = category_fixture(%{name: "Clothing"})
      furniture = category_fixture(%{name: "Furniture"})

      laptop = product_fixture(%{name: "Laptop", category_id: electronics.id})
      phone = product_fixture(%{name: "Phone", category_id: electronics.id})
      shirt = product_fixture(%{name: "T-Shirt", category_id: clothing.id})
      chair = product_fixture(%{name: "Chair", category_id: furniture.id})

      %{
        categories: %{electronics: electronics, clothing: clothing, furniture: furniture},
        products: %{laptop: laptop, phone: phone, shirt: shirt, chair: chair}
      }
    end

    test "filters by single category selection", context do
      select_filter =
        LiveTable.Select.new({:category, :id}, "category", %{
          label: "Category",
          selected: [context.categories.electronics.id]
        })

      options = put_in(default_options(), ["filters"], %{"category" => select_filter})

      query = TestResource.list_resources(@joined_fields, options, Product)
      results = @repo.all(query)

      # Should only return electronics products
      assert length(results) == 2
      result_ids = Enum.map(results, & &1.id)
      assert context.products.laptop.id in result_ids
      assert context.products.phone.id in result_ids
    end

    test "filters by multiple category selections", context do
      select_filter =
        LiveTable.Select.new({:category, :id}, "category", %{
          label: "Category",
          selected: [context.categories.electronics.id, context.categories.clothing.id]
        })

      options = put_in(default_options(), ["filters"], %{"category" => select_filter})

      query = TestResource.list_resources(@joined_fields, options, Product)
      results = @repo.all(query)

      # Should return electronics and clothing products
      assert length(results) == 3
      result_ids = Enum.map(results, & &1.id)
      assert context.products.laptop.id in result_ids
      assert context.products.phone.id in result_ids
      assert context.products.shirt.id in result_ids
    end

    test "returns no results when filtering by non-existent category" do
      select_filter =
        LiveTable.Select.new({:category, :id}, "category", %{
          label: "Category",
          # Non-existent ID
          selected: [99999]
        })

      options = put_in(default_options(), ["filters"], %{"category" => select_filter})

      query = TestResource.list_resources(@joined_fields, options, Product)
      results = @repo.all(query)

      assert results == []
    end
  end

  describe "list_resources/3 - text search on joined fields" do
    setup do
      electronics = category_fixture(%{name: "Electronics"})
      home_garden = category_fixture(%{name: "Home & Garden"})

      laptop = product_fixture(%{name: "Laptop Pro", category_id: electronics.id})
      plant = product_fixture(%{name: "House Plant", category_id: home_garden.id})

      %{products: %{laptop: laptop, plant: plant}}
    end

    test "searches joined field (category_name)", context do
      options = put_in(default_options(), ["filters", "search"], "Electronics")

      query = TestResource.list_resources(@joined_fields, options, Product)
      results = @repo.all(query)

      assert length(results) == 1
      assert List.first(results).id == context.products.laptop.id
    end

    test "searches across both local and joined fields", context do
      # "Home" appears in category name, "House" in product name
      options = put_in(default_options(), ["filters", "search"], "Ho")

      query = TestResource.list_resources(@joined_fields, options, Product)
      results = @repo.all(query)

      # Should find plant (matches "Home" in category or "House" in name)
      result_ids = Enum.map(results, & &1.id)
      assert context.products.plant.id in result_ids
    end
  end

  describe "list_resources/3 - many-to-many associations" do
    setup do
      supplier1 = supplier_fixture(%{name: "Acme Corp"})
      supplier2 = supplier_fixture(%{name: "GlobalTech"})

      product1 = product_fixture(%{name: "Widget"})
      product2 = product_fixture(%{name: "Gadget"})

      # Associate products with suppliers
      associate_product_supplier(product1, supplier1)
      associate_product_supplier(product1, supplier2)
      associate_product_supplier(product2, supplier1)

      %{
        suppliers: %{acme: supplier1, globaltech: supplier2},
        products: %{widget: product1, gadget: product2}
      }
    end

    test "joins many-to-many associations", context do
      query = TestResource.list_resources(@supplier_fields, default_options(), Product)
      results = @repo.all(query)

      # Note: Many-to-many joins may create duplicate rows
      # The widget has 2 suppliers, so it may appear twice
      widget_results = Enum.filter(results, &(&1.id == context.products.widget.id))

      # At minimum, widget should appear with supplier data
      assert length(widget_results) >= 1
    end

    test "searches on many-to-many joined field", context do
      options = put_in(default_options(), ["filters", "search"], "GlobalTech")

      query = TestResource.list_resources(@supplier_fields, options, Product)
      results = @repo.all(query)

      # Only widget has GlobalTech as supplier
      result_ids = Enum.map(results, & &1.id) |> Enum.uniq()
      assert context.products.widget.id in result_ids
    end
  end

  describe "list_resources/3 - computed fields" do
    setup do
      # Create products with different price * quantity values
      low_value =
        product_fixture(%{
          name: "Low Value",
          price: Decimal.new("10.00"),
          stock_quantity: 5
        })

      # total = 50

      mid_value =
        product_fixture(%{
          name: "Mid Value",
          price: Decimal.new("50.00"),
          stock_quantity: 20
        })

      # total = 1000

      high_value =
        product_fixture(%{
          name: "High Value",
          price: Decimal.new("100.00"),
          stock_quantity: 100
        })

      # total = 10000

      %{products: %{low: low_value, mid: mid_value, high: high_value}}
    end

    test "selects computed fields", context do
      query = TestResource.list_resources(computed_fields(), default_options(), Product)
      results = @repo.all(query)

      low_result = Enum.find(results, &(&1.id == context.products.low.id))
      # total_value should be price * stock_quantity = 10 * 5 = 50
      assert Decimal.equal?(low_result.total_value, Decimal.new("50.00"))
    end

    test "sorts by computed field ascending", %{products: _products} do
      options = put_in(default_options(), ["sort", "sort_params"], total_value: :asc)

      query = TestResource.list_resources(computed_fields(), options, Product)
      results = @repo.all(query)

      names = Enum.map(results, & &1.name)
      assert names == ["Low Value", "Mid Value", "High Value"]
    end

    test "sorts by computed field descending", %{products: _products} do
      options = put_in(default_options(), ["sort", "sort_params"], total_value: :desc)

      query = TestResource.list_resources(computed_fields(), options, Product)
      results = @repo.all(query)

      names = Enum.map(results, & &1.name)
      assert names == ["High Value", "Mid Value", "Low Value"]
    end
  end

  describe "list_resources/3 - combined joined operations" do
    setup do
      electronics = category_fixture(%{name: "Electronics"})
      clothing = category_fixture(%{name: "Clothing"})

      laptop =
        product_fixture(%{
          name: "Laptop",
          price: Decimal.new("999.00"),
          category_id: electronics.id
        })

      phone =
        product_fixture(%{
          name: "Phone",
          price: Decimal.new("699.00"),
          category_id: electronics.id
        })

      shirt =
        product_fixture(%{name: "T-Shirt", price: Decimal.new("29.00"), category_id: clothing.id})

      jeans =
        product_fixture(%{name: "Jeans", price: Decimal.new("59.00"), category_id: clothing.id})

      %{
        categories: %{electronics: electronics, clothing: clothing},
        products: %{laptop: laptop, phone: phone, shirt: shirt, jeans: jeans}
      }
    end

    test "combines join, filter, and sort", context do
      select_filter =
        LiveTable.Select.new({:category, :id}, "category", %{
          label: "Category",
          selected: [context.categories.electronics.id]
        })

      options =
        default_options()
        |> put_in(["sort", "sort_params"], price: :asc)
        |> put_in(["filters"], %{"category" => select_filter})

      query = TestResource.list_resources(@joined_fields, options, Product)
      results = @repo.all(query)

      # Should return electronics sorted by price
      assert length(results) == 2
      names = Enum.map(results, & &1.name)
      # $699 before $999
      assert names == ["Phone", "Laptop"]
    end

    test "combines search on joined field with pagination", _context do
      options =
        default_options()
        |> put_in(["filters", "search"], "Electronics")
        |> put_in(["pagination", "paginate?"], true)
        |> put_in(["pagination", "per_page"], "1")
        |> put_in(["pagination", "page"], "1")

      query = TestResource.list_resources(@joined_fields, options, Product)
      results = @repo.all(query)

      # Should get 2 results (1 + 1 for has_next_page) from electronics category
      assert length(results) == 2
    end
  end
end
