defmodule LiveTable.Integration.LiveResourceSingleTest do
  @moduledoc """
  Integration tests for LiveTable query pipeline with single-table operations.

  These tests verify the full query pipeline works correctly for:
    * Sorting (single and multi-column)
    * Pagination
    * Text search filtering
    * Boolean filters
    * Range filters
    * Combined operations

  ## Test Strategy

  Each test creates real database records, runs the query pipeline,
  and verifies the results match expected behavior. This ensures
  all components work together correctly.
  """

  use LiveTable.DataCase, async: true

  alias LiveTable.TestResource
  alias LiveTable.Catalog.Product

  import LiveTable.Fixtures

  @repo Application.compile_env(:live_table, :repo)

  # Simple fields without associations for single-table tests
  @simple_fields [
    id: %{label: "ID", sortable: true, searchable: false},
    name: %{label: "Name", sortable: true, searchable: true},
    description: %{label: "Description", sortable: false, searchable: true},
    price: %{label: "Price", sortable: true, searchable: false},
    stock_quantity: %{label: "Stock", sortable: true, searchable: false}
  ]

  # Default options structure
  defp default_options do
    %{
      "sort" => %{"sortable?" => true, "sort_params" => []},
      "pagination" => %{"paginate?" => false, "page" => "1", "per_page" => "10"},
      "filters" => %{}
    }
  end

  describe "list_resources/3 - basic query" do
    test "returns all resources without any options" do
      product1 = product_fixture(%{name: "Alpha"})
      product2 = product_fixture(%{name: "Beta"})

      query = TestResource.list_resources(@simple_fields, default_options(), Product)
      results = @repo.all(query)

      result_ids = Enum.map(results, & &1.id)
      assert product1.id in result_ids
      assert product2.id in result_ids
    end

    test "returns empty list when no products exist" do
      query = TestResource.list_resources(@simple_fields, default_options(), Product)
      results = @repo.all(query)

      assert results == []
    end
  end

  describe "list_resources/3 - sorting" do
    setup do
      # Create products with specific ordering data
      product_a =
        product_fixture(%{name: "Alpha", price: Decimal.new("100.00"), stock_quantity: 50})

      product_b =
        product_fixture(%{name: "Beta", price: Decimal.new("50.00"), stock_quantity: 100})

      product_c =
        product_fixture(%{name: "Gamma", price: Decimal.new("75.00"), stock_quantity: 25})

      %{products: [product_a, product_b, product_c]}
    end

    test "sorts by field ascending", %{products: [_alpha, _beta, _gamma]} do
      options = put_in(default_options(), ["sort", "sort_params"], name: :asc)

      query = TestResource.list_resources(@simple_fields, options, Product)
      results = @repo.all(query)

      names = Enum.map(results, & &1.name)
      assert names == ["Alpha", "Beta", "Gamma"]
    end

    test "sorts by field descending", %{products: [_alpha, _beta, _gamma]} do
      options = put_in(default_options(), ["sort", "sort_params"], name: :desc)

      query = TestResource.list_resources(@simple_fields, options, Product)
      results = @repo.all(query)

      names = Enum.map(results, & &1.name)
      assert names == ["Gamma", "Beta", "Alpha"]
    end

    test "sorts by numeric field ascending", %{products: [_alpha, _beta, _gamma]} do
      options = put_in(default_options(), ["sort", "sort_params"], price: :asc)

      query = TestResource.list_resources(@simple_fields, options, Product)
      results = @repo.all(query)

      prices = Enum.map(results, & &1.price)
      assert Decimal.equal?(Enum.at(prices, 0), Decimal.new("50.00"))
      assert Decimal.equal?(Enum.at(prices, 1), Decimal.new("75.00"))
      assert Decimal.equal?(Enum.at(prices, 2), Decimal.new("100.00"))
    end

    test "sorts by numeric field descending", %{products: [_alpha, _beta, _gamma]} do
      options = put_in(default_options(), ["sort", "sort_params"], price: :desc)

      query = TestResource.list_resources(@simple_fields, options, Product)
      results = @repo.all(query)

      prices = Enum.map(results, & &1.price)
      assert Decimal.equal?(Enum.at(prices, 0), Decimal.new("100.00"))
      assert Decimal.equal?(Enum.at(prices, 1), Decimal.new("75.00"))
      assert Decimal.equal?(Enum.at(prices, 2), Decimal.new("50.00"))
    end

    test "handles multiple sort params", %{products: _products} do
      # Create additional products with same name but different prices
      product_fixture(%{name: "Delta", price: Decimal.new("100.00")})
      product_fixture(%{name: "Delta", price: Decimal.new("50.00")})

      options = put_in(default_options(), ["sort", "sort_params"], name: :asc, price: :desc)

      query = TestResource.list_resources(@simple_fields, options, Product)
      results = @repo.all(query)

      # Delta products should be sorted by price desc within their name group
      delta_products = Enum.filter(results, &(&1.name == "Delta"))
      delta_prices = Enum.map(delta_products, & &1.price)

      if length(delta_prices) == 2 do
        assert Decimal.compare(Enum.at(delta_prices, 0), Enum.at(delta_prices, 1)) in [:gt, :eq]
      end
    end

    test "ignores sort for non-sortable fields" do
      options = put_in(default_options(), ["sort", "sort_params"], description: :asc)

      # Should not raise, just ignore the sort
      query = TestResource.list_resources(@simple_fields, options, Product)
      results = @repo.all(query)

      # Should return all products (unsorted by description since it's not sortable)
      assert length(results) == 3
    end

    test "returns unsorted when sortable? is false" do
      options =
        default_options()
        |> put_in(["sort", "sortable?"], false)
        |> put_in(["sort", "sort_params"], name: :asc)

      query = TestResource.list_resources(@simple_fields, options, Product)
      results = @repo.all(query)

      # Should return all products but sorting should be ignored
      assert length(results) == 3
    end
  end

  describe "list_resources/3 - pagination" do
    setup do
      # Create 25 products for pagination tests
      products = seed_products(25)
      %{products: products}
    end

    test "paginates with correct limit", %{products: _products} do
      options =
        default_options()
        |> put_in(["pagination", "paginate?"], true)
        |> put_in(["pagination", "per_page"], "10")
        |> put_in(["pagination", "page"], "1")

      query = TestResource.list_resources(@simple_fields, options, Product)
      results = @repo.all(query)

      # Note: LiveTable fetches per_page + 1 to detect has_next_page
      assert length(results) == 11
    end

    test "returns correct page", %{products: products} do
      options =
        default_options()
        |> put_in(["sort", "sort_params"], id: :asc)
        |> put_in(["pagination", "paginate?"], true)
        |> put_in(["pagination", "per_page"], "10")
        |> put_in(["pagination", "page"], "2")

      query = TestResource.list_resources(@simple_fields, options, Product)
      results = @repo.all(query)

      # Page 2 should start at product 11
      first_result_id = List.first(results).id
      expected_id = Enum.at(products, 10).id
      assert first_result_id == expected_id
    end

    test "handles last page with fewer items", %{products: _products} do
      options =
        default_options()
        |> put_in(["pagination", "paginate?"], true)
        |> put_in(["pagination", "per_page"], "10")
        |> put_in(["pagination", "page"], "3")

      query = TestResource.list_resources(@simple_fields, options, Product)
      results = @repo.all(query)

      # Page 3 of 25 items with 10 per page = 5 items
      assert length(results) == 5
    end

    test "returns all when pagination disabled", %{products: _products} do
      options = put_in(default_options(), ["pagination", "paginate?"], false)

      query = TestResource.list_resources(@simple_fields, options, Product)
      results = @repo.all(query)

      assert length(results) == 25
    end

    test "handles different page sizes", %{products: _products} do
      options =
        default_options()
        |> put_in(["pagination", "paginate?"], true)
        |> put_in(["pagination", "per_page"], "5")
        |> put_in(["pagination", "page"], "1")

      query = TestResource.list_resources(@simple_fields, options, Product)
      results = @repo.all(query)

      # Note: LiveTable fetches per_page + 1 to detect has_next_page
      assert length(results) == 6
    end
  end

  describe "list_resources/3 - text search filtering" do
    setup do
      product1 = product_fixture(%{name: "Widget Pro", description: "A professional widget"})
      product2 = product_fixture(%{name: "Gadget Basic", description: "A basic gadget"})

      product3 =
        product_fixture(%{name: "Tool Standard", description: "Standard tool for widgets"})

      %{products: [product1, product2, product3]}
    end

    test "filters by search term in name", %{products: [widget, _gadget, tool]} do
      options = put_in(default_options(), ["filters", "search"], "Widget")

      query = TestResource.list_resources(@simple_fields, options, Product)
      results = @repo.all(query)

      # "Widget" appears in "Widget Pro" name and "widgets" in Tool's description
      assert length(results) == 2
      result_ids = Enum.map(results, & &1.id)
      assert widget.id in result_ids
      assert tool.id in result_ids
    end

    test "filters by search term in description", %{products: [_widget, gadget, _tool]} do
      options = put_in(default_options(), ["filters", "search"], "basic gadget")

      query = TestResource.list_resources(@simple_fields, options, Product)
      results = @repo.all(query)

      assert length(results) == 1
      assert List.first(results).id == gadget.id
    end

    test "search is case insensitive", %{products: [widget, _, _]} do
      options = put_in(default_options(), ["filters", "search"], "WIDGET")

      query = TestResource.list_resources(@simple_fields, options, Product)
      results = @repo.all(query)

      assert length(results) >= 1
      result_ids = Enum.map(results, & &1.id)
      assert widget.id in result_ids
    end

    test "search across multiple searchable fields", %{products: [widget, _gadget, tool]} do
      # "widget" appears in Widget's name and Tool's description
      options = put_in(default_options(), ["filters", "search"], "widget")

      query = TestResource.list_resources(@simple_fields, options, Product)
      results = @repo.all(query)

      result_ids = Enum.map(results, & &1.id)
      assert widget.id in result_ids
      assert tool.id in result_ids
    end

    test "returns empty when no matches", %{products: _products} do
      options = put_in(default_options(), ["filters", "search"], "nonexistent")

      query = TestResource.list_resources(@simple_fields, options, Product)
      results = @repo.all(query)

      assert results == []
    end

    test "empty search returns all results", %{products: _products} do
      options = put_in(default_options(), ["filters", "search"], "")

      query = TestResource.list_resources(@simple_fields, options, Product)
      results = @repo.all(query)

      assert length(results) == 3
    end
  end

  describe "list_resources/3 - Boolean filters" do
    setup do
      cheap = product_fixture(%{name: "Cheap Item", price: Decimal.new("50.00")})
      expensive = product_fixture(%{name: "Expensive Item", price: Decimal.new("150.00")})

      in_stock =
        product_fixture(%{name: "In Stock", price: Decimal.new("75.00"), stock_quantity: 100})

      out_of_stock =
        product_fixture(%{name: "Out of Stock", price: Decimal.new("80.00"), stock_quantity: 0})

      %{cheap: cheap, expensive: expensive, in_stock: in_stock, out_of_stock: out_of_stock}
    end

    test "applies Boolean filter (under_100)", %{cheap: cheap, in_stock: in_stock} do
      under_100_filter =
        LiveTable.Boolean.new(:price, "under-100", %{
          label: "Under $100",
          condition: Ecto.Query.dynamic([p], p.price < 100)
        })

      options = put_in(default_options(), ["filters"], %{"under_100" => under_100_filter})

      query = TestResource.list_resources(@simple_fields, options, Product)
      results = @repo.all(query)

      result_ids = Enum.map(results, & &1.id)
      assert cheap.id in result_ids
      assert in_stock.id in result_ids
      # cheap, in_stock, out_of_stock (all under 100)
      assert length(results) == 3
    end

    test "applies Boolean filter (in_stock)", %{
      in_stock: in_stock,
      cheap: _cheap,
      expensive: _expensive
    } do
      in_stock_filter =
        LiveTable.Boolean.new(:stock_quantity, "in-stock", %{
          label: "In Stock",
          condition: Ecto.Query.dynamic([p], p.stock_quantity > 0)
        })

      options = put_in(default_options(), ["filters"], %{"in_stock" => in_stock_filter})

      query = TestResource.list_resources(@simple_fields, options, Product)
      results = @repo.all(query)

      result_ids = Enum.map(results, & &1.id)
      assert in_stock.id in result_ids
      # cheap and expensive should also be in stock (default stock_quantity is 100)
    end

    test "combines multiple Boolean filters", %{cheap: cheap} do
      under_100_filter =
        LiveTable.Boolean.new(:price, "under-100", %{
          label: "Under $100",
          condition: Ecto.Query.dynamic([p], p.price < 100)
        })

      in_stock_filter =
        LiveTable.Boolean.new(:stock_quantity, "in-stock", %{
          label: "In Stock",
          condition: Ecto.Query.dynamic([p], p.stock_quantity > 0)
        })

      options =
        put_in(default_options(), ["filters"], %{
          "under_100" => under_100_filter,
          "in_stock" => in_stock_filter
        })

      query = TestResource.list_resources(@simple_fields, options, Product)
      results = @repo.all(query)

      # Should have items that are both under $100 AND in stock
      result_ids = Enum.map(results, & &1.id)
      assert cheap.id in result_ids
    end
  end

  describe "list_resources/3 - Range filters" do
    setup do
      cheap = product_fixture(%{name: "Cheap", price: Decimal.new("25.00")})
      mid = product_fixture(%{name: "Mid", price: Decimal.new("75.00")})
      expensive = product_fixture(%{name: "Expensive", price: Decimal.new("150.00")})

      %{cheap: cheap, mid: mid, expensive: expensive}
    end

    test "applies Range filter with min and max", %{mid: mid} do
      price_range =
        LiveTable.Range.new(:price, "price_range", %{
          label: "Price Range",
          min: 0,
          max: 1000,
          current_min: 50,
          current_max: 100
        })

      options = put_in(default_options(), ["filters"], %{"price_range" => price_range})

      query = TestResource.list_resources(@simple_fields, options, Product)
      results = @repo.all(query)

      # Only mid-priced product ($75) should match
      assert length(results) == 1
      assert List.first(results).id == mid.id
    end

    test "applies Range filter with only min", %{mid: mid, expensive: expensive} do
      price_range =
        LiveTable.Range.new(:price, "price_range", %{
          label: "Price Range",
          min: 0,
          max: 1000,
          current_min: 50,
          # max at limit
          current_max: 1000
        })

      options = put_in(default_options(), ["filters"], %{"price_range" => price_range})

      query = TestResource.list_resources(@simple_fields, options, Product)
      results = @repo.all(query)

      result_ids = Enum.map(results, & &1.id)
      assert mid.id in result_ids
      assert expensive.id in result_ids
    end

    test "applies Range filter with only max", %{cheap: cheap, mid: mid} do
      price_range =
        LiveTable.Range.new(:price, "price_range", %{
          label: "Price Range",
          min: 0,
          max: 1000,
          # min at limit
          current_min: 0,
          current_max: 100
        })

      options = put_in(default_options(), ["filters"], %{"price_range" => price_range})

      query = TestResource.list_resources(@simple_fields, options, Product)
      results = @repo.all(query)

      result_ids = Enum.map(results, & &1.id)
      assert cheap.id in result_ids
      assert mid.id in result_ids
    end
  end

  describe "list_resources/3 - Transformer filters" do
    setup do
      low_value =
        product_fixture(%{name: "Low Value", price: Decimal.new("10.00"), stock_quantity: 5})

      high_value =
        product_fixture(%{name: "High Value", price: Decimal.new("100.00"), stock_quantity: 100})

      %{low_value: low_value, high_value: high_value}
    end

    test "applies Transformer filter", %{high_value: high_value} do
      transformer =
        LiveTable.Transformer.new("high_value", %{
          query_transformer: fn query, data ->
            case data do
              %{"min_value" => min} when min != "" ->
                min_val = String.to_integer(min)
                Ecto.Query.from(p in query, where: p.price * p.stock_quantity >= ^min_val)

              _ ->
                query
            end
          end,
          applied_data: %{"min_value" => "1000"}
        })

      options = put_in(default_options(), ["filters"], %{"high_value" => transformer})

      query = TestResource.list_resources(@simple_fields, options, Product)
      results = @repo.all(query)

      # Only high_value product has total value >= 1000 (100 * 100 = 10000)
      assert length(results) == 1
      assert List.first(results).id == high_value.id
    end
  end

  describe "list_resources/3 - combined operations" do
    setup do
      # Create diverse set of products
      products = [
        product_fixture(%{
          name: "Alpha Widget",
          price: Decimal.new("50.00"),
          stock_quantity: 100
        }),
        product_fixture(%{name: "Beta Widget", price: Decimal.new("75.00"), stock_quantity: 50}),
        product_fixture(%{
          name: "Gamma Gadget",
          price: Decimal.new("100.00"),
          stock_quantity: 25
        }),
        product_fixture(%{
          name: "Delta Gadget",
          price: Decimal.new("150.00"),
          stock_quantity: 10
        }),
        product_fixture(%{name: "Epsilon Tool", price: Decimal.new("200.00"), stock_quantity: 5})
      ]

      %{products: products}
    end

    test "combines sorting and pagination", %{products: _products} do
      options =
        default_options()
        |> put_in(["sort", "sort_params"], price: :asc)
        |> put_in(["pagination", "paginate?"], true)
        |> put_in(["pagination", "per_page"], "2")
        |> put_in(["pagination", "page"], "1")

      query = TestResource.list_resources(@simple_fields, options, Product)
      results = @repo.all(query)

      # Note: LiveTable fetches per_page + 1 to detect has_next_page
      # Should get 3 results (2 + 1 for has_next_page check)
      assert length(results) == 3

      # First 2 should be cheapest products sorted by price
      prices = Enum.map(Enum.take(results, 2), & &1.price)
      assert Decimal.equal?(Enum.at(prices, 0), Decimal.new("50.00"))
      assert Decimal.equal?(Enum.at(prices, 1), Decimal.new("75.00"))
    end

    test "combines search and sorting", %{products: _products} do
      options =
        default_options()
        |> put_in(["sort", "sort_params"], price: :desc)
        |> put_in(["filters", "search"], "Widget")

      query = TestResource.list_resources(@simple_fields, options, Product)
      results = @repo.all(query)

      # Should get widgets sorted by price desc
      assert length(results) == 2
      names = Enum.map(results, & &1.name)
      assert "Beta Widget" in names
      assert "Alpha Widget" in names

      # Beta ($75) should come before Alpha ($50) in desc order
      prices = Enum.map(results, & &1.price)
      assert Decimal.compare(Enum.at(prices, 0), Enum.at(prices, 1)) == :gt
    end

    test "combines filtering, sorting, and pagination", %{products: _products} do
      under_100_filter =
        LiveTable.Boolean.new(:price, "under-100", %{
          label: "Under $100",
          condition: Ecto.Query.dynamic([p], p.price < 100)
        })

      options =
        default_options()
        |> put_in(["sort", "sort_params"], name: :asc)
        |> put_in(["pagination", "paginate?"], true)
        |> put_in(["pagination", "per_page"], "2")
        |> put_in(["pagination", "page"], "1")
        |> put_in(["filters"], %{"under_100" => under_100_filter})

      query = TestResource.list_resources(@simple_fields, options, Product)
      results = @repo.all(query)

      # Should get first 2 products under $100 sorted by name
      assert length(results) == 2
      # Alpha Widget ($50) and Beta Widget ($75) are under $100
      names = Enum.map(results, & &1.name)
      assert "Alpha Widget" in names
      assert "Beta Widget" in names
    end

    test "combines search and Boolean filter", %{products: _products} do
      under_100_filter =
        LiveTable.Boolean.new(:price, "under-100", %{
          label: "Under $100",
          condition: Ecto.Query.dynamic([p], p.price < 100)
        })

      options =
        default_options()
        |> put_in(["filters"], %{"under_100" => under_100_filter})
        |> put_in(["filters", "search"], "Gadget")

      query = TestResource.list_resources(@simple_fields, options, Product)
      results = @repo.all(query)

      # Gamma Gadget is $100 (not under), Delta Gadget is $150 (not under)
      # So no gadgets are under $100
      assert results == []
    end
  end
end
