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

  defp typst_markup(query, keys, labels) do
    rows = fetch_rows(query)

    # Numbers line up on the right; everything else reads from the left.
    align =
      case rows do
        [first | _] ->
          Enum.map_join(keys, ", ", &if(number?(first[&1]), do: "right", else: "left"))

        [] ->
          "left"
      end

    footer = "Exported #{Calendar.strftime(Date.utc_today(), "%-d %b %Y")}, #{count(rows)}"

    # The table is marked as a PDF artifact: tagging every cell for accessibility makes a
    # 10,000-row export about 30 times larger. CSV is the machine-readable export.
    """
    #set page(
      paper: "a4",
      flipped: true,
      margin: (x: 1cm, top: 1cm, bottom: 1.5cm),
      footer: context text(
        size: 7pt,
        fill: luma(120),
        #{typst_string(footer)} + h(1fr) + counter(page).display("1 of 1", both: true),
      ),
    )

    #set text(
      font: ("IBM Plex Sans", "IBM Plex Sans Devanagari", "Noto Sans Arabic", "Noto Serif Hebrew"),
      size: 8pt,
    )

    #pdf.artifact(table(
      columns: #{length(labels)},
      inset: (x: 6pt, y: 5pt),
      align: (#{align},).map(a => a + horizon),
      stroke: (_, y) => (bottom: if y == 0 { 0.8pt + luma(80) } else { 0.4pt + luma(225) }),
      fill: (_, y) => if y == 0 { luma(243) },
      table.header(#{Enum.map_join(labels, ", ", &"text(weight: \"bold\", #{typst_string(&1)})")}),
    #{Enum.map(rows, fn row -> [Enum.map_join(keys, ", ", &typst_string(row[&1])), ",\n"] end)}))
    """
  end

  defp fetch_rows(query) do
    repo = Application.fetch_env!(:live_table, :repo)

    {:ok, rows} =
      repo.transaction(fn -> query |> repo.stream(max_rows: 500) |> Enum.to_list() end,
        timeout: :infinity
      )

    rows
  end

  defp number?(value), do: is_number(value) or is_struct(value, Decimal)

  defp count([_]), do: "1 row"

  defp count(rows) do
    digits = rows |> length() |> Integer.to_string()
    "#{Regex.replace(~r/\B(?=(\d{3})+$)/, digits, ",")} rows"
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
