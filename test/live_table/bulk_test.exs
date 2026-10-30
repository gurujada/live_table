defmodule LiveTable.BulkTest do
  use LiveTable.DataCase

  import Ecto.Query
  import LiveTable.Fixtures

  alias LiveTable.{Bulk, Repo}
  alias LiveTable.Catalog.Product

  test "narrows a joined, grouped query to the chosen rows" do
    alpha = product_fixture(%{name: "Alpha", stock_quantity: 1})
    beta = product_fixture(%{name: "Beta", stock_quantity: 1})

    table_query =
      from p in Product,
        left_join: s in assoc(p, :suppliers),
        group_by: p.id,
        order_by: p.name,
        select: %{id: p.id, name: p.name, suppliers: count(s.id)}

    assert {1, _} = Repo.update_all(Bulk.query(table_query, [alpha.id]), set: [stock_quantity: 0])
    assert Repo.reload!(alpha).stock_quantity == 0
    assert Repo.reload!(beta).stock_quantity == 1

    assert {2, _} = Repo.delete_all(Bulk.query(table_query, :all))
  end

  test "keeps the table's filters for :all" do
    product_fixture(%{name: "Alpha"})
    beta = product_fixture(%{name: "Beta"})

    table_query = from p in Product, where: p.name == "Alpha"

    assert {1, _} = Repo.delete_all(Bulk.query(table_query, :all))
    assert Repo.reload(beta)
  end

  test "casts ids from the browser and drops ones that don't cast" do
    alpha = product_fixture(%{name: "Alpha"})
    product_fixture(%{name: "Beta"})

    query = Bulk.query(from(p in Product), [to_string(alpha.id), "nope"])

    assert [%{id: id}] = Repo.all(query)
    assert id == alpha.id
  end
end
