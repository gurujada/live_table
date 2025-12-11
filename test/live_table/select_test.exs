defmodule LiveTable.SelectTest do
  use LiveTable.DataCase
  import Phoenix.LiveViewTest
  alias LiveTable.{Select, Repo, Catalog.Product, Catalog.Category, Catalog.Supplier}

  describe "Select.new/3" do
    test "creates struct with correct attributes" do
      field = {:categories, :id}
      key = "category-select"

      options = %{
        label: "Category",
        placeholder: "Select category"
      }

      result = Select.new(field, key, options)

      assert %Select{} = result
      assert result.field == field
      assert result.key == key
      assert result.options.label == "Category"
      assert result.options.placeholder == "Select category"
    end

    test "creates a Select struct with default values" do
      result = Select.new({:categories, :id}, "category-select", %{})

      assert %Select{} = result
      assert result.field == {:categories, :id}
      assert result.key == "category-select"
      assert result.options.label == "Select"
      assert result.options.placeholder == "Search..."
      assert result.options.mode == :tags
      assert result.options.selected == []
    end

    test "handles tuple field for associations" do
      result = Select.new({:categories, :name}, "category-name", %{})

      assert %Select{} = result
      assert result.field == {:categories, :name}
    end
  end

  describe "Select.apply/2" do
    test "applies filter with single table field" do
      filter = Select.new(:id, "category", %{selected: [1]})

      result = Select.apply(true, filter)

      assert is_struct(result, Ecto.Query.DynamicExpr)
      query = from(p in "products", where: ^result)
      assert inspect(query) =~ "where: ^true and p0.id in ^[1]"
    end

    test "applies filter with associated table field" do
      filter = Select.new({:categories, :id}, "category", %{selected: [1, 2]})

      result = Select.apply(true, filter)

      assert is_struct(result, Ecto.Query.DynamicExpr)

      query =
        from(p in Product,
          join: c in Category,
          as: :categories,
          on: c.id == p.category_id,
          where: ^result
        )

      assert inspect(query) =~ "where: ^true and c1.id in ^[1, 2]"
    end

    test "combines with existing conditions" do
      filter = Select.new({:categories, :id}, "category", %{selected: [1]})
      initial_condition = dynamic([p], p.price > 100)

      result = Select.apply(initial_condition, filter)

      query =
        from(p in Product,
          join: c in Category,
          as: :categories,
          on: c.id == p.category_id,
          where: ^result
        )

      assert inspect(query) =~ "where: p0.price > 100 and c1.id in ^[1]"
    end
  end

  describe "Select.render/1" do
    test "renders select component with correct attributes" do
      filter =
        Select.new({:categories, :id}, "category", %{
          label: "Category",
          placeholder: "Choose category",
          css_classes: "custom-wrapper",
          label_classes: "custom-label"
        })

      html =
        render_component(&Select.render/1, %{
          key: "category",
          filter: filter,
          filters: %{}
        })

      assert html =~ "Category"
      assert html =~ "Choose category"
      assert html =~ "custom-wrapper"
      assert html =~ "custom-label"
    end

    # The below test does not work because there is no way to set the value of the live_select from the incoming params in the url.
    # Need to upgrade it.

    # test "renders with selected values" do
    #   filter = Select.new(:category_id, "category", %{
    #     selected: [1, 2],
    #     label: "Category"
    #   })

    #   html = render_component(&Select.render/1, %{
    #     key: "category",
    #     filter: filter,
    #     filters: %{"category" => filter}
    #   })

    #   assert html =~ "selected"
    #   assert html =~ "Category"
    # end
  end

  describe "Select filter integration" do
    setup do
      # Create categories
      {:ok, category1} =
        %Category{name: "Electronics", description: "Electronic items"} |> Repo.insert()

      {:ok, category2} = %Category{name: "Books", description: "Book items"} |> Repo.insert()

      # Create suppliers
      {:ok, supplier1} =
        %Supplier{name: "Supplier A", contact_info: "supplier_a@example.com"} |> Repo.insert()

      {:ok, supplier2} =
        %Supplier{name: "Supplier B", contact_info: "supplier_b@example.com"} |> Repo.insert()

      # Create products
      {:ok, product1} =
        %Product{
          name: "Laptop",
          description: "High-end laptop",
          price: 1000,
          category_id: category1.id
        }
        |> Repo.insert()

      {:ok, product2} =
        %Product{
          name: "Book",
          description: "Programming book",
          price: 50,
          category_id: category2.id
        }
        |> Repo.insert()

      # Set up many-to-many relationships
      timestamp = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

      Repo.insert_all("products_suppliers", [
        %{
          product_id: product1.id,
          supplier_id: supplier1.id,
          inserted_at: timestamp,
          updated_at: timestamp
        },
        %{
          product_id: product2.id,
          supplier_id: supplier2.id,
          inserted_at: timestamp,
          updated_at: timestamp
        }
      ])

      %{
        categories: [category1, category2],
        suppliers: [supplier1, supplier2],
        products: [product1, product2]
      }
    end

    test "filters by product id", %{products: [product1, product2]} do
      filter = Select.new(:id, "category", %{selected: [product1.id]})

      query =
        Product
        |> where(^Select.apply(true, filter))
        |> Repo.all()

      result_ids = Enum.map(query, & &1.id)
      assert length(query) == 1
      assert product1.id in result_ids
      refute product2.id in result_ids
    end

    test "filters by supplier through association", %{
      suppliers: [supplier1, _],
      products: [product1, _]
    } do
      filter = Select.new({:suppliers, :id}, "supplier", %{selected: [supplier1.id]})

      query =
        Product
        |> join(:inner, [p], s in assoc(p, :suppliers), as: :suppliers)
        |> where(^Select.apply(true, filter))
        |> Repo.all()

      result_ids = Enum.map(query, & &1.id)
      assert length(query) == 1
      assert product1.id in result_ids
    end

    test "combines multiple select filters", %{
      categories: [category1, _],
      suppliers: [supplier1, _],
      products: [product1, _]
    } do
      category_filter = Select.new({:categories, :id}, "category", %{selected: [category1.id]})
      supplier_filter = Select.new({:suppliers, :id}, "supplier", %{selected: [supplier1.id]})

      query =
        Product
        |> join(:inner, [p], s in assoc(p, :suppliers), as: :suppliers)
        |> join(:inner, [p, s], c in Category, on: p.category_id == c.id, as: :categories)
        |> where(^Select.apply(true, category_filter))
        |> where(^Select.apply(true, supplier_filter))
        |> Repo.all()

      result_ids = Enum.map(query, & &1.id)
      assert length(query) == 1
      assert product1.id in result_ids
    end
  end

  describe "Select filter error handling" do
    test "handles empty selected values" do
      filter = Select.new(:category_id, "category", %{selected: []})
      result = Select.apply(true, filter)

      assert is_struct(result, Ecto.Query.DynamicExpr)
    end

    test "handles invalid field references gracefully" do
      filter = Select.new(:nonexistent_field, "invalid", %{selected: [1]})
      result = Select.apply(true, filter)

      assert is_struct(result, Ecto.Query.DynamicExpr)
    end
  end

  describe "Select filter with complex associations" do
    test "works with multiple selected values" do
      filter = Select.new(:id, "multi", %{selected: [1, 2, 3]})
      result = Select.apply(true, filter)

      query = from(p in "products", where: ^result)
      assert inspect(query) =~ "where: ^true and p0.id in ^[1, 2, 3]"
    end
  end
end
