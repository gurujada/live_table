defmodule LiveTable.PdfGenerator do
  @moduledoc false
  # A module for generating PDF files from Ecto queries using Typst.
  # This module provides functionality to convert Ecto queries into formatted PDF files,
  # with support for custom headers and efficient streaming of large datasets. It uses
  # Typst as an intermediate format for PDF generation.

  @repo Application.compile_env(:live_table, :repo)
  import Ecto.Query, only: [limit: 2]
  # Generates a PDF file from an Ecto query with specified headers.
  def generate_pdf(query, header_data) do
    timestamp = LiveTable.ExportHelpers.generate_export_timestamp()
    temp_path = Path.join(System.tmp_dir!(), "export-#{timestamp}.typ")
    query = LiveTable.CsvGenerator.get_query(query) |> limit(10_000)

    case generate_typst_file(query, temp_path, header_data) do
      {:ok, path} -> compile_typst_to_pdf(path)
      error -> error
    end
  end

  defp generate_typst_file(query, path, [header_keys, header_labels]) do
    typst_template = """
    #set page(
      paper: "a4",
      margin: (x: 0.8cm, y: 0.8cm),
      flipped: true,
    )

    #set text(
      font: "Fira Sans",
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

    case stream_data_to_file(query, path, header_keys) do
      {:ok, _} ->
        File.write!(path, "\n)", [:append])
        {:ok, path}

      error ->
        error
    end
  end

  defp generate_table_header(header_labels) do
    header_labels
    |> Enum.map(&"[*#{&1}*]")
    |> Enum.join(", ")
  end

  defp stream_data_to_file(query, path, header_keys) do
    atom_keys = Enum.map(header_keys, &String.to_atom/1)

    apply(
      @repo,
      :transaction,
      [
        fn ->
          apply(@repo, :stream, [query, [max_rows: 500]])
          |> Stream.map(fn row ->
            atom_keys
            |> Enum.map(fn key -> Map.get(row, key) |> format_value() end)
            |> Enum.join(", ")
            |> Kernel.<>(",\n")
          end)
          |> Stream.chunk_every(500)
          |> Stream.each(fn chunk ->
            if Process.whereis(:chunk_monitor) do
              send(:chunk_monitor, {:chunk, length(chunk)})
            end

            File.write!(path, Enum.join(chunk, ""), [:append])
          end)
          |> Stream.run()

          {:ok, path}
        end,
        [timeout: :infinity]
      ]
    )
  end

  defp compile_typst_to_pdf(tp_path) do
    pdf_path = String.replace(tp_path, ".typ", ".pdf")

    case System.cmd("typst", ["compile", tp_path, pdf_path]) do
      {_, 0} ->
        {:ok, pdf_path}

      # File.rm(tp_path)
      {error, _} ->
        {:error, "Failed to compile PDF: #{error}"}
    end
  end

  defp format_value(value) when is_binary(value) do
    value = value |> String.replace("@", "\\@")
    "[#{value}]"
  end

  defp format_value(value), do: "[#{value}]"
end
