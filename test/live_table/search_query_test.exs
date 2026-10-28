defmodule LiveTable.SearchQueryTest do
  use LiveTable.DataCase
  import Ecto.Query

  alias LiveTable.{Filter, Repo}
  alias LiveTable.Catalog.Product

  setup do
    for {name, stock} <- [{"50% off", 7}, {"500 off", 8}, {"a_b", 9}, {"axb", 10}, {"wow!", 11}] do
      Repo.insert!(%Product{name: name, price: Decimal.new(1), stock_quantity: stock})
    end

    :ok
  end

  defp search(term, fields, mode) do
    from(p in Product, select: p.name)
    |> Filter.apply_filters(%{"search" => term}, fields, mode)
    |> Repo.all()
    |> Enum.sort()
  end

  for mode <- [:ilike, :like_lower] do
    test "#{mode}: %, _ and ! in the search term match literally" do
      fields = [name: %{searchable: true}]

      assert search("50%", fields, unquote(mode)) == ["50% off"]
      assert search("a_b", fields, unquote(mode)) == ["a_b"]
      assert search("w!", fields, unquote(mode)) == ["wow!"]
    end
  end

  test "ilike: a numeric column can be searchable" do
    fields = [name: %{searchable: true}, stock_quantity: %{searchable: true}]

    assert search("10", fields, :ilike) == ["axb"]
  end
end
