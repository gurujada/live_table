defmodule LiveTable.FilterHelpers do
  @moduledoc false
  defmacro __using__(_opts) do
    quote do
      def get_filter(key) when is_binary(key) do
        key
        |> String.to_existing_atom()
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

            {key, "[" <> rest}, acc ->
              case get_filter(key) do
                %LiveTable.Select{} ->
                  id = ("[" <> rest) |> Jason.decode!() |> List.first()
                  Map.put(acc, key, %{id: [id]})

                true ->
                  acc
              end

            _, acc ->
              acc
          end)

        Map.put(map, "filters", updated_params)
      end

      def encode_filters(filters) do
        Enum.reduce(filters, %{}, fn
          {k, %LiveTable.Range{options: %{current_min: min, current_max: max, type: :number}}},
          acc ->
            k = k |> to_string
            acc |> Map.merge(%{k => [min: min, max: max]})

          {k, %LiveTable.Range{options: %{current_min: min, current_max: max, type: :date}}},
          acc ->
            k = k |> to_string
            min = min |> Date.to_iso8601()
            max = max |> Date.to_iso8601()
            acc |> Map.merge(%{k => [min: min, max: max]})

          {k, %LiveTable.Range{options: %{current_min: min, current_max: max, type: :datetime}}},
          acc ->
            k = k |> to_string
            min = min |> NaiveDateTime.to_iso8601()
            max = max |> NaiveDateTime.to_iso8601()
            acc |> Map.merge(%{k => [min: min, max: max]})

          {k, %LiveTable.Boolean{field: _, key: key}}, acc ->
            k = k |> to_string
            acc |> Map.merge(%{k => key})

          {k, %LiveTable.Select{options: %{selected: selected}}}, acc ->
            k = k |> to_string
            acc |> Map.merge(%{k => %{id: selected}})

          _, acc ->
            acc
        end)
      end
    end
  end
end
