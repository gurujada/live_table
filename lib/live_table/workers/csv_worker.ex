defmodule LiveTable.Workers.CsvExportWorker do
  @moduledoc false
  use Oban.Worker, queue: :exports

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{"header_data" => header_data, "query" => query, "topic" => topic}
      }) do
    case LiveTable.CsvGenerator.generate_csv(LiveTable.Export.decode_query(query), header_data) do
      {:ok, file_path} ->
        Phoenix.PubSub.broadcast(
          Application.fetch_env!(:live_table, :pubsub),
          topic,
          {:file_ready, file_path}
        )

        :ok
    end
  end
end
