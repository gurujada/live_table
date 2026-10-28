defmodule LiveTable.Export do
  @moduledoc false

  @formats %{
    "csv" => %{content_type: "text/csv"},
    "pdf" => %{content_type: "application/pdf", max_records: 10_000}
  }

  @path "/live_table/exports"
  @salt "live_table export"
  # The browser follows the link as soon as it receives it.
  @max_age 60

  def fetch_format(format) when is_binary(format), do: Map.fetch(@formats, format)

  def validate_formats!(formats) do
    unknown = Enum.reject(formats, &(is_atom(&1) and Map.has_key?(@formats, Atom.to_string(&1))))

    if unknown != [] do
      raise ArgumentError,
            "unsupported export format(s) #{inspect(unknown)}. Supported formats: csv, pdf."
    end

    formats
  end

  # The query is encrypted into the download link, so whoever holds the link gets exactly
  # this export and nothing else, on any node, without storing anything.
  def download_path(context, format, query, columns) do
    data =
      :erlang.term_to_binary(%{format: format, query: query, columns: columns}, [:compressed])

    "#{@path}/#{Phoenix.Token.encrypt(context, @salt, data)}"
  end

  # Only download_path/4 can produce a token that decrypts with the app's secret.
  def verify(context, token) do
    case Phoenix.Token.decrypt(context, @salt, token, max_age: @max_age) do
      {:ok, data} -> {:ok, Plug.Crypto.non_executable_binary_to_term(data, [:safe])}
      {:error, _reason} -> :error
    end
  end
end
