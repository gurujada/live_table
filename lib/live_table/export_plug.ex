defmodule LiveTable.ExportPlug do
  @moduledoc """
  Serves the table's CSV and PDF exports.

  Forward to it in your router, outside any `scope` that pipes through `:browser`:

      forward "/live_table/exports", LiveTable.ExportPlug

  The export button sends the browser a link with the export's query encrypted in it,
  valid for 60 seconds. This plug decrypts it, runs the query and streams the file back.
  Nothing is stored, so it works on any node.
  """

  @behaviour Plug

  import Plug.Conn
  require Logger

  alias LiveTable.{CsvGenerator, Export, PdfGenerator}

  @impl true
  def init(opts), do: opts

  @impl true
  def call(%Plug.Conn{method: "GET", path_info: [token]} = conn, _opts) do
    case Export.verify(conn, token) do
      {:ok, export} -> conn |> send_export(export) |> halt()
      :error -> conn |> send_resp(404, "Not found") |> halt()
    end
  end

  def call(conn, _opts), do: conn |> send_resp(404, "Not found") |> halt()

  defp send_export(conn, %{format: "csv", query: query, columns: columns}) do
    repo = Application.fetch_env!(:live_table, :repo)
    conn = conn |> put_download_headers("csv") |> send_chunked(200)

    {:ok, conn} =
      repo.transaction(
        fn ->
          query
          |> CsvGenerator.stream(columns)
          |> Enum.reduce_while(conn, fn data, conn ->
            case chunk(conn, data) do
              {:ok, conn} -> {:cont, conn}
              {:error, _closed} -> {:halt, conn}
            end
          end)
        end,
        timeout: :infinity
      )

    conn
  end

  defp send_export(conn, %{format: "pdf", query: query, columns: columns}) do
    case PdfGenerator.render(query, columns) do
      {:ok, pdf} ->
        conn |> put_download_headers("pdf") |> send_resp(200, pdf)

      {:error, reason} ->
        Logger.error("LiveTable PDF export failed: #{reason}")
        send_resp(conn, 500, "Export failed")
    end
  end

  defp put_download_headers(conn, format) do
    {:ok, %{content_type: content_type}} = Export.fetch_format(format)
    filename = "export-#{LiveTable.ExportHelpers.generate_export_timestamp()}.#{format}"

    conn
    |> put_resp_content_type(content_type)
    |> put_resp_header("content-disposition", ~s(attachment; filename="#{filename}"))
    |> put_resp_header("cache-control", "no-store")
  end
end
