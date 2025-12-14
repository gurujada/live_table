# New module
defmodule LiveTable.Transformer do
  @moduledoc """
  Transformers provide complete control over query modification in LiveTable.

  Unlike simple filters that add WHERE conditions, transformers receive the full
  Ecto query and can perform any operations: joins, aggregations, subqueries,
  GROUP BY, ORDER BY overrides, and complex transformations.

  ## Why Transformers?

  Transformers are LiveTable's most powerful feature, enabling:

  - Complex multi-table filtering that can't be expressed with simple conditions
  - Dynamic sorting based on user input
  - Aggregations and computed metrics
  - Role-based query modifications
  - Any custom query logic

  ## Basic Usage

      def filters do
        [
          sales_filter: Transformer.new("sales_filter", %{
            query_transformer: &apply_sales_filter/2
          })
        ]
      end

      defp apply_sales_filter(query, filter_data) do
        case filter_data do
          %{"min_sales" => min} when min != "" ->
            from p in query,
              join: s in Sale, on: s.product_id == p.id,
              group_by: p.id,
              having: sum(s.amount) >= ^String.to_integer(min)
          _ ->
            query
        end
      end

  ## Transformer Function Signature

  Transformer functions receive two arguments and must return a query:

      def my_transformer(query, filter_data) do
        # query: The current Ecto query
        # filter_data: Map of applied filter data from URL/form
        # Returns: Modified Ecto query
        query
      end

  ## Configuration Options

  - `:query_transformer` - Required. Function or `{module, function}` tuple.
    - Function: `&my_function/2` or `fn query, data -> query end`
    - MFA: `{MyApp.Filters, :transform_query}`

  ## State Management

  Transformer state persists in URL parameters. Access applied data in templates:

      Map.get(@options["filters"], :my_transformer).options.applied_data["field"]

  ## See Also

  - [Transformers API Reference](transformers.html) - Complete documentation with examples
  - [Complex Queries Guide](complex-queries.html) - Real-world transformer patterns
  """

  defstruct [:key, :options]

  @doc false
  def new(key, options) do
    %__MODULE__{key: key, options: options}
  end

  @doc false
  def render(assigns) do
    render_assigns = %{
      key: assigns.filter.key,
      label: Map.get(assigns.filter.options, :label),
      value: Map.get(assigns.filter.options, :applied_data, %{})
    }

    assigns.filter.options.render.(render_assigns)
  end

  @doc false
  # This gets the full query, not dynamic conditions
  def apply(query, %__MODULE__{options: %{query_transformer: transformer}} = filter) do
    filter_data = Map.get(filter.options, :applied_data, %{})

    case transformer do
      {module, function} -> apply(module, function, [query, filter_data])
      transformer when is_function(transformer, 2) -> transformer.(query, filter_data)
      _ -> query
    end
  end
end
