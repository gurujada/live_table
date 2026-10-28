defmodule LiveTable.ParseHelpers do
  def parse_sort_params(params, default_sort, fields) do
    case Map.get(params, "sort_params", default_sort) do
      sort_params when is_map(sort_params) or is_list(sort_params) ->
        Enum.flat_map(sort_params, fn
          {k, v} when is_atom(k) and is_atom(v) ->
            [{k, v}]

          # Keys come from the URL: keep only fields in fields/0
          {k, v} when v in ["asc", "desc"] ->
            for {name, _} <- fields,
                Atom.to_string(name) == k,
                do: {name, String.to_existing_atom(v)}

          _ ->
            []
        end)

      _ ->
        default_sort
    end
  end

  def parse_filters(params, socket, filters) do
    raw_filters = if is_map(params["filters"]), do: params["filters"], else: %{}
    initial_load? = not Map.has_key?(socket.assigns, :options)

    parsed =
      raw_filters
      # Keys and values come from the URL: drop any that don't match a filter in filters/0
      |> Map.filter(fn {key, value} -> valid_filter?(get_filter(key, filters), value) end)
      |> Map.put("search", params["search"] || "")
      |> Enum.reduce(%{}, fn
        {"search", search_term}, acc ->
          Map.put(acc, "search", search_term)

        # By the filter's type, not the value's shape: a Transformer's data can have any keys
        {key, value}, acc ->
          case get_filter(key, filters) do
            %LiveTable.Range{} ->
              parse_range_filter(key, value["min"], value["max"], acc, filters)

            %LiveTable.Select{} ->
              parse_select_filter(key, value["id"], acc, filters)

            %LiveTable.Transformer{} ->
              parse_custom_filter(key, value, acc, filters)

            filter ->
              Map.put(acc, String.to_existing_atom(key), filter)
          end
      end)

    if raw_filters == %{} and initial_load?,
      do: apply_default_filters(parsed, filters),
      else: parsed
  end

  defp valid_filter?(%LiveTable.Boolean{}, value), do: is_binary(value)

  defp valid_filter?(%LiveTable.Range{}, %{"min" => min, "max" => max}),
    do: is_binary(min) and is_binary(max)

  defp valid_filter?(%LiveTable.Select{}, %{"id" => ids}), do: is_list(ids)
  defp valid_filter?(%LiveTable.Transformer{}, value), do: is_map(value)
  defp valid_filter?(_filter, _value), do: false

  defp apply_default_filters(parsed, filters) do
    Enum.reduce(filters, parsed, fn
      {key, %LiveTable.Boolean{options: %{default: true}} = filter}, acc ->
        Map.put(acc, key, filter)

      _, acc ->
        acc
    end)
  end

  defp parse_range_filter(key, min, max, acc, filters) do
    filter = get_filter(key, filters)
    {min_val, max_val} = parse_range_values(filter.options, min, max)

    updated_filter =
      filter
      |> Map.update!(:options, fn options ->
        options
        |> Map.put(:current_min, min_val)
        |> Map.put(:current_max, max_val)
      end)

    Map.put(acc, String.to_existing_atom(key), updated_filter)
  end

  defp parse_select_filter(key, id, acc, filters) do
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

  defp parse_custom_filter(key, custom_data, acc, filters) do
    filter = get_filter(key, filters)
    updated_filter = %{filter | options: Map.put(filter.options, :applied_data, custom_data)}
    Map.put(acc, String.to_existing_atom(key), updated_filter)
  end

  def get_filter(key, filters) when is_binary(key) do
    Enum.find_value(filters, fn {name, filter} -> Atom.to_string(name) == key && filter end)
  end

  def get_filter(key, filters) when is_atom(key) do
    Keyword.get(filters, key)
  end

  # Blank or non-numeric bounds (an emptied input, a hand-edited URL) fall back to the defaults.
  defp parse_range_values(options, min, max) do
    {parse_bound(min, options.step, options.default_min),
     parse_bound(max, options.step, options.default_max)}
  end

  defp parse_bound(value, step, default) do
    parser = if is_integer(step), do: &Integer.parse/1, else: &Float.parse/1

    case parser.(to_string(value)) do
      {number, _} -> number
      :error -> default
    end
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

  defp validate_page_num(n) when is_binary(n) do
    case Integer.parse(n) do
      {num, ""} when num > 0 -> n
      _ -> "1"
    end
  end

  defp validate_page_num(_), do: "1"

  defp validate_per_page(n, table_options) when is_binary(n) do
    max_per_page = table_options[:max_per_page]

    case Integer.parse(n) do
      {num, ""} when num > 0 and num <= max_per_page -> n
      {num, ""} when num > max_per_page -> max_per_page |> to_string()
      _ -> table_options[:default_size] |> to_string()
    end
  end

  defp validate_per_page(_, table_options),
    do: table_options[:default_size] |> to_string()
end
