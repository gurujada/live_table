defmodule LiveTable.Integration.DataProviderTest do
  @moduledoc """
  Integration tests for LiveTable custom data provider (MFA tuple) support.

  These tests verify that the query pipeline works correctly when using
  a custom query function provided via `{module, function, args}` tuple
  instead of a schema module directly.

  ## Test Strategy

  Each test provides a custom query function that returns a base query,
  then verifies that filters, sorting, and pagination are applied correctly
  on top of the custom query.

  ## Use Cases

  Custom data providers are useful when:
    * The base query needs complex joins or CTEs
    * The query comes from a different module
    * The query needs runtime-dependent logic
    * Existing queries need to be reused with LiveTable
  """

  use LiveTable.DataCase, async: true

  alias LiveTable.TestResource
  alias LiveTable.Catalog.Product

  import Ecto.Query
  import LiveTable.Fixtures

  @repo Application.compile_env(:live_table, :repo)

  # Simple fields for data provider tests (no associations to keep it simple)
  @simple_fields [
    id: %{label: "ID", sortable: true, searchable: false},
    name: %{label: "Name", sortable: true, searchable: true},
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

  # Custom query provider - returns a base query with named binding
  def base_query do
    from(p in Product, as: :resource)
  end

  # Custom query provider with pre-applied condition
  def in_stock_query do
    from(p in Product, as: :resource, where: p.stock_quantity > 0)
  end

  # Custom query provider with preload and select
  def with_category_query do
    from(p in Product, as: :resource, preload: [:category])
  end

  # Custom query provider accepting arguments
  def min_price_query(min_price) do
    from(p in Product, as: :resource, where: p.price >= ^min_price)
  end

  describe "list_resources/3 with data provider - basic operations" do
    setup do
      product_a =
        product_fixture(%{name: "Alpha", price: Decimal.new("100.00"), stock_quantity: 10})

      product_b =
        product_fixture(%{name: "Beta", price: Decimal.new("200.00"), stock_quantity: 5})

      product_c =
        product_fixture(%{name: "Gamma", price: Decimal.new("50.00"), stock_quantity: 0})

      %{products: %{alpha: product_a, beta: product_b, gamma: product_c}}
    end

    test "executes basic data provider query", context do
      data_provider = {__MODULE__, :base_query, []}

      query = TestResource.list_resources(@simple_fields, default_options(), data_provider)
      results = @repo.all(query)

      assert length(results) == 3
      result_ids = Enum.map(results, & &1.id)
      assert context.products.alpha.id in result_ids
      assert context.products.beta.id in result_ids
      assert context.products.gamma.id in result_ids
    end

    test "applies sorting to data provider query", %{products: _products} do
      data_provider = {__MODULE__, :base_query, []}
      options = put_in(default_options(), ["sort", "sort_params"], name: :asc)

      query = TestResource.list_resources(@simple_fields, options, data_provider)
      results = @repo.all(query)

      names = Enum.map(results, & &1.name)
      assert names == ["Alpha", "Beta", "Gamma"]
    end

    test "applies pagination to data provider query", _context do
      data_provider = {__MODULE__, :base_query, []}

      options =
        default_options()
        |> put_in(["pagination", "paginate?"], true)
        |> put_in(["pagination", "per_page"], "2")
        |> put_in(["pagination", "page"], "1")
        |> put_in(["sort", "sort_params"], name: :asc)

      query = TestResource.list_resources(@simple_fields, options, data_provider)
      results = @repo.all(query)

      # per_page + 1 for has_next_page detection
      assert length(results) == 3

      names = Enum.map(results, & &1.name)
      assert names == ["Alpha", "Beta", "Gamma"]
    end

    test "applies text search to data provider query", context do
      data_provider = {__MODULE__, :base_query, []}
      options = put_in(default_options(), ["filters", "search"], "Alpha")

      query = TestResource.list_resources(@simple_fields, options, data_provider)
      results = @repo.all(query)

      assert length(results) == 1
      assert List.first(results).id == context.products.alpha.id
    end
  end

  describe "list_resources/3 with data provider - pre-filtered queries" do
    setup do
      in_stock =
        product_fixture(%{
          name: "In Stock Item",
          price: Decimal.new("100.00"),
          stock_quantity: 10
        })

      out_of_stock =
        product_fixture(%{
          name: "Out of Stock Item",
          price: Decimal.new("50.00"),
          stock_quantity: 0
        })

      %{in_stock: in_stock, out_of_stock: out_of_stock}
    end

    test "respects pre-applied conditions in data provider", context do
      data_provider = {__MODULE__, :in_stock_query, []}

      query = TestResource.list_resources(@simple_fields, default_options(), data_provider)
      results = @repo.all(query)

      # Should only return in-stock items (pre-filtered by data provider)
      assert length(results) == 1
      assert List.first(results).id == context.in_stock.id
    end

    test "combines pre-applied conditions with additional sorting", context do
      data_provider = {__MODULE__, :in_stock_query, []}
      options = put_in(default_options(), ["sort", "sort_params"], name: :asc)

      query = TestResource.list_resources(@simple_fields, options, data_provider)
      results = @repo.all(query)

      assert length(results) == 1
      assert List.first(results).id == context.in_stock.id
    end

    test "combines pre-applied conditions with text search", _context do
      # Create another in-stock item
      another_in_stock = product_fixture(%{name: "Searchable Item", stock_quantity: 5})

      data_provider = {__MODULE__, :in_stock_query, []}
      options = put_in(default_options(), ["filters", "search"], "Searchable")

      query = TestResource.list_resources(@simple_fields, options, data_provider)
      results = @repo.all(query)

      assert length(results) == 1
      assert List.first(results).id == another_in_stock.id
    end
  end

  describe "list_resources/3 with data provider - parameterized queries" do
    setup do
      cheap = product_fixture(%{name: "Cheap", price: Decimal.new("25.00")})
      mid_range = product_fixture(%{name: "Mid Range", price: Decimal.new("75.00")})
      expensive = product_fixture(%{name: "Expensive", price: Decimal.new("150.00")})

      %{cheap: cheap, mid_range: mid_range, expensive: expensive}
    end

    test "passes arguments to data provider function", context do
      # Query with min_price = 50
      data_provider = {__MODULE__, :min_price_query, [Decimal.new("50.00")]}

      query = TestResource.list_resources(@simple_fields, default_options(), data_provider)
      results = @repo.all(query)

      # Should only return mid_range and expensive
      assert length(results) == 2
      result_ids = Enum.map(results, & &1.id)
      refute context.cheap.id in result_ids
      assert context.mid_range.id in result_ids
      assert context.expensive.id in result_ids
    end

    test "combines parameterized query with sorting", _context do
      data_provider = {__MODULE__, :min_price_query, [Decimal.new("50.00")]}
      options = put_in(default_options(), ["sort", "sort_params"], price: :asc)

      query = TestResource.list_resources(@simple_fields, options, data_provider)
      results = @repo.all(query)

      names = Enum.map(results, & &1.name)
      assert names == ["Mid Range", "Expensive"]
    end

    test "combines parameterized query with pagination", _context do
      data_provider = {__MODULE__, :min_price_query, [Decimal.new("50.00")]}

      options =
        default_options()
        |> put_in(["pagination", "paginate?"], true)
        |> put_in(["pagination", "per_page"], "1")
        |> put_in(["pagination", "page"], "1")
        |> put_in(["sort", "sort_params"], price: :asc)

      query = TestResource.list_resources(@simple_fields, options, data_provider)
      results = @repo.all(query)

      # per_page + 1 = 2
      assert length(results) == 2
      names = Enum.map(results, & &1.name)
      assert names == ["Mid Range", "Expensive"]
    end
  end

  describe "list_resources/3 with data provider - filters" do
    setup do
      product_a = product_fixture(%{name: "A", price: Decimal.new("100.00"), stock_quantity: 10})
      product_b = product_fixture(%{name: "B", price: Decimal.new("200.00"), stock_quantity: 0})
      product_c = product_fixture(%{name: "C", price: Decimal.new("50.00"), stock_quantity: 5})

      %{products: [product_a, product_b, product_c]}
    end

    test "applies Boolean filter to data provider query", _context do
      data_provider = {__MODULE__, :base_query, []}

      in_stock_filter =
        LiveTable.Boolean.new(:stock_quantity, "in-stock", %{
          label: "In Stock",
          condition: dynamic([p], p.stock_quantity > 0),
          checked: true
        })

      options = put_in(default_options(), ["filters"], %{"in_stock" => in_stock_filter})

      query = TestResource.list_resources(@simple_fields, options, data_provider)
      results = @repo.all(query)

      # Should return only in-stock items (A and C)
      assert length(results) == 2
      result_names = Enum.map(results, & &1.name) |> Enum.sort()
      assert result_names == ["A", "C"]
    end

    test "applies Range filter to data provider query", _context do
      data_provider = {__MODULE__, :base_query, []}

      price_range =
        LiveTable.Range.new(:price, "price_range", %{
          label: "Price Range",
          min: 0,
          max: 1000,
          current_min: Decimal.new("75.00"),
          current_max: Decimal.new("150.00")
        })

      options = put_in(default_options(), ["filters"], %{"price_range" => price_range})

      query = TestResource.list_resources(@simple_fields, options, data_provider)
      results = @repo.all(query)

      # Should return only product A ($100, within $75-$150 range)
      assert length(results) == 1
      assert List.first(results).name == "A"
    end

    test "applies Transformer filter to data provider query", _context do
      data_provider = {__MODULE__, :base_query, []}

      # Transformer that filters for high-value items (price * quantity > threshold)
      high_value_filter =
        LiveTable.Transformer.new("high_value", %{
          applied_data: %{"min_value" => "500"},
          query_transformer: fn query, filter_data ->
            case filter_data do
              %{"min_value" => min} when min != "" ->
                min_value = String.to_integer(min)
                from p in query, where: p.price * p.stock_quantity >= ^min_value

              _ ->
                query
            end
          end
        })

      options = put_in(default_options(), ["filters"], %{"high_value" => high_value_filter})

      query = TestResource.list_resources(@simple_fields, options, data_provider)
      results = @repo.all(query)

      # Product A: 100 * 10 = 1000 (passes)
      # Product B: 200 * 0 = 0 (fails)
      # Product C: 50 * 5 = 250 (fails)
      assert length(results) == 1
      assert List.first(results).name == "A"
    end
  end

  describe "list_resources/3 with data provider - combined operations" do
    setup do
      p1 = product_fixture(%{name: "Widget", price: Decimal.new("100.00"), stock_quantity: 10})
      p2 = product_fixture(%{name: "Gadget", price: Decimal.new("200.00"), stock_quantity: 5})
      p3 = product_fixture(%{name: "Widget Pro", price: Decimal.new("150.00"), stock_quantity: 3})
      p4 = product_fixture(%{name: "Gadget Plus", price: Decimal.new("50.00"), stock_quantity: 0})

      %{products: [p1, p2, p3, p4]}
    end

    test "combines data provider with search, filter, sort, and pagination", _context do
      data_provider = {__MODULE__, :in_stock_query, []}

      # Search for "Widget", sort by price desc, paginate
      options =
        default_options()
        |> put_in(["filters", "search"], "Widget")
        |> put_in(["sort", "sort_params"], price: :desc)
        |> put_in(["pagination", "paginate?"], true)
        |> put_in(["pagination", "per_page"], "10")
        |> put_in(["pagination", "page"], "1")

      query = TestResource.list_resources(@simple_fields, options, data_provider)
      results = @repo.all(query)

      # In stock widgets: Widget ($100, qty 10), Widget Pro ($150, qty 3)
      # Sorted by price desc: Widget Pro, Widget
      assert length(results) == 2
      names = Enum.map(results, & &1.name)
      assert names == ["Widget Pro", "Widget"]
    end

    test "empty result when data provider filter conflicts with LiveTable filter", _context do
      # Data provider returns only in-stock items
      data_provider = {__MODULE__, :in_stock_query, []}

      # Search for out-of-stock item name
      options = put_in(default_options(), ["filters", "search"], "Gadget Plus")

      query = TestResource.list_resources(@simple_fields, options, data_provider)
      results = @repo.all(query)

      # Gadget Plus is out of stock, so data provider excludes it
      assert results == []
    end
  end
end
