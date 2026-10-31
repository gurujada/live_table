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
      |> element("#sort-name")
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

    test "only the changed rows are sent again when the page keeps its rows", %{
      conn: conn,
      alpha: alpha,
      beta: beta
    } do
      {:ok, view, _html} = live(conn, "/products")

      # Alpha changes without a broadcast; if the whole page were resent, it would show.
      LiveTable.Repo.update!(Ecto.Changeset.change(alpha, price: Decimal.new("111.00")))
      LiveTable.Repo.update!(Ecto.Changeset.change(beta, price: Decimal.new("222.00")))
      broadcast([beta.id])

      assert view |> element("#resource-#{beta.id}", "222.00") |> has_element?()
      assert view |> element("#resource-#{alpha.id}", "100.00") |> has_element?()
    end

    # The ids of the rows on screen, in order.
    defp rows_on_screen(view) do
      ~r/id="resource-(\d+)"/
      |> Regex.scan(render(view), capture: :all_but_first)
      |> Enum.map(fn [id] -> String.to_integer(id) end)
    end

    # Each test below also changes Alpha without a broadcast: it shows only if the whole page is
    # sent again.
    defp change_quietly(product),
      do: LiveTable.Repo.update!(Ecto.Changeset.change(product, price: Decimal.new("111.00")))

    test "a new row is sent alone, and the row it pushes off is removed", %{
      conn: conn,
      alpha: alpha
    } do
      {:ok, view, _html} = live(conn, "/products")

      change_quietly(alpha)
      new = product_fixture(%{name: "Aardvark"})
      broadcast([new.id])

      assert rows_on_screen(view) == [new.id, alpha.id]
      assert view |> element("#resource-#{alpha.id}", "100.00") |> has_element?()
    end

    test "a deleted row is removed alone, and the next row moves up", %{
      conn: conn,
      alpha: alpha,
      beta: beta,
      gamma: gamma
    } do
      {:ok, view, _html} = live(conn, "/products")

      change_quietly(beta)
      LiveTable.Repo.delete!(alpha)
      broadcast([alpha.id])

      assert rows_on_screen(view) == [beta.id, gamma.id]
      assert view |> element("#resource-#{beta.id}", "200.00") |> has_element?()
    end

    test "rows that swap places send the whole page", %{conn: conn, alpha: alpha, beta: beta} do
      {:ok, view, _html} = live(conn, "/products")

      change_quietly(alpha)
      LiveTable.Repo.update!(Ecto.Changeset.change(beta, name: "Aaa"))
      broadcast([beta.id])

      assert rows_on_screen(view) == [beta.id, alpha.id]
      assert view |> element("#resource-#{alpha.id}", "111.00") |> has_element?()
    end

    test "infinite scroll sends only the changed rows too", %{
      conn: conn,
      alpha: alpha,
      gamma: gamma
    } do
      {:ok, view, _html} = live(conn, "/products_infinite")
      view |> element("#infinite-scroll-container") |> render_hook("load_more", %{})

      # Alpha is on the first page, Gamma on the second; only Gamma is broadcast.
      LiveTable.Repo.update!(Ecto.Changeset.change(alpha, price: Decimal.new("111.00")))
      LiveTable.Repo.update!(Ecto.Changeset.change(gamma, price: Decimal.new("333.00")))
      broadcast([gamma.id])

      assert view |> element("#resource-#{gamma.id}", "333.00") |> has_element?()
      assert view |> element("#resource-#{alpha.id}", "100.00") |> has_element?()
    end

    test "infinite scroll sends a new row alone", %{conn: conn, gamma: gamma} do
      {:ok, view, _html} = live(conn, "/products_infinite")
      view |> element("#infinite-scroll-container") |> render_hook("load_more", %{})

      change_quietly(gamma)
      new = product_fixture(%{name: "Aardvark"})
      broadcast([new.id])

      assert hd(rows_on_screen(view)) == new.id
      assert view |> element("#resource-#{gamma.id}", "300.00") |> has_element?()
    end

    test "other messages still reach the LiveView", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/products")

      send(view.pid, :ping)
      render(view)

      assert :sys.get_state(view.pid).socket.assigns.pinged
    end
  end

  describe "bulk actions" do
    setup do
      products =
        for {name, stock} <- [{"Alpha", 10}, {"Beta", 0}, {"Delta", 7}, {"Gamma", 5}],
            into: %{},
            do: {name, product_fixture(%{name: name, stock_quantity: stock})}

      %{products: products}
    end

    defp price(product), do: LiveTable.Repo.reload!(product).price
    defp row_id(product), do: "resource-#{product.id}"

    # The selection lives in the browser; the .LiveTable hook puts it on the action button as
    # phx-value-ids or phx-value-all. These tests click the button with those values.
    defp act(view, values),
      do: view |> element("#bulk-bar button", "Mark down") |> render_click(values)

    test "render a checkbox per row and a hidden bar", %{conn: conn, products: products} do
      {:ok, view, _html} = live(conn, "/products")

      assert view
             |> element("input[data-live-table-select][value='#{row_id(products["Alpha"])}']")
             |> has_element?()

      assert view |> element("input[data-live-table-select-page]") |> has_element?()
      assert view |> element("#bulk-bar[hidden]") |> has_element?()

      assert view
             |> element("#bulk-bar button[data-confirm='Mark down the selected products?']")
             |> has_element?()
    end

    test "run on the chosen rows", %{conn: conn, products: products} do
      {:ok, view, _html} = live(conn, "/products")

      act(view, %{"ids" => "#{row_id(products["Alpha"])},#{row_id(products["Delta"])}"})

      assert price(products["Alpha"]) == Decimal.new("1.00")
      assert price(products["Delta"]) == Decimal.new("1.00")
      assert price(products["Beta"]) == Decimal.new("99.99")
      assert_push_event(view, "live_table:bulk_done", %{})
      assert render(view) =~ "1.00"
    end

    test "run on all rows matching the filters", %{conn: conn, products: products} do
      {:ok, view, _html} = live(conn, "/products?filters[in_stock]=in-stock")

      act(view, %{"all" => "true"})

      for name <- ["Alpha", "Delta", "Gamma"],
          do: assert(price(products[name]) == Decimal.new("1.00"))

      assert price(products["Beta"]) == Decimal.new("99.99")
    end

    test "ignore ids outside the table's query", %{conn: conn, products: products} do
      {:ok, view, _html} = live(conn, "/products?filters[in_stock]=in-stock")

      act(view, %{"ids" => "#{row_id(products["Beta"])},resource-nope"})

      assert price(products["Beta"]) == Decimal.new("99.99")
    end

    test "do nothing without a selection", %{conn: conn, products: products} do
      {:ok, view, _html} = live(conn, "/products")

      act(view, %{"ids" => ""})

      assert price(products["Alpha"]) == Decimal.new("99.99")
      refute_push_event(view, "live_table:bulk_done", %{})
    end

    test "work without streams", %{conn: conn, products: products} do
      {:ok, view, _html} = live(conn, "/products_no_streams")

      assert view
             |> element("input[data-live-table-select][value='#{row_id(products["Alpha"])}']")
             |> has_element?()

      act(view, %{"ids" => row_id(products["Alpha"])})

      assert price(products["Alpha"]) == Decimal.new("1.00")
      assert render(view) =~ "1.00"
    end

    test "cards draw their own checkbox; the bar selects the page", %{
      conn: conn,
      products: products
    } do
      {:ok, view, _html} = live(conn, "/products_infinite")

      assert view
             |> element("input[aria-label='Select Alpha'][value='#{row_id(products["Alpha"])}']")
             |> has_element?()

      assert view |> element("#bulk-bar button[data-live-table-select-page]") |> has_element?()
    end

    test "the table's view key changes with the query, which clears the selection", %{
      conn: conn
    } do
      {:ok, view, html} = live(conn, "/products")
      [before] = Regex.run(~r/data-view="(\d+)"/, html, capture: :all_but_first)

      [later] =
        Regex.run(~r/data-view="(\d+)"/, render_patch(view, "/products?search=a"),
          capture: :all_but_first
        )

      assert before != later
    end
  end
end
