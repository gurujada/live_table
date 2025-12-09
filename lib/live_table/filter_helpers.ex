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
          params
          |> Enum.reduce(existing_filters, fn
            {k, "true"}, acc ->
              %{field: _, key: key} = get_filter(k)
              Map.put(acc, k, key)

            {key, %{"max" => max, "min" => min}}, acc ->
              Map.put(acc, key, min: min, max: max)

            {k, "false"}, acc ->
              Map.delete(acc, k)

            {key, ["[" <> rest]}, acc ->
              case get_filter(key) do
                %LiveTable.Select{} ->
                  id = ("[" <> rest) |> Jason.decode!() |> List.first()
                  Map.put(acc, key, %{id: [id]})

                true ->
                  acc
              end

            {key, custom_data}, acc when is_map(custom_data) ->
              case get_filter(key) do
                %LiveTable.Transformer{} ->
                  Map.put(acc, key, custom_data)

                _ ->
                  acc
              end

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
