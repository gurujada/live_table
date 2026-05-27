defmodule LiveTable.SortingTest do
  use LiveTable.DataCase
  alias LiveTable.{Sorting, Catalog.Product}

  describe "maybe_sort/4" do
    test "returns original query when sorting is disabled" do
      query = from(p in "posts")

      sort_params = [id: :asc]
      fields = %{id: %{sortable: true}}

      result = Sorting.maybe_sort(query, fields, sort_params, false)
      assert result == query
    end

    test "applies sorting when enabled" do
      query = from(p in "posts")

      sort_params = [%{"sort_by" => "id", "sort_order" => "asc"}]

      result = Sorting.maybe_sort(query, %{}, sort_params, true)
      assert %Ecto.Query{} = result
      assert result != query
    end
  end

  setup do
    # Pre-create atoms that will be used in tests
    :body |> to_string() |> String.to_existing_atom()
    :likes_count |> to_string() |> String.to_existing_atom()
    :repost_count |> to_string() |> String.to_existing_atom()
    :photo_locations |> to_string() |> String.to_existing_atom()

    :ok
  end

  describe "sort/4 (Single Table)" do
    test "handles ascending sort" do
      query = from(p in "posts")
      sort_params = [body: :asc]
      fields = %{body: %{sortable: true}}
      result = Sorting.maybe_sort(query, fields, sort_params, true)

      assert %Ecto.Query{} = result
      assert inspect(result) =~ "order_by: [asc: p0.body]"
    end

    test "handles descending sort" do
      query = from(p in "posts")
      sort_params = [likes_count: :desc]
      fields = %{likes_count: %{sortable: true}}
      result = Sorting.maybe_sort(query, fields, sort_params, true)

      assert %Ecto.Query{} = result
      assert inspect(result) =~ "order_by: [desc: p0.likes_count]"
    end

    test "returns unsorted query for invalid params" do
      query = from(p in "posts")
      sort_params = [invalid: :params]
      fields = %{body: %{sortable: true}}

      result = Sorting.maybe_sort(query, fields, sort_params, true)

      assert %Ecto.Query{} = result
      assert inspect(result) =~ "order_by: []"
    end

    test "handles multiple sort parameters" do
      query = from(p in "posts")

      sort_params = [likes_count: :desc, repost_count: :asc]

      fields = %{likes_count: %{sortable: true}, repost_count: %{sortable: true}}

      result = Sorting.maybe_sort(query, fields, sort_params, true)

      assert %Ecto.Query{} = result
      assert inspect(result) =~ "order_by: [desc: p0.likes_count, asc: p0.repost_count]"
    end

    test "Ignores sort for sortable: false columns" do
      query =
        from p0 in Product,
          as: :resource,
          left_join: s1 in assoc(p0, :suppliers),
          as: :suppliers,
          left_join: c2 in assoc(p0, :category),
          as: :category,
          left_join: i3 in assoc(p0, :image),
          as: :image,
          select: %{
            supplier_name: s1.name,
            price: p0.price
          }

      sort_params =
        [supplier_name: :asc, price: :desc]

      fields = [
        price: %{
          label: "Price",
          sortable: true
        },
        supplier_name: %{
          label: "Supplier Name",
          assoc: {:suppliers, :name},
          sortable: false
        }
      ]

      result = Sorting.maybe_sort(query, fields, sort_params, true)

      assert %Ecto.Query{} = result
      assert inspect(result) =~ "order_by: [desc: p0.price]"
    end

    test "Sorts by computed fields" do
      query = from(p in "products", as: :resource)

      sort_params = [amount: :desc]

      fields = [
        amount: %{
          label: "Amount",
          sortable: true,
          computed: dynamic([resource: r], fragment("? * 0.58", r.price))
        }
      ]

      result = Sorting.maybe_sort(query, fields, sort_params, true)

      assert %Ecto.Query{} = result
      assert inspect(result) =~ "order_by: [desc: fragment(\"? * 0.58\", p0.price)]"
    end
  end

  describe "sort/4 (Joined Table)" do
    test "sorts by column in base schema" do
      query = from(p in "products")
      sort_params = [price: :asc]
      fields = %{price: %{sortable: true}}
      result = Sorting.maybe_sort(query, fields, sort_params, true)

      assert %Ecto.Query{} = result
      assert inspect(result) =~ "order_by: [asc: p0.price]"
    end

    test "sorts by column in joined query" do
      query =
        from p in "products",
          join: ps in "product_suppliers",
          on: ps.product_id == p.id,
          join: s in "suppliers",
          on: ps.supplier_id == s.id,
          order_by: [asc: s.name],
          select: %{supplier_name: s.name}

      sort_params = [supplier_name: :asc]
      fields = %{supplier_name: %{sortable: true}}

      result = Sorting.maybe_sort(query, fields, sort_params, true)

      assert %Ecto.Query{} = result
      assert inspect(result) =~ "order_by: [asc: s2.name]"
    end

    test "sort by multiple columns in joined table" do
      query =
        from p0 in Product,
          as: :resource,
          left_join: s1 in assoc(p0, :suppliers),
          as: :suppliers,
          left_join: c2 in assoc(p0, :category),
          as: :category,
          left_join: i3 in assoc(p0, :image),
          as: :image,
          select: %{
            supplier_name: s1.name,
            price: p0.price
          }

      sort_params =
        [supplier_name: :asc, price: :desc]

      fields = [
        price: %{
          label: "Price",
          sortable: true
        },
        supplier_name: %{
          label: "Supplier Name",
          assoc: {:suppliers, :name},
          sortable: true
        }
      ]

      result = Sorting.maybe_sort(query, fields, sort_params, true)

      assert %Ecto.Query{} = result
      assert inspect(result) =~ "order_by: [asc: s1.name, desc: p0.price]"
    end

    test "sort order preserved in sort by multiple columns" do
      query =
        from p0 in Product,
          as: :resource,
          left_join: s1 in assoc(p0, :suppliers),
          as: :suppliers,
          left_join: c2 in assoc(p0, :category),
          as: :category,
          left_join: i3 in assoc(p0, :image),
          as: :image

      sort_params =
        [supplier_name: :asc, category_name: :asc, price: :desc, name: :asc]

      fields = [
        price: %{
          label: "Price",
          sortable: true
        },
        name: %{
          label: "Name",
          sortable: true
        },
        supplier_name: %{
          label: "Supplier Name",
          assoc: {:suppliers, :name},
          sortable: true
        },
        category_name: %{
          label: "Category Name",
          assoc: {:category, :name},
          sortable: true
        }
      ]

      result = Sorting.maybe_sort(query, fields, sort_params, true)

      assert %Ecto.Query{} = result

      assert inspect(result) =~
               "order_by: [asc: s1.name, asc: c2.name, desc: p0.price, asc: p0.name]"
    end

    test "sorts by computed fields with joins" do
      query =
        from p0 in Product,
          as: :resource,
          left_join: s1 in assoc(p0, :suppliers),
          as: :suppliers,
          left_join: c2 in assoc(p0, :category),
          as: :category

      sort_params = [
        total_value: :desc,
        supplier_name: :asc
      ]

      fields = [
        supplier_name: %{
          label: "Supplier Name",
          assoc: {:suppliers, :name},
          sortable: true
        },
        total_value: %{
          label: "Total Value",
          sortable: true,
          computed:
            dynamic(
              [resource: r, suppliers: s],
              fragment("? * ? * 0.58", r.price, r.stock_quantity)
            )
        }
      ]

      result = Sorting.maybe_sort(query, fields, sort_params, true)

      assert %Ecto.Query{} = result

      assert inspect(result) =~
               "order_by: [desc: fragment(\"? * ? * 0.58\", p0.price, p0.stock_quantity), asc: s1.name]"
    end
  end
end
