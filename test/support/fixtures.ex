defmodule LiveTable.Fixtures do
  @moduledoc """
  Factory functions for creating test data.

  This module provides convenient functions for creating test records
  with sensible defaults. Use these in your tests to quickly set up
  the data you need.

  ## Examples

      # Create a product with defaults
      product = product_fixture()

      # Create a product with custom attributes
      product = product_fixture(%{name: "Custom Name", price: Decimal.new("50.00")})

      # Create a product with all associations
      product = product_with_associations_fixture()

      # Seed multiple products for pagination tests
      products = seed_products(25)
  """

  alias LiveTable.Repo
  alias LiveTable.Catalog.{Product, Category, Supplier, Image}

  @doc """
  Creates a category with default or custom attributes.

  ## Examples

      category = category_fixture()
      category = category_fixture(%{name: "Electronics"})
  """
  def category_fixture(attrs \\ %{}) do
    defaults = %{
      name: "Category #{System.unique_integer([:positive])}",
      description: "Test category description"
    }

    %Category{}
    |> struct!(Map.merge(defaults, attrs))
    |> Repo.insert!()
  end

  @doc """
  Creates a supplier with default or custom attributes.

  ## Examples

      supplier = supplier_fixture()
      supplier = supplier_fixture(%{name: "Acme Corp"})
  """
  def supplier_fixture(attrs \\ %{}) do
    defaults = %{
      name: "Supplier #{System.unique_integer([:positive])}",
      contact_info: "contact#{System.unique_integer([:positive])}@example.com",
      address: "123 Test Street"
    }

    %Supplier{}
    |> struct!(Map.merge(defaults, attrs))
    |> Repo.insert!()
  end

  @doc """
  Creates a product with default or custom attributes.

  Note: Does not create associations by default. Use `product_with_associations_fixture/1`
  for a product with category and suppliers.

  ## Examples

      product = product_fixture()
      product = product_fixture(%{name: "Widget", price: Decimal.new("29.99")})
  """
  def product_fixture(attrs \\ %{}) do
    defaults = %{
      name: "Product #{System.unique_integer([:positive])}",
      description: "Test product description",
      price: Decimal.new("99.99"),
      stock_quantity: 100
    }

    %Product{}
    |> struct!(Map.merge(defaults, attrs))
    |> Repo.insert!()
  end

  @doc """
  Creates an image associated with a product.

  ## Examples

      product = product_fixture()
      image = image_fixture(%{product_id: product.id})
  """
  def image_fixture(attrs \\ %{}) do
    defaults = %{
      url: "https://example.com/image#{System.unique_integer([:positive])}.jpg"
    }

    %Image{}
    |> struct!(Map.merge(defaults, attrs))
    |> Repo.insert!()
  end

  @doc """
  Creates a product with a category and optionally suppliers.

  Returns a map with the product and its associations for easy access in tests.

  ## Options

    * `:supplier_count` - Number of suppliers to create and associate (default: 1)
    * `:with_image` - Whether to create an associated image (default: false)

  ## Examples

      # Basic product with category and one supplier
      %{product: product, category: category, suppliers: [supplier]} =
        product_with_associations_fixture()

      # Product with multiple suppliers
      %{product: product, suppliers: suppliers} =
        product_with_associations_fixture(%{}, supplier_count: 3)

      # Product with image
      %{product: product, image: image} =
        product_with_associations_fixture(%{}, with_image: true)
  """
  def product_with_associations_fixture(product_attrs \\ %{}, opts \\ []) do
    supplier_count = Keyword.get(opts, :supplier_count, 1)
    with_image = Keyword.get(opts, :with_image, false)

    # Create category
    category = category_fixture()

    # Create product with category
    product = product_fixture(Map.put(product_attrs, :category_id, category.id))

    # Create suppliers and associate them
    suppliers =
      for _ <- 1..supplier_count do
        supplier = supplier_fixture()
        associate_product_supplier(product, supplier)
        supplier
      end

    # Optionally create image
    image =
      if with_image do
        image_fixture(%{product_id: product.id})
      else
        nil
      end

    result = %{
      product: product,
      category: category,
      suppliers: suppliers
    }

    if image, do: Map.put(result, :image, image), else: result
  end

  @doc """
  Associates a product with a supplier via the join table.

  ## Examples

      product = product_fixture()
      supplier = supplier_fixture()
      associate_product_supplier(product, supplier)
  """
  def associate_product_supplier(product, supplier) do
    timestamp = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    Repo.insert_all("products_suppliers", [
      %{
        product_id: product.id,
        supplier_id: supplier.id,
        inserted_at: timestamp,
        updated_at: timestamp
      }
    ])
  end

  @doc """
  Creates multiple products for pagination and bulk testing.

  Returns a list of products sorted by id.

  ## Options

    * `:with_category` - Associate all products with a single category (default: false)
    * `:price_range` - `{min, max}` tuple for random prices (default: {10, 500})

  ## Examples

      # Create 25 products
      products = seed_products(25)

      # Create products in same category
      products = seed_products(10, with_category: true)

      # Create products with specific price range
      products = seed_products(10, price_range: {100, 200})
  """
  def seed_products(count, opts \\ []) do
    with_category = Keyword.get(opts, :with_category, false)
    {min_price, max_price} = Keyword.get(opts, :price_range, {10, 500})

    category =
      if with_category do
        category_fixture()
      else
        nil
      end

    timestamp = DateTime.utc_now() |> DateTime.truncate(:second)

    products =
      for i <- 1..count do
        price = :rand.uniform(max_price - min_price) + min_price

        %{
          name: "Product #{String.pad_leading("#{i}", 4, "0")}",
          description: "Description for product #{i}",
          price: Decimal.new("#{price}.99"),
          stock_quantity: :rand.uniform(500),
          category_id: category && category.id,
          inserted_at: timestamp,
          updated_at: timestamp
        }
      end

    {_count, inserted} = Repo.insert_all(Product, products, returning: true)
    Enum.sort_by(inserted, & &1.id)
  end

  @doc """
  Cleans up all test data. Useful for tests that need a clean slate.

  ## Examples

      setup do
        clean_all()
        :ok
      end
  """
  def clean_all do
    Repo.delete_all("products_suppliers")
    Repo.delete_all(Image)
    Repo.delete_all(Product)
    Repo.delete_all(Supplier)
    Repo.delete_all(Category)
  end
end
