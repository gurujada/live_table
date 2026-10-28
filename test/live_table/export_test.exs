defmodule LiveTable.ExportTest do
  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest

  alias LiveTable.Export

  describe "format registry" do
    test "only pdf carries the row limit" do
      {:ok, pdf} = Export.fetch_format("pdf")
      {:ok, csv} = Export.fetch_format("csv")

      assert pdf.max_records == 10_000
      refute Map.has_key?(csv, :max_records)
    end
  end

  describe "fetch_format/1" do
    test "resolves a format sent as an event parameter" do
      assert {:ok, %{content_type: "text/csv"}} = Export.fetch_format("csv")
      assert {:ok, %{content_type: "application/pdf"}} = Export.fetch_format("pdf")
    end

    test "refuses unknown formats instead of defaulting to one" do
      assert :error = Export.fetch_format("json")
      assert :error = Export.fetch_format("xlsx")
      assert :error = Export.fetch_format("")
    end

    test "never creates an atom from the parameter" do
      assert :error = Export.fetch_format("live_table_probe_never_an_atom")

      # If fetch_format/1 had used String.to_atom/1 this would no longer raise.
      assert_raise ArgumentError, fn ->
        String.to_existing_atom("live_table_probe_never_an_atom")
      end
    end
  end

  describe "download_path/4 and verify/2" do
    import Ecto.Query

    @endpoint LiveTable.TestEndpoint

    test "round-trips the query and columns through the link" do
      query = from(p in LiveTable.Catalog.Product, where: p.id in ^[1, 2], select: %{id: p.id})
      "/live_table/exports/" <> token = Export.download_path(@endpoint, "csv", query, id: "ID")

      assert {:ok, %{format: "csv", query: ^query, columns: [id: "ID"]}} =
               Export.verify(@endpoint, token)
    end

    test "the link doesn't reveal the query" do
      query = from(p in LiveTable.Catalog.Product, where: p.name == ^"secret-value")
      path = Export.download_path(@endpoint, "csv", query, [])

      refute path =~ "Product"
      refute path =~ "secret"
    end

    test "refuses a tampered token" do
      token = Export.download_path(@endpoint, "csv", from(p in "products"), []) |> Path.basename()

      assert :error = Export.verify(@endpoint, token <> "x")
      assert :error = Export.verify(@endpoint, "not-a-token")
    end
  end

  describe "validate_formats!/1" do
    test "accepts supported formats" do
      assert Export.validate_formats!([:csv]) == [:csv]
      assert Export.validate_formats!([:csv, :pdf]) == [:csv, :pdf]
      assert Export.validate_formats!([]) == []
    end

    test "rejects a format LiveTable cannot produce" do
      message =
        assert_raise ArgumentError, fn -> Export.validate_formats!([:csv, :json]) end

      assert message.message =~ "unsupported export format(s) [:json]"
      assert message.message =~ "Supported formats: csv, pdf"
    end
  end

  describe "the export dropdown" do
    defmodule ExportProbe do
      use LiveTable.TableComponent,
        table_options: %{
          mode: :table,
          use_streams: false,
          exports: %{enabled: true, formats: [:csv, :pdf, :json]}
        }
    end

    defmodule SupportedProbe do
      use LiveTable.TableComponent,
        table_options: %{
          mode: :table,
          use_streams: false,
          exports: %{enabled: true, formats: [:csv, :pdf]}
        }
    end

    test "each configured format dispatches by value, not by a distinct event name" do
      html = render_table(SupportedProbe)

      assert html =~ "Export as CSV"
      assert html =~ "Export as PDF"
      assert html =~ ~s(phx-click="export")
      assert html =~ ~s(phx-value-format="csv")
      assert html =~ ~s(phx-value-format="pdf")

      # No per-format event names to interpolate or keep in sync.
      refute html =~ "export-csv"
      refute html =~ "export-pdf"
    end

    test "an unsupported format is refused loudly instead of exporting the wrong thing" do
      # Regression: this used to render "Export as JSON" wired to export-pdf.
      message = assert_raise ArgumentError, fn -> render_table(ExportProbe) end

      assert message.message =~ "unsupported export format(s) [:json]"
    end

    defp render_table(module) do
      render_component(&module.live_table/1, %{
        fields: [{:name, %{label: "Name", sortable: false}}],
        filters: [],
        options: %{
          "filters" => %{"search" => ""},
          "sort" => %{"sort_params" => []},
          "pagination" => %{"paginate?" => false}
        },
        streams: []
      })
    end
  end
end
