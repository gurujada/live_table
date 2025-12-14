defmodule LiveTable.TestResource do
  @moduledoc """
  A test resource module that demonstrates LiveTable query functions.

  This module is used in integration tests to verify the query pipeline
  works correctly. It also serves as documentation for how to configure
  fields and filters.

  Note: This is a simplified version that doesn't use the full LiveResource
  macro (which requires a LiveView context). Instead, it directly implements
  the query functions for testing purposes.

  ## Features Demonstrated

    * Basic field configuration with sortable/searchable options
    * Association fields with `assoc: {table, field}` syntax
    * Computed fields using dynamic expressions
    * Boolean, Range, Select, and Transformer filters
    * Custom table options
  """

  import Ecto.Query
  import LiveTable.Sorting
  import LiveTable.Paginate
  import LiveTable.Join
  import LiveTable.Filter

  alias LiveTable.{Boolean, Select, Range, Transformer, TableConfig}
  alias LiveTable.Catalog.Product

  @doc """
  Defines the fields displayed in the table.

  Each field has:
    * `:label` - Display name in table header
    * `:sortable` - Whether the column can be sorted (defaults to false)
    * `:searchable` - Whether the field is included in text search
    * `:hidden` - Whether the column is hidden from display (defaults to false)
    * `:assoc` - For joined fields, `{association_name, field_name}`
    * `:computed` - Dynamic expression for calculated fields
  """
  def fields do
    [
      id: %{
        label: "ID",
        sortable: true
      },
      name: %{
        label: "Name",
        sortable: true,
        searchable: true
      },
      description: %{
        label: "Description",
        searchable: true
      },
      price: %{
        label: "Price",
        sortable: true
      },
      stock_quantity: %{
        label: "Stock",
        sortable: true
      },
      category_name: %{
        label: "Category",
        assoc: {:category, :name},
        sortable: true,
        searchable: true
      },
      supplier_name: %{
        label: "Supplier",
        assoc: {:suppliers, :name},
        sortable: true,
        searchable: true
      },
      # Computed field example
      total_value: %{
        label: "Total Value",
        sortable: true,
        computed: dynamic([resource: r], r.price * r.stock_quantity)
      },
      # Hidden field example - available for sorting/filtering but not displayed
      internal_rank: %{
        label: "Internal Rank",
        sortable: true,
        hidden: true
      }
    ]
  end

  @doc """
  Defines the available filters for the table.

  Demonstrates all filter types:
    * `Boolean` - Checkbox toggle with custom condition
    * `Range` - Numeric range slider
    * `Select` - Dropdown/multi-select for associations
    * `Transformer` - Custom query transformations
  """
  def filters do
    [
      # Boolean filter - shows only products under $100
      under_100:
        Boolean.new(:price, "under-100", %{
          label: "Under $100",
          condition: dynamic([p], p.price < 100)
        }),

      # Boolean filter - shows only in-stock products
      in_stock:
        Boolean.new(:stock_quantity, "in-stock", %{
          label: "In Stock",
          condition: dynamic([p], p.stock_quantity > 0)
        }),

      # Range filter - filter by price range
      price_range:
        Range.new(:price, "price_range", %{
          label: "Price Range",
          unit: "$",
          min: 0,
          max: 1000,
          step: 10,
          default_min: 0,
          default_max: 1000
        }),

      # Select filter - filter by category
      category:
        Select.new({:category, :id}, "category", %{
          label: "Category",
          placeholder: "Select categories..."
        }),

      # Transformer filter - custom query modification
      high_value:
        Transformer.new("high_value", %{
          query_transformer: &__MODULE__.apply_high_value_filter/2
        }),

      # Transformer with MFA syntax
      min_stock:
        Transformer.new("min_stock", %{
          query_transformer: {__MODULE__, :apply_min_stock_filter}
        })
    ]
  end

  @doc """
  Custom table options demonstrating configuration.
  """
  def table_options do
    %{
      pagination: %{
        enabled: true,
        sizes: [5, 10, 25, 50],
        default_size: 10
      },
      sorting: %{
        enabled: true,
        default_sort: [id: :asc]
      },
      search: %{
        enabled: true,
        debounce: 300,
        placeholder: "Search products..."
      },
      exports: %{
        enabled: true,
        formats: [:csv, :pdf]
      }
    }
  end

  @doc """
  Lists resources with the given options.

  This is the main query pipeline function. It:
  1. Builds the base query
  2. Joins associations (from filters)
  3. Selects columns
  4. Applies filters
  5. Applies sorting
  6. Applies transformers
  7. Paginates results
  """
  def list_resources(fields_list, options, data_source \\ Product)

  def list_resources(fields_list, options, {module, function, args} = _data_provider)
      when is_atom(function) do
    {regular_filters, transformers, _debug_mode} = prepare_query_context(options)

    apply(module, function, args)
    |> join_associations(regular_filters)
    |> apply_filters(regular_filters, fields_list)
    |> maybe_sort(fields_list, options["sort"]["sort_params"], options["sort"]["sortable?"])
    |> apply_transformers(transformers)
    |> maybe_paginate(options["pagination"], options["pagination"]["paginate?"])
  end

  def list_resources(fields_list, options, schema) do
    {regular_filters, transformers, _debug_mode} = prepare_query_context(options)

    # For joined fields, we need to join associations from both filters AND fields
    field_assocs = get_field_assocs(fields_list)
    filter_assocs = get_filter_assocs(regular_filters)
    all_assocs = Enum.uniq(field_assocs ++ filter_assocs)

    base_query = from(schema, as: :resource)

    query_with_joins =
      Enum.reduce(all_assocs, base_query, fn assoc_name, query ->
        if has_named_binding?(query, assoc_name) do
          query
        else
          join(query, :left, [r], s in assoc(r, ^assoc_name), as: ^assoc_name)
        end
      end)

    query_with_joins
    |> select_columns_with_assocs(fields_list)
    |> apply_filters(regular_filters, fields_list)
    |> maybe_sort(fields_list, options["sort"]["sort_params"], options["sort"]["sortable?"])
    |> apply_transformers(transformers)
    |> maybe_paginate(options["pagination"], options["pagination"]["paginate?"])
  end

  @doc """
  Returns merged table options with defaults.
  """
  def get_merged_table_options do
    TableConfig.get_table_options(table_options())
  end

  @doc """
  Transformer function that filters for high-value products.

  This demonstrates how transformers receive the query and filter data,
  allowing complex query modifications.
  """
  def apply_high_value_filter(query, filter_data) do
    case filter_data do
      %{"min_value" => min} when min != "" ->
        min_value = String.to_integer(min)

        from p in query,
          where: p.price * p.stock_quantity >= ^min_value

      _ ->
        query
    end
  end

  @doc """
  Transformer function using MFA syntax that filters by minimum stock.
  """
  def apply_min_stock_filter(query, filter_data) do
    case filter_data do
      %{"quantity" => qty} when qty != "" ->
        min_qty = String.to_integer(qty)
        from p in query, where: p.stock_quantity >= ^min_qty

      _ ->
        query
    end
  end

  # Private helpers

  defp prepare_query_context(options) do
    debug_mode = Map.get(TableConfig.get_table_options(table_options()), :debug, :off)

    {regular_filters, transformers} =
      Map.get(options, "filters", nil)
      |> separate_filters_and_transformers()

    {regular_filters, transformers, debug_mode}
  end

  defp separate_filters_and_transformers(filters) when is_map(filters) do
    {transformers, regular_filters} =
      filters
      |> Enum.split_with(fn {_, filter} ->
        match?(%LiveTable.Transformer{}, filter)
      end)

    {Map.new(regular_filters), Map.new(transformers)}
  end

  defp separate_filters_and_transformers(nil), do: {%{}, %{}}

  defp apply_transformers(query, transformers) do
    Enum.reduce(transformers, query, fn {_key, transformer}, acc ->
      LiveTable.Transformer.apply(acc, transformer)
    end)
  end

  # Extract associations from fields that have :assoc key
  defp get_field_assocs(fields) do
    fields
    |> Enum.map(fn
      {_name, %{assoc: {assoc_name, _}}} -> assoc_name
      _ -> nil
    end)
    |> Enum.reject(&is_nil/1)
  end

  # Extract associations from filters
  defp get_filter_assocs(filters) do
    filters
    |> Enum.map(fn
      {_name, %{field: {assoc_name, _}}} -> assoc_name
      _ -> nil
    end)
    |> Enum.reject(&is_nil/1)
  end

  # Enhanced select_columns that handles assoc fields
  defp select_columns_with_assocs(query, fields) do
    select_struct =
      Enum.flat_map(fields, fn
        {name, %{computed: dynamic_expr}} ->
          [{name, dynamic_expr}]

        {name, %{assoc: {assoc_name, field_name}}} ->
          [{name, dynamic([{^assoc_name, a}], field(a, ^field_name))}]

        {name, _opts} ->
          [{name, dynamic([resource: r], field(r, ^name))}]
      end)
      |> Enum.into(%{})

    select(query, ^select_struct)
  end
end
