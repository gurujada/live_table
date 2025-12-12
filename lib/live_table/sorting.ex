defmodule LiveTable.Sorting do
  @moduledoc false
  import Ecto.Query

  def maybe_sort(query, _, _, false), do: query

  def maybe_sort(query, fields, sort_params, true) do
    sort(query, fields, sort_params)
  end

  def sort(query, fields, sort_params) do
    sorts =
      Enum.reduce(sort_params, [], fn
        {sort_by, sort_order}, acc ->
          sort_expr =
            Enum.find_value(fields, fn
              {^sort_by, %{sortable: true, assoc: {assoc_name, field}}} ->
                dynamic([{^assoc_name, a}], field(a, ^field))

              {^sort_by, %{sortable: true, computed: fragment}} ->
                fragment

              {^sort_by, %{sortable: true}} ->
                dynamic([a], field(a, ^sort_by))

              _ ->
                nil
            end)

          case sort_expr do
            nil -> acc
            expr -> acc ++ [{sort_order, expr}]
          end

        _, acc ->
          acc
      end)

    from query, order_by: ^sorts
  end
end
