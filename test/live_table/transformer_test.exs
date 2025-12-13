defmodule LiveTable.TransformerTest do
  @moduledoc """
  Tests for LiveTable.Transformer - the most powerful filter type.

  Transformers provide complete control over query modification, unlike simple
  filters that only add WHERE conditions. They can perform joins, aggregations,
  subqueries, GROUP BY, and any custom query logic.

  ## What This Tests

    * Creating transformer structs with function or MFA syntax
    * Applying transformers to queries
    * Passing applied_data to transformer functions
    * Error handling for invalid transformers
    * Integration with real database queries
  """

  use LiveTable.DataCase, async: true

  alias LiveTable.Transformer
  alias LiveTable.Catalog.Product

  import LiveTable.Fixtures

  describe "Transformer.new/2" do
    test "creates struct with key and options" do
      transformer =
        Transformer.new("my_filter", %{
          query_transformer: fn q, _data -> q end
        })

      assert %Transformer{} = transformer
      assert transformer.key == "my_filter"
      assert is_map(transformer.options)
      assert is_function(transformer.options.query_transformer, 2)
    end

    test "stores query_transformer as anonymous function" do
      transform_fn = fn query, _data -> query end

      transformer =
        Transformer.new("filter", %{
          query_transformer: transform_fn
        })

      assert transformer.options.query_transformer == transform_fn
    end

    test "stores query_transformer as {module, function} tuple" do
      transformer =
        Transformer.new("filter", %{
          query_transformer: {__MODULE__, :sample_transformer}
        })

      assert transformer.options.query_transformer == {__MODULE__, :sample_transformer}
    end

    test "preserves additional options" do
      transformer =
        Transformer.new("filter", %{
          query_transformer: fn q, _d -> q end,
          custom_option: "value",
          another: 123
        })

      assert transformer.options.custom_option == "value"
      assert transformer.options.another == 123
    end
  end

  describe "Transformer.apply/2 with function transformer" do
    test "applies function transformer to query" do
      transformer =
        Transformer.new("price_filter", %{
          query_transformer: fn query, _data ->
            from p in query, where: p.price > 100
          end
        })

      query = from(p in Product)
      result = Transformer.apply(query, transformer)

      assert %Ecto.Query{} = result
      assert inspect(result) =~ "where: p0.price > 100"
    end

    test "passes applied_data to transformer function" do
      transformer =
        Transformer.new("min_price", %{
          query_transformer: fn query, data ->
            min = Map.get(data, "min_price", 0)
            from p in query, where: p.price >= ^min
          end,
          applied_data: %{"min_price" => 50}
        })

      query = from(p in Product)
      result = Transformer.apply(query, transformer)

      # The applied_data should be passed to the transformer
      {sql, params} = Ecto.Adapters.SQL.to_sql(:all, Repo, result)
      assert sql =~ ">="
      # The price field is a :decimal type, so the param is converted to Decimal
      assert Decimal.new("50") in params
    end

    test "handles empty applied_data" do
      transformer =
        Transformer.new("filter", %{
          query_transformer: fn query, data ->
            if data == %{} do
              query
            else
              from p in query, where: p.price > 0
            end
          end
          # No applied_data key - should default to %{}
        })

      query = from(p in Product)
      result = Transformer.apply(query, transformer)

      # Query should be unchanged since applied_data is empty
      assert result == query
    end

    test "transformer can add joins" do
      transformer =
        Transformer.new("category_filter", %{
          query_transformer: fn query, data ->
            case data do
              %{"category_id" => id} when id != "" ->
                from p in query,
                  join: c in assoc(p, :category),
                  where: c.id == ^String.to_integer(id)

              _ ->
                query
            end
          end,
          applied_data: %{"category_id" => "1"}
        })

      query = from(p in Product)
      result = Transformer.apply(query, transformer)

      assert inspect(result) =~ "join:"
      assert inspect(result) =~ "assoc(p0, :category)"
    end

    test "transformer can add group_by and having" do
      transformer =
        Transformer.new("sales_filter", %{
          query_transformer: fn query, data ->
            case data do
              %{"min_total" => min} when min != "" ->
                from p in query,
                  group_by: p.id,
                  having: sum(p.price) >= ^String.to_integer(min)

              _ ->
                query
            end
          end,
          applied_data: %{"min_total" => "100"}
        })

      query = from(p in Product, select: p)
      result = Transformer.apply(query, transformer)

      assert inspect(result) =~ "group_by:"
      assert inspect(result) =~ "having:"
    end
  end

  describe "Transformer.apply/2 with MFA transformer" do
    test "applies {module, function} transformer to query" do
      transformer =
        Transformer.new("mfa_filter", %{
          query_transformer: {__MODULE__, :add_price_filter},
          applied_data: %{"min" => "25"}
        })

      query = from(p in Product)
      result = Transformer.apply(query, transformer)

      assert %Ecto.Query{} = result
      {sql, params} = Ecto.Adapters.SQL.to_sql(:all, Repo, result)
      assert sql =~ ">="
      # The price field is a :decimal type, so the param is converted to Decimal
      assert Decimal.new("25") in params
    end

    test "MFA transformer receives applied_data" do
      transformer =
        Transformer.new("mfa_filter", %{
          query_transformer: {__MODULE__, :echo_data_filter},
          applied_data: %{"key" => "value", "number" => "42"}
        })

      query = from(p in Product, select: p.id)

      # This should not raise - MFA should receive the data correctly
      result = Transformer.apply(query, transformer)
      assert %Ecto.Query{} = result
    end
  end

  describe "Transformer.apply/2 with invalid transformer" do
    test "returns unmodified query when transformer is not a function or MFA" do
      transformer =
        Transformer.new("invalid", %{
          query_transformer: "not a function"
        })

      query = from(p in Product)
      result = Transformer.apply(query, transformer)

      # Should return original query unchanged
      assert result == query
    end

    test "returns unmodified query when transformer is nil" do
      transformer =
        Transformer.new("nil_transformer", %{
          query_transformer: nil
        })

      query = from(p in Product)
      result = Transformer.apply(query, transformer)

      assert result == query
    end
  end

  describe "Transformer integration with database" do
    setup do
      # Create test products with different prices
      cheap = product_fixture(%{name: "Cheap Item", price: Decimal.new("25.00")})
      mid = product_fixture(%{name: "Mid Item", price: Decimal.new("75.00")})
      expensive = product_fixture(%{name: "Expensive Item", price: Decimal.new("150.00")})

      %{cheap: cheap, mid: mid, expensive: expensive}
    end

    test "transformer filters products by price threshold", %{cheap: cheap, mid: mid} do
      transformer =
        Transformer.new("price_filter", %{
          query_transformer: fn query, data ->
            case data do
              %{"max_price" => max} when max != "" ->
                max_val = Decimal.new(max)
                from p in query, where: p.price <= ^max_val

              _ ->
                query
            end
          end,
          applied_data: %{"max_price" => "100"}
        })

      query = from(p in Product, select: p)
      result = Transformer.apply(query, transformer) |> Repo.all()

      result_ids = Enum.map(result, & &1.id)
      assert cheap.id in result_ids
      assert mid.id in result_ids
      assert length(result) == 2
    end

    test "transformer with no matching data returns all products", _context do
      transformer =
        Transformer.new("price_filter", %{
          query_transformer: fn query, data ->
            case data do
              %{"max_price" => max} when max != "" ->
                max_val = Decimal.new(max)
                from p in query, where: p.price <= ^max_val

              _ ->
                query
            end
          end,
          # Empty data - should not filter
          applied_data: %{}
        })

      query = from(p in Product, select: p)
      result = Transformer.apply(query, transformer) |> Repo.all()

      # Should return all 3 products
      assert length(result) == 3
    end

    test "multiple transformers can be chained" do
      price_transformer =
        Transformer.new("price", %{
          query_transformer: fn query, data ->
            case data do
              %{"min" => min} when min != "" ->
                min_val = Decimal.new(min)
                from p in query, where: p.price >= ^min_val

              _ ->
                query
            end
          end,
          applied_data: %{"min" => "50"}
        })

      name_transformer =
        Transformer.new("name", %{
          query_transformer: fn query, data ->
            case data do
              %{"contains" => term} when term != "" ->
                from p in query, where: ilike(p.name, ^"%#{term}%")

              _ ->
                query
            end
          end,
          applied_data: %{"contains" => "Item"}
        })

      query = from(p in Product, select: p)

      result =
        query
        |> Transformer.apply(price_transformer)
        |> Transformer.apply(name_transformer)
        |> Repo.all()

      # Should filter by both price >= 50 AND name contains "Item"
      # Mid (75) and Expensive (150) match price, all match name
      assert length(result) == 2
    end
  end

  # Helper functions for MFA tests

  @doc false
  def sample_transformer(query, _data), do: query

  @doc false
  def add_price_filter(query, data) do
    case data do
      %{"min" => min} when min != "" ->
        min_val = String.to_integer(min)
        from p in query, where: p.price >= ^min_val

      _ ->
        query
    end
  end

  @doc false
  def echo_data_filter(query, _data) do
    # Just return query unchanged - used to verify data is passed
    query
  end
end
