defmodule LiveTable.ExportHelpers do
  @moduledoc false

  @doc false
  def generate_export_timestamp do
    DateTime.utc_now()
    |> DateTime.to_string()
    |> String.replace([" ", ":", "."], "-")
    |> String.replace(~r/[^a-zA-Z0-9\-]/, "")
  end

  defmacro __using__(opts) do
    quote do
      def handle_event("export-csv", _params, socket) do
        {export_topic, updated_socket} = maybe_subscribe(socket)
        header_data = extract_header_data()
        options = socket.assigns.options |> put_in(["pagination", "paginate?"], false)

        query_string =
          list_resources(
            fields(),
            options,
            Map.get(socket.assigns, :data_provider) || unquote(opts[:schema])
          )
          |> inspect()

        {:ok, _job} =
          %{
            query: query_string,
            header_data: header_data,
            topic: export_topic
          }
          |> LiveTable.Workers.CsvExportWorker.new()
          |> Oban.insert()

        {:noreply, updated_socket}
      end

      def handle_event("export-pdf", _params, socket) do
        {export_topic, updated_socket} = maybe_subscribe(socket)

        options = socket.assigns.options |> put_in(["pagination", "paginate?"], false)

        count_query =
          list_resources(
            fields(),
            options,
            Map.get(socket.assigns, :data_provider) || unquote(opts[:schema])
          )

        case Application.get_env(:live_table, :repo).aggregate(count_query, :count) do
          count when count > 10_000 ->
            {:noreply,
             put_flash(
               updated_socket,
               :error,
               "Cannot export more than 10,000 records. Please apply filters to reduce the dataset."
             )}

          _ ->
            header_data = extract_header_data()

            query_string =
              list_resources(
                fields(),
                options,
                Map.get(socket.assigns, :data_provider) || unquote(opts[:schema])
              )
              |> inspect()

            {:ok, _job} =
              %{
                query: query_string,
                header_data: header_data,
                topic: export_topic
              }
              |> LiveTable.Workers.PdfExportWorker.new()
              |> Oban.insert()

            {:noreply, updated_socket}
        end
      end

      # Extracts header keys and labels from fields for export
      defp extract_header_data do
        fields()
        |> Enum.reduce([[], []], fn {k, %{label: label}}, [key_names, headers] ->
          [[k | key_names], [label | headers]]
        end)
        |> Enum.map(&Enum.reverse/1)
      end

      defp maybe_subscribe(socket) do
        case socket.assigns[:export_topic] do
          nil ->
            client_id = Ecto.UUID.generate()
            export_topic = "exports:#{client_id}"

            updated_socket = assign(socket, export_topic: export_topic)

            if connected?(socket) do
              Phoenix.PubSub.subscribe(Application.fetch_env!(:live_table, :pubsub), export_topic)
            end

            {export_topic, updated_socket}

          export_topic ->
            {export_topic, socket}
        end
      end

      @impl true
      def handle_info({:file_ready, file_path}, socket) do
        app_name = Application.fetch_env!(:live_table, :app)
        static_path = Path.join([:code.priv_dir(app_name), "static", "exports"])
        File.mkdir_p!(static_path)

        filename = Path.basename(file_path)
        dest_path = Path.join(static_path, filename)
        File.cp!(file_path, dest_path)

        socket =
          socket
          |> push_event("download", %{path: "/exports/#{filename}"})
          |> put_flash(:info, "File downloaded successfully.")

        Process.send_after(self(), {:cleanup_file, dest_path}, :timer.seconds(20))
        File.rm(file_path)
        {:noreply, socket}
      end

      def handle_info({:cleanup_file, file_path}, socket) do
        File.rm(file_path)
        {:noreply, socket}
      end
    end
  end
end
