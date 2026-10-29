defmodule LiveTable.Join do
  @moduledoc false

  import Ecto.Query

  # Adds LEFT JOINs to the query for any fields that reference associations
  # Fields are expected to be a map where values can include:
  # - %{assoc: {assoc_name, field_name}} for associated fields
  # - %{computed: dynamic_expr} for computed fields
  def join_associations(query, filters) do
    filter_assocs = get_filter_assocs(filters)

    filter_assocs
    |> Enum.uniq()
    |> Enum.reduce(query, fn
      assoc_name, query ->
        if has_named_binding?(query, assoc_name) do
          query
        else
          join(query, :left, [r], s in assoc(r, ^assoc_name), as: ^assoc_name)
        end
    end)
  end

  # Builds a select statement that includes:
  # - Regular fields from the main table
  # - Fields from associated tables
  # - Computed fields using dynamic expressions
  # - The primary key, which identifies each row
  def select_columns(query, fields) do
    key = Enum.map(primary_key(query), &{&1, dynamic([resource: r], field(r, ^&1))})

    select_struct =
      Enum.flat_map(fields, fn
        {name, %{computed: dynamic_expr}} ->
          [{name, dynamic_expr}]

        {name, _opts} ->
          [{name, dynamic([resource: r], field(r, ^name))}]
      end)
      |> Enum.into(Map.new(key))

    select(query, ^select_struct)
  end

  # The primary key of the query's root schema, or :id when it has none.
  def primary_key(%Ecto.Query{from: %{source: {_, schema}}}) when schema != nil,
    do: schema.__schema__(:primary_key)

  def primary_key(_query), do: [:id]

  defp get_filter_assocs(filters) do
    filters
    |> Enum.map(fn
      {_name, %{field: {assoc_name, _}}} -> assoc_name
      _ -> nil
    end)
    |> Enum.reject(&is_nil/1)
  end
end
