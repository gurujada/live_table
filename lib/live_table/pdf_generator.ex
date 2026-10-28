defmodule LiveTable.PdfGenerator do
  @moduledoc false
  # A module for generating PDF files from Ecto queries using Typst.
  # This module provides functionality to convert Ecto queries into formatted PDF files,
  # with support for custom headers and efficient streaming of large datasets. It uses
  # Typst as an intermediate format for PDF generation.

  import Ecto.Query, only: [limit: 2]

  # Renders the query as a PDF binary. Typst works in a private directory that is
  # always removed, and only sees that directory.
  def render(query, columns) do
    dir =
      Path.join(
        System.tmp_dir!(),
        "live_table-" <> Base.url_encode64(:crypto.strong_rand_bytes(12))
      )

    File.mkdir_p!(dir)

    try do
      typ_path = Path.join(dir, "export.typ")
      pdf_path = Path.join(dir, "export.pdf")
      {keys, labels} = Enum.unzip(columns)

      generate_typst_file(limit(query, 10_000), typ_path, keys, labels)

      case System.cmd("typst", ["compile", "--root", dir, typ_path, pdf_path],
             stderr_to_stdout: true
           ) do
        {_, 0} -> {:ok, File.read!(pdf_path)}
        {error, _} -> {:error, "Failed to compile PDF: #{error}"}
      end
    after
      File.rm_rf(dir)
    end
  end

  defp generate_typst_file(query, path, header_keys, header_labels) do
    typst_template = """
    #set page(
      paper: "a4",
      margin: (x: 0.8cm, y: 0.8cm),
      flipped: true,
    )

    #set text(
      font: "DejaVu Sans",
      size: 8pt,
      weight: "regular"
    )

    #show table.cell: it => {
      set text(size: 8pt)
      set par(leading: 0.5em)
      it
    }

    #table(
      columns: (auto, ) * #{length(header_labels)},
      inset: (x: 8pt, y: 6pt),
      align: (col, row) => {
        if row == 0 { center + horizon }
        else { left + horizon }
      },
      stroke: (x, y) => {
        if y == 0 {
          (bottom: 1.5pt + rgb(45, 45, 45), rest: 0.75pt + rgb(160, 160, 160))
        } else {
          0.5pt + rgb(210, 210, 210)
        }
      },
      fill: (col, row) => {
        if row == 0 {
          gradient.linear(rgb(235, 245, 255), rgb(220, 235, 250))
        } else if calc.odd(row) {
          rgb(248, 250, 252)
        } else {
          white
        }
      },

      #{generate_table_header(header_labels)},
    """

    File.write!(path, typst_template)
    stream_data_to_file(query, path, header_keys)
    File.write!(path, "\n)", [:append])
  end

  defp generate_table_header(header_labels) do
    header_labels
    |> Enum.map(&"text(weight: \"bold\", #{typst_string(&1)})")
    |> Enum.join(", ")
  end

  defp stream_data_to_file(query, path, header_keys) do
    repo = Application.fetch_env!(:live_table, :repo)

    repo.transaction(
      fn ->
        query
        |> repo.stream(max_rows: 500)
        |> Stream.map(fn row ->
          Enum.map_join(header_keys, ", ", &typst_string(Map.get(row, &1))) <> ",\n"
        end)
        |> Stream.chunk_every(500)
        |> Stream.each(&File.write!(path, &1, [:append]))
        |> Stream.run()
      end,
      timeout: :infinity
    )
  end

  # Cells are Typst string literals, so data is never read as markup or code.
  defp typst_string(nil), do: ~s("")

  defp typst_string(value) do
    escaped =
      value
      |> to_string()
      |> String.replace("\\", "\\\\")
      |> String.replace("\"", "\\\"")

    ~s("#{escaped}")
  end
end
