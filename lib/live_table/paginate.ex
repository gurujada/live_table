defmodule LiveTable.Paginate do
  @moduledoc false
  import Ecto.Query

  def maybe_paginate(query, _, false), do: query

  def maybe_paginate(query, paginate_params, true) do
    query
    |> paginate(paginate_params)
  end

  def paginate(query, %{"per_page" => per_page, "page" => page}) do
    page = page |> String.to_integer()
    per_page = per_page |> String.to_integer()

    offset = max((page - 1) * per_page, 0)
    limit = per_page + 1

    query
    |> limit(^limit)
    |> offset(^offset)
  end
end
