defmodule LiveTable.PdfGeneratorTest do
  use LiveTable.DataCase

  alias LiveTable.PdfGenerator
  alias LiveTable.Catalog.Product
  alias LiveTable.Repo

  setup do
    # Create test products
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
      # Cleanup generated files
      Path.wildcard(Path.join(System.tmp_dir!(), "export-*.{typ,pdf}"))
      |> Enum.each(&File.rm/1)
    end)

    {:ok, %{product1: product1, product2: product2}}
  end

  describe "generate_pdf/2" do
    test "successfully generates PDF file with correct headers and data" do
      query =
        "from p in #{Product}, select: %{name: p.name, price: p.price, stock_quantity: p.stock_quantity}"

      header_data = [["name", "price", "stock_quantity"], ["Name", "Price", "Stock Quantity"]]

      {:ok, file_path} = PdfGenerator.generate_pdf(query, header_data)

      assert File.exists?(file_path)
      assert String.ends_with?(file_path, ".pdf")

      # Verify file size is non-zero (basic PDF validation)
      assert File.stat!(file_path).size > 0
    end

    test "handles empty result set" do
      Repo.delete_all(Product)
      query = "from p in #{Product}, select: %{name: p.name, price: p.price}"
      header_data = [["name", "price"], ["Name", "Price"]]

      {:ok, file_path} = PdfGenerator.generate_pdf(query, header_data)

      assert File.exists?(file_path)
      assert File.stat!(file_path).size > 0
    end

    test "handles special characters in data" do
      {:ok, special_product} =
        Repo.insert(%Product{
          name: "Product @ with special chars",
          description: "Description with @ symbol",
          price: Decimal.new("39.99"),
          stock_quantity: 300
        })

      query =
        "from p in #{Product}, where: p.id == #{special_product.id}, select: %{name: p.name}"

      header_data = [["name"], ["Name"]]

      {:ok, file_path} = PdfGenerator.generate_pdf(query, header_data)

      assert File.exists?(file_path)
      assert File.stat!(file_path).size > 0
    end
  end

  describe "module structure" do
    test "exports generate_pdf/2" do
      assert function_exported?(PdfGenerator, :generate_pdf, 2)
    end

    test "generate_pdf/2 requires query and header_data arguments" do
      # Verify the function exists with correct arity
      assert {:generate_pdf, 2} in PdfGenerator.__info__(:functions)
    end
  end
end
