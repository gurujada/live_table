defmodule LiveTable.Export do
  @moduledoc false

  @formats %{
    "csv" => %{worker: LiveTable.Workers.CsvExportWorker},
    "pdf" => %{worker: LiveTable.Workers.PdfExportWorker, max_records: 10_000}
  }

  def fetch_format(format) when is_binary(format), do: Map.fetch(@formats, format)

  def validate_formats!(formats) do
    unknown = Enum.reject(formats, &(is_atom(&1) and Map.has_key?(@formats, Atom.to_string(&1))))

    if unknown != [] do
      raise ArgumentError,
            "unsupported export format(s) #{inspect(unknown)}. Supported formats: csv, pdf."
    end

    formats
  end

  # Oban stores JSON args; serialize the actual query rather than its printed representation.
  def encode_query(%Ecto.Query{} = query) do
    query |> :erlang.term_to_binary() |> Base.encode64()
  end

  def decode_query(encoded) when is_binary(encoded) do
    decoded =
      try do
        encoded |> Base.decode64!() |> :erlang.binary_to_term([:safe])
      rescue
        ArgumentError -> raise ArgumentError, "corrupt export query payload"
      end

    case decoded do
      %Ecto.Query{} = query -> query
      _ -> raise ArgumentError, "expected an Ecto query in the export payload"
    end
  end

  def decode_query(_) do
    raise ArgumentError, "expected an encoded export query"
  end
end
