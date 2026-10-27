defmodule LiveTable.ComponentsTest do
  use LiveTable.ConnCase, async: false

  import LiveTable.Fixtures

  alias LiveTable.Components

  defp use_components(module) do
    previous = Application.fetch_env(:live_table, :components)
    Application.put_env(:live_table, :components, module)

    on_exit(fn ->
      case previous do
        {:ok, value} -> Application.put_env(:live_table, :components, value)
        :error -> Application.delete_env(:live_table, :components)
      end
    end)
  end

  describe "resolve/2" do
    test "uses Sutra UI when nothing is configured and Sutra UI is installed" do
      assert Components.resolve(nil, true) == LiveTable.Components.Sutra
    end

    test "uses the configured module whether or not Sutra UI is installed" do
      assert Components.resolve(LiveTable.TestComponents, true) == LiveTable.TestComponents
      assert Components.resolve(LiveTable.TestComponents, false) == LiveTable.TestComponents
    end

    test "explains the fix when there is neither Sutra UI nor a configured module" do
      error = assert_raise ArgumentError, fn -> Components.resolve(nil, false) end

      assert error.message =~ "LiveTable needs :sutra_ui or a components module"
      assert error.message =~ "config :live_table, components:"
    end
  end

  describe "Sutra UI boundary" do
    test "only LiveTable.Components.Sutra uses Sutra UI" do
      offenders =
        Path.wildcard("lib/**/*.ex")
        |> List.delete("lib/live_table/components/sutra.ex")
        |> Enum.filter(fn path ->
          # The LiveSelect helpers send updates to SutraUI.LiveSelect behind Components.sutra?().
          path
          |> File.read!()
          |> String.replace("send_update(SutraUI.LiveSelect,", "")
          |> String.match?(
            ~r/(import|alias|use|require)\s+SutraUI|[<{(]SutraUI\.|SutraUI(\.\w+)+\(/
          )
        end)

      assert offenders == []
    end
  end

  describe "with a custom components module" do
    setup do
      use_components(LiveTable.TestComponents)

      product_fixture(%{name: "Alpha", price: Decimal.new("100.00"), stock_quantity: 10})
      product_fixture(%{name: "Beta", price: Decimal.new("200.00"), stock_quantity: 0})
      product_fixture(%{name: "Gamma", price: Decimal.new("300.00"), stock_quantity: 5})
      :ok
    end

    test "renders the table without Sutra UI markup", %{conn: conn} do
      {:ok, view, html} = live(conn, "/products")

      assert html =~ "Alpha"
      assert has_element?(view, "input[type=search][name=search]")
      assert has_element?(view, "select#per-page-select[name=per_page]")
      assert has_element?(view, "input[type=checkbox][name='filters[in_stock]']")
      assert has_element?(view, "input[type=number][name='filters[price_range][min]']")
      assert has_element?(view, "select[name='filters[category][id][]'][multiple]")
      refute html =~ "SutraUI"
    end

    test "filters through the plain form fields", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/products")

      view
      |> form("#live-table-controls-form", %{
        "per_page" => "5",
        "filters" => %{
          "in_stock" => "true",
          "price_range" => %{"min" => "150", "max" => "500"}
        }
      })
      |> render_change()

      html = render(view)
      assert html =~ "Gamma"
      refute html =~ "Alpha"
      refute html =~ "Beta"
    end

    test "an emptied range input falls back to the range defaults", %{conn: conn} do
      {:ok, _view, html} =
        live(conn, "/products?per_page=5&filters[price_range][min]=&filters[price_range][max]=")

      assert html =~ "Alpha"
      assert html =~ "Gamma"
    end

    test "uses the custom empty state", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/products?search=nothing-matches")

      assert html =~ "Nothing to show."
    end
  end

  describe "overriding part of the Sutra UI components" do
    setup do
      use_components(LiveTable.TestPartialComponents)
    end

    test "uses the override and keeps Sutra UI for the rest", %{conn: conn} do
      {:ok, view, html} = live(conn, "/products")

      assert has_element?(view, "select#custom-per-page")
      refute has_element?(view, "#per-page-select")
      assert html =~ "input-group"
    end
  end

  describe "a components module without a filter's component" do
    setup do
      use_components(LiveTable.TestIncompleteComponents)
    end

    test "names the missing function", %{conn: conn} do
      error =
        assert_raise ArgumentError, fn -> live(conn, "/products") end

      assert error.message =~
               "LiveTable.TestIncompleteComponents does not implement range_filter/1"
    end
  end
end
