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
      assert {:ok, %{worker: LiveTable.Workers.CsvExportWorker}} = Export.fetch_format("csv")
      assert {:ok, %{worker: LiveTable.Workers.PdfExportWorker}} = Export.fetch_format("pdf")
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
