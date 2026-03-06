defmodule LiveTable.ParseHelpers do
  def parse_sort_params(params, default_sort) do
    Map.get(params, "sort_params", default_sort)
    |> Enum.map(fn
      {k, v} when is_atom(k) and is_atom(v) -> {k, v}
      {k, v} -> {String.to_existing_atom(k), String.to_existing_atom(v)}
    end)
  end

  def parse_filters(params, socket, filters) do
    raw_filters = Map.get(params, "filters", %{})
    initial_load? = not Map.has_key?(socket.assigns, :options)

    parsed =
      raw_filters
      |> Map.put("search", params["search"] || "")
      |> Enum.reduce(%{}, fn
        {"search", search_term}, acc ->
          Map.put(acc, "search", search_term)

        {key, %{"min" => min, "max" => max}}, acc ->
          parse_range_filter(key, min, max, acc, filters)

        {key, %{"id" => id}}, acc ->
          parse_select_filter(key, id, acc, filters)

        {key, custom_data}, acc when is_map(custom_data) ->
          parse_custom_filter(key, custom_data, acc, filters)

        {k, _}, acc ->
          key = k |> String.to_existing_atom()
          Map.put(acc, key, get_filter(k, filters))
      end)

    if raw_filters == %{} and initial_load?,
      do: apply_default_filters(parsed, filters),
      else: parsed
  end

  def apply_default_filters(parsed, filters) do
    Enum.reduce(filters, parsed, fn
      {key, %LiveTable.Boolean{options: %{default: true}} = filter}, acc ->
        Map.put(acc, key, filter)

      _, acc ->
        acc
    end)
  end

  def parse_range_filter(key, min, max, acc, filters) do
    filter = get_filter(key, filters)
    {min_val, max_val} = parse_range_values(filter.options, min, max)

    updated_filter =
      filter
      |> Map.update!(:options, fn options ->
        options
        |> Map.put(:current_min, min_val)
        |> Map.put(:current_max, max_val)
      end)

    Map.put(acc, String.to_atom(key), updated_filter)
  end

  def parse_select_filter(key, id, acc, filters) do
    filter = %LiveTable.Select{} = get_filter(key, filters)

    id =
      id
      |> Enum.flat_map(fn
        "" -> []
        values when is_list(values) -> Enum.map(values, &coerce_select_value/1)
        value -> [coerce_select_value(value)]
      end)

    filter = %{filter | options: Map.update!(filter.options, :selected, &(&1 ++ id))}
    Map.put(acc, String.to_existing_atom(key), filter)
  end

  def coerce_select_value(val) when is_binary(val) do
    case Integer.parse(val) do
      {int, ""} -> int
      _ -> val
    end
  end

  def coerce_select_value(val), do: val

  def parse_custom_filter(key, custom_data, acc, filters) do
    filter = get_filter(key, filters)

    case filter do
      %LiveTable.Transformer{} ->
        updated_filter = %{
          filter
          | options: Map.put(filter.options, :applied_data, custom_data)
        }

        Map.put(acc, String.to_existing_atom(key), updated_filter)

      _ ->
        Map.put(acc, String.to_existing_atom(key), filter)
    end
  end

  def get_filter(key, filters) when is_binary(key) do
    key
    |> String.to_atom()
    |> get_filter(filters)
  end

  def get_filter(key, filters) when is_atom(key) do
    Keyword.get(filters, key)
  end

  def parse_range_values(%{step: step}, min, max) when is_integer(step) do
    {min_int, _} = Integer.parse(min)
    {max_int, _} = Integer.parse(max)
    {min_int, max_int}
  end

  def parse_range_values(%{step: _step}, min, max) do
    {min_float, _} = Float.parse(min)
    {max_float, _} = Float.parse(max)
    {min_float, max_float}
  end

  def build_options(sort_params, filters, params, table_options) do
    %{
      "sort" => %{
        "sortable?" => get_in(table_options, [:sorting, :enabled]),
        "sort_params" => sort_params
      },
      "pagination" => %{
        "paginate?" => get_in(table_options, [:pagination, :enabled]),
        "page" => params["page"] |> validate_page_num(),
        "per_page" =>
          params["per_page"] |> validate_per_page(get_in(table_options, [:pagination]))
      },
      "filters" => filters
    }
  end

  def validate_page_num(nil), do: "1"

  def validate_page_num(n) when is_binary(n) do
    case Integer.parse(n) do
      {num, ""} when num > 0 -> n
      _ -> "1"
    end
  end

  def validate_per_page(nil, table_options),
    do: table_options[:default_size] |> to_string()

  def validate_per_page(n, table_options) when is_binary(n) do
    max_per_page = table_options[:max_per_page]

    case Integer.parse(n) do
      {num, ""} when num > 0 and num <= max_per_page -> n
      _ -> max_per_page |> to_string()
    end
  end
end
