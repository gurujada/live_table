defmodule LiveTable.LiveResourceLiveViewTest do
  use LiveTable.ConnCase

  import LiveTable.Fixtures

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

    test "rows are identified by their primary key", %{conn: conn, products: products} do
      {:ok, view, _html} = live(conn, "/products")

      assert view |> element("tr#resource-#{products.alpha.id}", "Alpha") |> has_element?()
    end

    test "schema data source renders selected fields without schema metadata columns", %{
      conn: conn
    } do
      {:ok, view, html} = live(conn, "/products")

      assert html =~ "Alpha"
      assert html =~ "100.00"
      assert view |> element("th", "Name") |> has_element?()
      refute html =~ "__meta__"
      refute html =~ "category_id"
      refute html =~ "inserted_at"
      refute html =~ "updated_at"
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
  end

  describe "hand-edited URLs" do
    test "render the table instead of crashing", %{conn: conn} do
      product_fixture(%{name: "Alpha"})

      for query <- [
            "sort_params[name]=sideways",
            "sort_params[nonexistent]=asc",
            "sort_params=abc",
            "per_page=abc",
            "page[]=2",
            "filters[not_a_filter]=true",
            "filters=abc",
            "filters[price_range]=true",
            "filters[price_range][min][x]=1&filters[price_range][max]=500",
            "filters[category][id]=5",
            "filters[in_stock][x]=true"
          ] do
        {:ok, _view, html} = live(conn, "/products?" <> query)
        assert html =~ "Alpha"
      end
    end
  end

  describe "live rows" do
    setup do
      alpha = product_fixture(%{name: "Alpha", price: Decimal.new("100.00")})
      beta = product_fixture(%{name: "Beta", price: Decimal.new("200.00")})
      gamma = product_fixture(%{name: "Gamma", price: Decimal.new("300.00")})

      %{alpha: alpha, beta: beta, gamma: gamma}
    end

    defp broadcast(ids), do: LiveTable.broadcast(LiveTable.TestPubSub, "products", ids)

    test "a new row lands in its sorted place", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/products")

      new = product_fixture(%{name: "Aardvark"})
      broadcast([new.id])

      html = render(view)
      assert html =~ "Aardvark"
      assert html =~ "Alpha"
      refute html =~ "Beta"
    end

    test "a row that now sorts onto another page leaves this one", %{conn: conn, alpha: alpha} do
      {:ok, view, _html} = live(conn, "/products")

      LiveTable.Repo.update!(Ecto.Changeset.change(alpha, name: "Zulu"))
      broadcast([alpha.id])

      html = render(view)
      refute html =~ "Zulu"
      refute html =~ "Alpha"
      assert html =~ "Beta"
      assert html =~ "Gamma"
    end

    test "a deleted row disappears", %{conn: conn, beta: beta} do
      {:ok, view, _html} = live(conn, "/products")

      LiveTable.Repo.delete!(beta)
      broadcast([beta.id])

      html = render(view)
      refute html =~ "Beta"
      assert html =~ "Gamma"
    end

    test "a row outside the filters doesn't appear", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/products?search=Gamma")

      new = product_fixture(%{name: "Aardvark"})
      broadcast([new.id])

      refute render(view) =~ "Aardvark"
    end

    test "an updated row on screen changes in place", %{conn: conn, alpha: alpha} do
      {:ok, view, _html} = live(conn, "/products")

      LiveTable.Repo.update!(Ecto.Changeset.change(alpha, price: Decimal.new("150.00")))
      broadcast([alpha.id])

      assert view |> element("#resource-#{alpha.id}", "150.00") |> has_element?()
    end

    test "infinite scroll keeps every loaded page", %{conn: conn, gamma: gamma} do
      {:ok, view, _html} = live(conn, "/products_infinite")
      view |> element("#infinite-scroll-container") |> render_hook("load_more", %{})

      LiveTable.Repo.update!(Ecto.Changeset.change(gamma, price: Decimal.new("350.00")))
      broadcast([gamma.id])

      html = render(view)
      assert html =~ "Alpha"
      assert html =~ "Beta"
      assert html =~ "350.00"
    end

    test "other messages still reach the LiveView", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/products")

      send(view.pid, :ping)
      render(view)

      assert :sys.get_state(view.pid).socket.assigns.pinged
    end
  end
end
