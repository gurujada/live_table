defmodule LiveTable.CsvGeneratorTest do
  use LiveTable.DataCase
  import Ecto.Query
  alias LiveTable.CsvGenerator
  alias LiveTable.Catalog.Product
  alias LiveTable.Repo
  alias NimbleCSV.RFC4180, as: CSV

  setup do
    Repo.insert!(%Product{
      name: "Test Product 1",
      description: "Description 1",
      price: Decimal.new("19.99"),
      stock_quantity: 100
    })

    Repo.insert!(%Product{
      name: "Test Product 2",
      description: "Description 2",
      price: Decimal.new("29.99"),
      stock_quantity: 200
    })

    :ok
  end

  defp export(query, columns) do
    {:ok, csv} =
      Repo.transaction(fn ->
        query |> CsvGenerator.stream(columns) |> Enum.to_list() |> IO.iodata_to_binary()
      end)

    csv
  end

  describe "stream/2" do
    test "writes the labels, then each row's values in column order" do
      query =
        from(p in Product,
          order_by: p.name,
          select: %{name: p.name, price: p.price, stock: p.stock_quantity}
        )

      csv = export(query, name: "Name", price: "Price", stock: "Stock Quantity")

      assert CSV.parse_string(csv, skip_headers: false) == [
               ["Name", "Price", "Stock Quantity"],
               ["Test Product 1", "19.99", "100"],
               ["Test Product 2", "29.99", "200"]
             ]
    end

    test "writes only the header for an empty result" do
      Repo.delete_all(Product)

      assert export(from(p in Product, select: %{name: p.name}), name: "Name") == "Name\r\n"
    end

    test "streams large results completely" do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      Repo.insert_all(
        Product,
        for i <- 1..2500 do
          %{name: "Product #{i}", price: Decimal.new(i), inserted_at: now, updated_at: now}
        end
      )

      csv = export(from(p in Product, select: %{name: p.name}), name: "Name")

      # The header, the 2 products from setup and the 2500 inserted here.
      assert csv |> String.split("\r\n", trim: true) |> length() == 2503
    end

    test "keeps cells that spreadsheets would run as formulas as text" do
      for name <- ["=1+1", "+1", "-1", "@SUM(A1)", "\tx", "\rx"] do
        Repo.insert!(%Product{name: name, price: Decimal.new(1)})
      end

      csv = export(from(p in Product, select: %{name: p.name}), name: "Name")
      names = CSV.parse_string(csv) |> List.flatten()

      for name <- ["=1+1", "+1", "-1", "@SUM(A1)", "\tx", "\rx"] do
        assert ("'" <> name) in names
      end

      assert "Test Product 1" in names
    end
  end
end
