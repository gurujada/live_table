defmodule LiveTable.CsvGeneratorTest do
  use LiveTable.DataCase
  import Ecto.Query
  alias LiveTable.CsvGenerator
  alias LiveTable.Catalog.Product
  alias LiveTable.Repo
  alias NimbleCSV.RFC4180, as: CSV

  setup do
    # Create some test products
    {:ok, product1} =
      Repo.insert(%Product{
        name: "Test Product 1",
        description: "Description 1",
        price: Decimal.new("19.99"),
        stock_quantity: 100
      })

    {:ok, product2} =
      Repo.insert(%Product{
        name: "Test Product 2",
        description: "Description 2",
        price: Decimal.new("29.99"),
        stock_quantity: 200
      })

    on_exit(fn ->
      Path.wildcard(Path.join(System.tmp_dir!(), "export-*.csv"))
      |> Enum.each(&File.rm/1)
    end)

    {:ok, %{product1: product1, product2: product2}}
  end

  describe "generate_csv/2" do
    test "successfully generates CSV file with correct headers and data" do
      query =
        from(p in Product,
          select: %{name: p.name, price: p.price, stock_quantity: p.stock_quantity}
        )

      header_data = [["name", "price", "stock_quantity"], ["Name", "Price", "Stock Quantity"]]

      {:ok, file_path} = CsvGenerator.generate_csv(query, header_data)

      assert File.exists?(file_path)

      file_content = File.read!(file_path)

      [header_row | data_rows] =
        file_content
        |> String.split("\r\n", trim: true)
        |> Enum.map(&String.split(&1, ","))

      assert header_row == Enum.at(header_data, 1)
      assert length(data_rows) == 2

      assert Enum.any?(data_rows, fn row ->
               Enum.at(row, 0) == "Test Product 1" &&
                 Enum.at(row, 1) == "19.99" &&
                 Enum.at(row, 2) == "100"
             end)
    end

    test "handles empty result set" do
      Repo.delete_all(Product)
      query = from(p in Product, select: %{name: p.name, price: p.price})
      header_data = [["name", "price"], ["Name", "Price"]]

      {:ok, file_path} = CsvGenerator.generate_csv(query, header_data)

      assert File.exists?(file_path)
      file_content = File.read!(file_path)
      rows = String.split(file_content, "\r\n", trim: true)
      # Only header row
      assert length(rows) == 1
      assert hd(rows) == "Name,Price"
    end

    test "processes data in chunks of 1000" do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      products =
        for i <- 1..2500 do
          %{
            name: "Product #{i}",
            description: "Description #{i}",
            price: Decimal.new("#{i}.99"),
            stock_quantity: i,
            inserted_at: now,
            updated_at: now
          }
        end

      Repo.insert_all(Product, products)

      query =
        from(p in "products", select: %{name: p.name, price: p.price, stock: p.stock_quantity})

      headers_labels = ["Name", "Price", "Stock Quantity"]

      headers_keys = ["name", "price", "stock_quantity"]
      header_data = [headers_keys, headers_labels]

      chunk_spy = spawn(fn -> chunk_monitor() end)
      Process.register(chunk_spy, :chunk_monitor)

      {:ok, file_path} = CsvGenerator.generate_csv(query, header_data)
      chunks = get_chunks()

      content = File.read!(file_path)
      lines = String.split(content, "\r\n", trim: true)

      File.rm!(file_path)
      # 2500 records should be processed in 3 chunks
      assert length(chunks) == 3
      assert Enum.all?(Enum.take(chunks, 2), fn chunk_size -> chunk_size == 1000 end)
      # Dont know why it has 502 records
      assert List.last(chunks) == 502

      # Why 2503 records?
      assert length(lines) == 2503
      assert Enum.at(lines, 0) == "Name,Price,Stock Quantity"
    end

    defp chunk_monitor(chunks \\ []) do
      receive do
        {:chunk, size} ->
          chunk_monitor([size | chunks])

        {:get_chunks, pid} ->
          send(pid, {:chunks, Enum.reverse(chunks)})
      end
    end

    defp get_chunks do
      send(:chunk_monitor, {:get_chunks, self()})

      receive do
        {:chunks, chunks} -> chunks
      after
        5000 -> raise "Timeout waiting for chunks"
      end
    end

    test "verifies headers align with correct data columns" do
      query =
        from(p in "products", select: %{name: p.name, price: p.price, stock: p.stock_quantity})

      headers_labels = ["Name", "Price", "Stock Quantity"]

      headers_keys = ["name", "price", "stock"]
      header_data = [headers_keys, headers_labels]

      {:ok, csv_path} = CsvGenerator.generate_csv(query, header_data)

      rows =
        csv_path
        |> File.read!()
        |> CSV.parse_string()

      assert rows == [["Test Product 1", "19.99", "100"], ["Test Product 2", "29.99", "200"]]

      File.rm!(csv_path)
    end
  end

  describe "the export query codec" do
    test "round-trips a query exactly" do
      query =
        from(p in Product,
          where: p.price > ^Decimal.new("20.00"),
          select: %{name: p.name, price: p.price},
          order_by: [desc: p.price]
        )

      decoded = query |> LiveTable.Export.encode_query() |> LiveTable.Export.decode_query()

      assert decoded == query

      # And it still produces the same SQL and params.
      repo = LiveTable.Repo

      assert Ecto.Adapters.SQL.to_sql(:all, repo, decoded) ==
               Ecto.Adapters.SQL.to_sql(:all, repo, query)
    end

    test "round-trips a large pinned list, as a Select filter produces" do
      values = Enum.to_list(1..200)
      query = from(p in Product, where: p.id in ^values)

      decoded = query |> LiveTable.Export.encode_query() |> LiveTable.Export.decode_query()

      assert decoded == query
    end

    test "does not eval anything: the payload is opaque" do
      encoded = from(p in Product) |> LiveTable.Export.encode_query()

      refute encoded =~ "Ecto.Query"
      refute encoded =~ "Product"

      # A payload that is not a query is refused rather than interpreted.
      assert_raise ArgumentError, fn ->
        LiveTable.Export.decode_query(Base.encode64("not a query"))
      end
    end

    test "refuses corrupt payloads" do
      assert_raise ArgumentError, ~r/corrupt export query payload/, fn ->
        LiveTable.Export.decode_query("!!!not base64!!!")
      end
    end

    test "refuses a non-binary payload" do
      assert_raise ArgumentError, ~r/expected an encoded export query/, fn ->
        LiveTable.Export.decode_query(%{})
      end
    end
  end
end
