defmodule LiveTable.Bulk do
  @moduledoc false

  import Ecto.Query

  # The rows of the table's query with these primary keys, or all of them with :all, as a plain
  # query on the root schema. Repo.update_all and delete_all accept it whatever joins, grouping
  # or select the table's query has.
  def query(table_query, ids) do
    key =
      case LiveTable.Join.primary_key(table_query) do
        [key] -> key
        _ -> raise ArgumentError, "LiveTable bulk actions need a single-column primary key."
      end

    chosen =
      table_query
      |> exclude(:select)
      |> exclude(:order_by)
      |> exclude(:preload)
      |> select([r], field(r, ^key))

    chosen =
      if ids == :all,
        do: chosen,
        else: where(chosen, [r], field(r, ^key) in ^cast(table_query, key, ids))

    table_query.from.source
    |> Ecto.Queryable.to_query()
    |> where([r], field(r, ^key) in subquery(chosen))
  end

  # Ids from the browser are strings; ones that don't cast to the key's type match no row.
  defp cast(%Ecto.Query{from: %{source: {_, schema}}}, key, ids) when schema != nil do
    type = schema.__schema__(:type, key)
    for id <- ids, {:ok, id} <- [Ecto.Type.cast(type, id)], do: id
  end

  defp cast(_query, _key, ids), do: ids
end
