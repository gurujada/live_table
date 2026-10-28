defmodule LiveTable.ExportPlugTest do
  use LiveTable.ConnCase

  import LiveTable.Fixtures
  alias NimbleCSV.RFC4180, as: CSV

  setup do
    product_fixture(%{name: "Alpha", price: Decimal.new("100.00"), stock_quantity: 10})
    product_fixture(%{name: "Beta", price: Decimal.new("200.00"), stock_quantity: 0})
    :ok
  end

  defp export_path(conn, url, format) do
    {:ok, view, _html} = live(conn, url)
    render_click(view, "export", %{"format" => format})
    assert_push_event(view, "download", %{path: path})
    path
  end

  test "the export button's link downloads the table as CSV, with its filters", %{conn: conn} do
    path = export_path(conn, "/products?search=Alpha", "csv")
    conn = get(build_conn(), path)

    assert response_content_type(conn, :csv) =~ "text/csv"

    assert get_resp_header(conn, "content-disposition") |> hd() =~
             ~r/attachment; filename="export-.*\.csv"/

    [header | rows] = conn |> response(200) |> CSV.parse_string(skip_headers: false)
    assert header == ["ID", "Name", "Description", "Price", "Stock"]
    assert [[_id, "Alpha", _description, "100.00", "10"]] = rows
  end

  test "the export button's link downloads a PDF", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/products")
    render_click(view, "export", %{"format" => "pdf"})
    assert_push_event(view, "download", %{path: path})

    # The test LiveView renders no flash, so read it from the LiveView's state.
    assert :sys.get_state(view.pid).socket.assigns.flash["info"] =~ "Preparing your PDF"
    conn = get(build_conn(), path)

    assert "%PDF" <> _ = response(conn, 200)
    assert response_content_type(conn, :pdf) =~ "application/pdf"
  end

  test "a tampered or missing token gets a 404", %{conn: conn} do
    path = export_path(conn, "/products", "csv")

    assert build_conn() |> get(path <> "x") |> response(404)
    assert build_conn() |> get("/live_table/exports/not-a-token") |> response(404)
    assert build_conn() |> get("/live_table/exports") |> response(404)
  end

  test "the export event is ignored for a format the table doesn't offer", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/products_no_streams")
    render_click(view, "export", %{"format" => "csv"})

    refute_push_event(view, "download", %{})
  end
end
