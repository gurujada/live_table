defmodule LiveTable.PdfGenerator do
  @moduledoc false
  # Renders an Ecto query as a PDF table with the optional `:typst` package.

  import Ecto.Query, only: [limit: 2]

  @compile {:no_warn_undefined, Typst}

  def available?, do: Code.ensure_loaded?(Typst)

  def render(query, columns) do
    {keys, labels} = Enum.unzip(columns)
    markup = typst_markup(limit(query, 10_000), keys, labels)

    # render_to_pdf/3 evaluates its template as EEx, so the markup, which holds the
    # table's data, goes in as a binding: EEx inserts it without evaluating it.
    case Typst.render_to_pdf("<%= markup %>", [markup: markup],
           root_dir: empty_dir(),
           extra_fonts: Application.get_env(:live_table, :pdf_font_dirs, [])
         ) do
      {:ok, pdf} -> {:ok, pdf}
      {:error, reason} -> {:error, "Failed to compile PDF: #{reason}"}
    end
  end

  # Typst resolves file paths from root_dir; give it nothing to read.
  defp empty_dir do
    dir = Path.join(System.tmp_dir!(), "live_table_typst_root")
    File.mkdir_p!(dir)
    dir
  end

  defp typst_markup(query, header_keys, header_labels) do
    typst_template = """
    #set page(
      paper: "a4",
      margin: (x: 0.8cm, y: 0.8cm),
      flipped: true,
    )

    #set text(
      font: ("IBM Plex Sans", "IBM Plex Sans Devanagari", "Noto Sans Arabic", "Noto Serif Hebrew"),
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

    IO.iodata_to_binary([typst_template, rows(query, header_keys), "\n)"])
  end

  defp generate_table_header(header_labels) do
    header_labels
    |> Enum.map(&"text(weight: \"bold\", #{typst_string(&1)})")
    |> Enum.join(", ")
  end

  defp rows(query, header_keys) do
    repo = Application.fetch_env!(:live_table, :repo)

    {:ok, rows} =
      repo.transaction(
        fn ->
          query
          |> repo.stream(max_rows: 500)
          |> Enum.map(fn row ->
            [Enum.map_join(header_keys, ", ", &typst_string(Map.get(row, &1))), ",\n"]
          end)
        end,
        timeout: :infinity
      )

    rows
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
