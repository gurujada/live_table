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
      def handle_event("export", %{"format" => format}, socket) do
        case LiveTable.Export.fetch_format(format) do
          {:ok, exporter} -> enqueue_export(exporter, socket)
          :error -> {:noreply, socket}
        end
      end

      defp enqueue_export(exporter, socket) do
        {export_topic, updated_socket} = maybe_subscribe(socket)

        options = socket.assigns.options |> put_in(["pagination", "paginate?"], false)

        query =
          list_resources(
            fields(),
            options,
            Map.get(socket.assigns, :data_provider) || unquote(opts[:schema])
          )

        case export_limit_error(exporter, query) do
          nil ->
            {:ok, _job} =
              %{
                query: LiveTable.Export.encode_query(query),
                header_data: extract_header_data(),
                topic: export_topic
              }
              |> exporter.worker.new()
              |> Oban.insert()

            {:noreply, updated_socket}

          message ->
            {:noreply, put_flash(updated_socket, :error, message)}
        end
      end

      defp export_limit_error(%{max_records: max}, query) do
        repo = Application.fetch_env!(:live_table, :repo)

        if repo.aggregate(query, :count) > max do
          "Cannot export more than #{max} records. " <>
            "Please apply filters to reduce the dataset."
        end
      end

      defp export_limit_error(_exporter, _query), do: nil

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
