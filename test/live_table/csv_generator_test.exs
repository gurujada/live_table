defmodule LiveTable.CsvGeneratorTest do
  use LiveTable.DataCase
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
        "from p in #{Product}, select: %{name: p.name, price: p.price, stock_quantity: p.stock_quantity}"

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
      query = "from p in #{Product}, select: %{name: p.name, price: p.price}"
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

      query_string =
        "#Ecto.Query<from p in \"products\", select: %{name: p.name, price: p.price, stock: p.stock_quantity}>"

      headers_labels = ["Name", "Price", "Stock Quantity"]

      headers_keys = ["name", "price", "stock_quantity"]
      header_data = [headers_keys, headers_labels]

      chunk_spy = spawn(fn -> chunk_monitor() end)
      Process.register(chunk_spy, :chunk_monitor)

      {:ok, file_path} = CsvGenerator.generate_csv(query_string, header_data)
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
      query_string =
        "#Ecto.Query<from p in \"products\", select: %{name: p.name, price: p.price, stock: p.stock_quantity}>"

      headers_labels = ["Name", "Price", "Stock Quantity"]

      headers_keys = ["name", "price", "stock"]
      header_data = [headers_keys, headers_labels]

      {:ok, csv_path} = CsvGenerator.generate_csv(query_string, header_data)

      rows =
        csv_path
        |> File.read!()
        |> CSV.parse_string()

      assert rows == [["Test Product 1", "19.99", "100"], ["Test Product 2", "29.99", "200"]]

      File.rm!(csv_path)
    end
  end

  describe "get_query/1" do
    test "successfully converts query string to Ecto query" do
      query_string = "from p in #{Product}, select: %{name: p.name, price: p.price}"
      result = CsvGenerator.get_query(query_string)

      assert %Ecto.Query{} = result
    end

    test "handles complex queries with conditions" do
      query_string = """
      from p in #{Product},
        where: p.price > 20.00,
        select: %{name: p.name, price: p.price, stock_quantity: p.stock_quantity}
      """

      result = CsvGenerator.get_query(query_string)

      assert %Ecto.Query{} = result

      # Verify the query returns expected results
      data = Repo.all(result)
      assert length(data) == 1
      product = hd(data)
      assert product.name == "Test Product 2"
      assert Decimal.compare(product.price, Decimal.new("20.00")) == :gt
    end
  end

  describe "error handling" do
    test "handles invalid query string" do
      import ExUnit.CaptureIO

      # Capture stderr to suppress the "undefined function" error from Code.eval_string
      capture_io(:stderr, fn ->
        assert_raise ArgumentError, "Invalid Ecto query string", fn ->
          CsvGenerator.get_query("invalid query string")
        end
      end)
    end

    test "handles valid query string" do
      valid_query = "#Ecto.Query<from p in \"products\", select: {p.name, p.price}>"
      result = CsvGenerator.get_query(valid_query)
      assert %Ecto.Query{} = result
    end
  end
end
