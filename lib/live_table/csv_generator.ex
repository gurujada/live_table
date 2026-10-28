defmodule LiveTable.CsvGenerator do
  @moduledoc false

  alias NimbleCSV.RFC4180, as: CSV

  # Streams the query as CSV iodata, a header row first. Run it inside a repo transaction.
  def stream(query, columns) do
    repo = Application.fetch_env!(:live_table, :repo)
    {keys, labels} = Enum.unzip(columns)

    rows =
      query
      |> repo.stream(max_rows: 1000)
      |> Stream.map(fn row -> Enum.map(keys, &cell(Map.get(row, &1))) end)
      |> Stream.chunk_every(1000)
      |> Stream.map(&CSV.dump_to_iodata/1)

    Stream.concat([CSV.dump_to_iodata([labels])], rows)
  end

  # Spreadsheets run cells starting with these as formulas; a leading quote keeps them text.
  defp cell(<<first, _::binary>> = value) when first in [?=, ?+, ?-, ?@, ?\t, ?\r],
    do: "'" <> value

  defp cell(value), do: value
end
