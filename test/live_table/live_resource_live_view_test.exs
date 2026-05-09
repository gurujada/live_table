defmodule LiveTable.LiveResourceLiveViewTest do
  use LiveTable.ConnCase

  import LiveTable.Fixtures

  alias LiveTable.Catalog.Product

  describe "LiveResource LiveView lifecycle" do
    setup do
      alpha =
        product_fixture(%{
          name: "Alpha",
          description: "First product",
          price: Decimal.new("100.00"),
          stock_quantity: 10
        })

      beta =
        product_fixture(%{
          name: "Beta",
          description: "Second product",
          price: Decimal.new("200.00"),
          stock_quantity: 0
        })

      gamma =
        product_fixture(%{
          name: "Gamma",
          description: "Third product",
          price: Decimal.new("300.00"),
          stock_quantity: 5
        })

      %{products: %{alpha: alpha, beta: beta, gamma: gamma}}
    end

    test "initial params fetch resources with default sorting, pagination, and streams", %{
      conn: conn
    } do
      {:ok, view, html} = live(conn, "/products")

      assert html =~ "Alpha"
      assert html =~ "Beta"
      refute html =~ "Gamma"

      assert view |> element("tbody#resources-stream[phx-update='stream']") |> has_element?()
      assert render(view) =~ "Page <span class=\"font-medium text-foreground\">1</span>"
    end

    test "search params filter rows and preserve URL-backed state", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/products?search=Gamma")

      assert html =~ "Gamma"
      refute html =~ "Alpha"
      refute html =~ "Beta"
    end

    test "sort event pushes URL state and re-renders sorted rows", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/products")

      view
      |> element("#name")
      |> render_click()

      assert_patch(view, "/products?page=1&per_page=2&sort_params[name]=desc")

      html = render(view)
      assert html =~ "Gamma"
      assert html =~ "Beta"
      refute html =~ "Alpha"
    end

    test "pagination event moves between pages through handle_params", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/products")

      view
      |> element("button", "Next")
      |> render_click()

      assert_patch(view, "/products?page=2&per_page=2&sort_params[name]=asc")

      html = render(view)
      assert html =~ "Gamma"
      refute html =~ "Alpha"
      refute html =~ "Beta"
    end

    test "boolean filter URL params are parsed and applied", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/products?filters[in_stock]=in-stock")

      assert html =~ "Alpha"
      assert html =~ "Gamma"
      refute html =~ "Beta"
    end

    test "range filter URL params are parsed and applied", %{conn: conn} do
      {:ok, _view, html} =
        live(conn, "/products?filters[price_range][min]=150&filters[price_range][max]=250")

      assert html =~ "Beta"
      refute html =~ "Alpha"
      refute html =~ "Gamma"
    end

    test "transformer URL params are parsed and applied", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/products?filters[min_stock][quantity]=6")

      assert html =~ "Alpha"
      refute html =~ "Beta"
      refute html =~ "Gamma"
    end

    test "clear filters event resets select state and patches to unfiltered URL", %{conn: conn} do
      {:ok, view, html} = live(conn, "/products?search=Gamma")
      assert html =~ "Gamma"

      view
      |> element("button", "Clear Filters")
      |> render_click()

      assert_patch(view, "/products?page=1&per_page=2&sort_params[name]=asc")

      html = render(view)
      assert html =~ "Alpha"
      assert html =~ "Beta"
    end

    test "non-streaming mode assigns resources and renders rows", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/products_no_streams")

      assert html =~ "Alpha"
      assert html =~ "Beta"
      refute html =~ "Gamma"
    end

    test "infinite scroll load_more appends the next page", %{conn: conn} do
      {:ok, view, html} = live(conn, "/products_infinite")

      assert html =~ "Alpha"
      assert html =~ "Beta"
      refute html =~ "Gamma"

      html =
        view
        |> element("#infinite-scroll-container")
        |> render_hook("load_more", %{})

      assert html =~ "Gamma"
    end
  end

  describe "production LiveResource query pipeline" do
    test "select filters on associations join before filtering", %{conn: conn} do
      category = category_fixture(%{name: "Visible Category"})
      product_fixture(%{name: "Matched", category_id: category.id})
      product_fixture(%{name: "Unmatched"})

      {:ok, _view, html} = live(conn, "/products?filters[category][id][]=#{category.id}")

      assert html =~ "Matched"
      refute html =~ "Unmatched"
    end

    test "schema data source returns selected maps, not raw schemas" do
      product_fixture(%{name: "Selected"})

      options = %{
        "sort" => %{"sortable?" => true, "sort_params" => [name: :asc]},
        "pagination" => %{"paginate?" => false, "page" => "1", "per_page" => "10"},
        "filters" => %{}
      }

      [result] =
        LiveTable.TestProductLive.list_resources(
          LiveTable.TestProductLive.fields(),
          options,
          Product
        )
        |> Repo.all()

      assert %{name: "Selected", price: %Decimal{}} = result
      refute Map.has_key?(result, :__meta__)
    end
  end
end
