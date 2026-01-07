defmodule LiveTable.Filter do
  @moduledoc false
  import Ecto.Query

  def apply_text_search(search_term, fields, opts \\ [])

  # Returns true for empty search terms to avoid unnecessary filtering
  def apply_text_search("", _, _opts) do
    true
  end

  # Builds a dynamic query for text search across multiple fields
  # Handles both direct table fields and associated table fields
  # Supports different search modes: :ilike (PostgreSQL), :like (case-sensitive), :like_lower (SQLite)
  def apply_text_search(search_term, fields, opts) do
    searchable_fields = get_searchable_fields(fields)
    search_mode = Keyword.get(opts, :search_mode, :ilike)

    Enum.reduce(searchable_fields, nil, fn
      field, nil when is_atom(field) ->
        build_field_condition(field, search_term, search_mode)

      field, acc when is_atom(field) ->
        condition = build_field_condition(field, search_term, search_mode)
        dynamic([p], ^acc or ^condition)

      {table_name, field}, nil ->
        build_assoc_condition(table_name, field, search_term, search_mode)

      {table_name, field}, acc ->
        condition = build_assoc_condition(table_name, field, search_term, search_mode)
        dynamic([{^table_name, p}], ^acc or ^condition)
    end)
  end

  # Build search condition for direct table fields
  defp build_field_condition(field, search_term, :ilike) do
    pattern = "%#{search_term}%"
    dynamic([p], ilike(field(p, ^field), ^pattern))
  end

  defp build_field_condition(field, search_term, :like) do
    pattern = "%#{search_term}%"
    dynamic([p], like(field(p, ^field), ^pattern))
  end

  defp build_field_condition(field, search_term, :like_lower) do
    pattern = "%#{String.downcase(search_term)}%"
    dynamic([p], fragment("lower(?) LIKE ?", field(p, ^field), ^pattern))
  end

    # Build search condition for associated table fields
  defp build_assoc_condition(table_name, field, search_term, :ilike) do
    pattern = "%#{search_term}%"
    dynamic([{^table_name, p}], ilike(field(p, ^field), ^pattern))
  end

  defp build_assoc_condition(table_name, field, search_term, :like) do
    pattern = "%#{search_term}%"
    dynamic([{^table_name, p}], like(field(p, ^field), ^pattern))
  end

  defp build_assoc_condition(table_name, field, search_term, :like_lower) do
    pattern = "%#{String.downcase(search_term)}%"
    dynamic([{^table_name, p}], fragment("lower(?) LIKE ?", field(p, ^field), ^pattern))
  end

  # Extracts fields marked as searchable from the fields configuration
  # Returns either [field_name] for direct fields or [{assoc_name, field_name}] for associations
  defp get_searchable_fields(fields) do
    fields
    |> Enum.flat_map(fn
      {_key, %{assoc: {assoc, field}, searchable: true}} ->
        [{assoc, field}]

      {field, %{searchable: true}} ->
        [field]

      _ ->
        []
    end)
  end

  # Function head declares the default parameter for opts
  def apply_filters(query, filters, fields, opts \\ [])

  # Skip filtering if only an empty search parameter is present
  def apply_filters(query, %{"search" => ""} = filters, _, _opts) when map_size(filters) == 1, do: query

  # Applies both text search and custom filters to the query
  # Combines all conditions with AND operations
  def apply_filters(query, filters, fields, opts) do
    conditions =
      filters
      |> Enum.reduce(true, fn
        {"search", search_term}, acc ->
          text_search_condition = apply_text_search(search_term, fields, opts)
          dynamic(^acc and ^text_search_condition)

        {_filter_key, filter}, acc ->
          filter.__struct__.apply(acc, filter)
      end)

    where(query, ^conditions)
  end
end
