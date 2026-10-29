defmodule LiveTable.RowDomIdTest do
  use ExUnit.Case, async: true

  import LiveTable.SortHelpers, only: [row_dom_id: 2]

  test "joins the primary key values" do
    assert row_dom_id(%{id: 7, name: "Alpha"}, [:id]) == "resource-7"
    assert row_dom_id(%{order_id: 1, line: 2}, [:order_id, :line]) == "resource-1-2"
  end

  test "asks for the primary key when a row lacks it" do
    assert_raise ArgumentError, ~r/a row has no :id/, fn ->
      row_dom_id(%{name: "Alpha"}, [:id])
    end
  end

  test "rejects schemas without a primary key" do
    assert_raise ArgumentError, ~r/the schema has none/, fn ->
      row_dom_id(%{name: "Alpha"}, [])
    end
  end
end
