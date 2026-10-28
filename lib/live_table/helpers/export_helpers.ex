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
        exports = LiveTable.TableConfig.get_table_options(table_options()).exports

        with true <- exports.enabled,
             true <- format in Enum.map(exports.formats, &to_string/1),
             {:ok, exporter} <- LiveTable.Export.fetch_format(format) do
          export(format, exporter, socket)
        else
          _ -> {:noreply, socket}
        end
      end

      defp export(format, exporter, socket) do
        options = socket.assigns.options |> put_in(["pagination", "paginate?"], false)

        query =
          list_resources(
            fields(),
            options,
            Map.get(socket.assigns, :data_provider) || unquote(opts[:schema])
          )

        case export_limit_error(exporter, query) do
          nil ->
            path = LiveTable.Export.download_path(socket, format, query, export_columns())
            {:noreply, socket |> push_event("download", %{path: path}) |> export_notice(format)}

          message ->
            {:noreply, put_flash(socket, :error, message)}
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

      # A CSV starts downloading at once; a PDF is built first, which takes a few seconds.
      defp export_notice(socket, "pdf"),
        do: put_flash(socket, :info, "Preparing your PDF. The download will start shortly.")

      defp export_notice(socket, _format), do: socket

      defp export_columns do
        for {key, %{label: label}} <- fields(), do: {key, label}
      end
    end
  end
end
