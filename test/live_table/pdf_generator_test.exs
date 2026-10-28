defmodule LiveTable.PdfGeneratorTest do
  use LiveTable.DataCase
  import Ecto.Query

  alias LiveTable.PdfGenerator
  alias LiveTable.Catalog.Product
  alias LiveTable.Repo

  setup do
    Repo.insert!(%Product{name: "Test Product 1", price: Decimal.new("19.99")})
    :ok
  end

  describe "render/2" do
    test "returns a PDF" do
      query = from(p in Product, select: %{name: p.name, price: p.price})

      assert {:ok, "%PDF" <> _} = PdfGenerator.render(query, name: "Name", price: "Price")
    end

    test "renders an empty result" do
      Repo.delete_all(Product)

      assert {:ok, "%PDF" <> _} =
               PdfGenerator.render(from(p in Product, select: %{name: p.name}), name: "Name")
    end

    test "treats cell values as text, never as Typst markup or code" do
      for name <- [
            ~S|#read("export.typ")|,
            ~S|say "hi" \ bye|,
            "[*bold*] @ref $x$ <label>"
          ] do
        Repo.insert!(%Product{name: name, price: Decimal.new(1)})
      end

      assert {:ok, "%PDF" <> _} =
               PdfGenerator.render(from(p in Product, select: %{name: p.name}), name: "Name")
    end

    test "leaves no files behind" do
      before = File.ls!(System.tmp_dir!())

      {:ok, _pdf} = PdfGenerator.render(from(p in Product, select: %{name: p.name}), name: "Name")

      assert File.ls!(System.tmp_dir!()) -- before == []
    end
  end
end
