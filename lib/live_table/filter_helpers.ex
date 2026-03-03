defmodule LiveTable.FilterHelpers do
  @moduledoc false
  defmacro __using__(_opts) do
    quote do
      def get_filter(key) when is_binary(key) do
        key
        |> String.to_atom()
        |> get_filter()
      end

      def get_filter(key) when is_atom(key) do
        filters() |> Keyword.get(key)
      end

      defp update_filter_params(map, nil), do: map

      defp update_filter_params(map, params) do
        existing_filters = Map.get(map, "filters", %{})

        updated_params =
          Enum.reduce(params, existing_filters, fn
            {k, "true"}, acc ->
              %{field: _, key: key} = get_filter(k)
              Map.put(acc, k, key)

            {k, "false"}, acc ->
              Map.delete(acc, k)

            {key, %{"max" => max, "min" => min}}, acc ->
              Map.put(acc, key, min: min, max: max)

            # LiveSelect single mode — cleared
            {key, %{"value" => ""}}, acc ->
              Map.delete(acc, key)

            # LiveSelect single mode — structured value from form or pushEvent
            # Also handles Transformer filters that use %{"value" => ...} shape
            {key, %{"value" => value} = data}, acc ->
              case get_filter(key) do
                %LiveTable.Select{} -> Map.put(acc, key, %{id: [value]})
                %LiveTable.Transformer{} -> Map.put(acc, key, data)
                _ -> acc
              end

            # LiveSelect tags mode — id list from form, URL params, or pushEvent
            {key, %{"id" => ids}}, acc when is_list(ids) ->
              case get_filter(key) do
                %LiveTable.Select{} ->
                  filtered = Enum.reject(ids, &(&1 == ""))

                  if filtered == [],
                    do: Map.delete(acc, key),
                    else: Map.put(acc, key, %{id: filtered})

                _ ->
                  acc
              end

            # Transformer custom data
            {key, data}, acc when is_map(data) ->
              case get_filter(key) do
                %LiveTable.Transformer{} -> Map.put(acc, key, data)
                _ -> acc
              end

            # Cleared field
            {key, ""}, acc ->
              Map.delete(acc, key)

            _, acc ->
              acc
          end)

        Map.put(map, "filters", updated_params)
      end

      def encode_filters(filters) do
        Enum.reduce(filters, %{}, fn
          {k, %LiveTable.Range{options: %{current_min: min, current_max: max}}}, acc ->
            k = k |> to_string
            acc |> Map.merge(%{k => [min: min, max: max]})

          {k, %LiveTable.Boolean{field: _, key: key}}, acc ->
            k = k |> to_string
            acc |> Map.merge(%{k => key})

          {k, %LiveTable.Select{options: %{selected: selected}}}, acc ->
            k = k |> to_string
            acc |> Map.merge(%{k => %{id: selected}})

          {k, %LiveTable.Transformer{options: %{applied_data: applied_data}}}, acc
          when applied_data != %{} ->
            k = k |> to_string
            acc |> Map.merge(%{k => applied_data})

          _, acc ->
            acc
        end)
      end
    end
  end
end
