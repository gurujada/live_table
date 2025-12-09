defmodule LiveTable.LiveViewHelpers do
  @moduledoc false
  defmacro __using__(opts) do
    quote do
      use LiveTable.ExportHelpers, schema: unquote(opts[:schema])

      @impl true
      # Fetches records based on URL params
      def handle_params(params, url, socket) do
        default_sort = get_in(unquote(opts[:table_options]), [:sorting, :default_sort])
        current_path = URI.parse(url).path |> String.trim_leading("/")

        sort_params =
          Map.get(params, "sort_params", default_sort)
          |> Enum.map(fn
            # for default case
            {k, v} when is_atom(k) and is_atom(v) -> {k, v}
            # for incoming params from url
            {k, v} -> {String.to_existing_atom(k), String.to_existing_atom(v)}
          end)

        filters =
          Map.get(params, "filters", %{})
          |> Map.put("search", params["search"] || "")
          |> Enum.reduce(%{}, fn
            {"search", search_term}, acc ->
              Map.put(acc, "search", search_term)

            {key, %{"min" => min, "max" => max}}, acc ->
              filter = get_filter(key)
              {min_val, max_val} = parse_range_values(filter.options.type, min, max)

              updated_filter =
                filter
                |> Map.update!(:options, fn options ->
                  options
                  |> Map.put(:current_min, min_val)
                  |> Map.put(:current_max, max_val)
                end)

              key = String.to_atom(key)
              Map.put(acc, key, updated_filter)

            {key, %{"id" => id}}, acc ->
              filter = %LiveTable.Select{} = get_filter(key)
              id = id |> Enum.map(&String.to_integer/1)
              filter = %{filter | options: Map.update!(filter.options, :selected, &(&1 ++ id))}
              key = key |> String.to_existing_atom()
              Map.put(acc, key, filter)

            {key, custom_data}, acc when is_map(custom_data) ->
              filter = get_filter(key)

              case filter do
                %LiveTable.Transformer{} ->
                  updated_filter = %{
                    filter
                    | options: Map.put(filter.options, :applied_data, custom_data)
                  }

                  key = String.to_existing_atom(key)
                  Map.put(acc, key, updated_filter)

                _ ->
                  key = String.to_existing_atom(key)
                  Map.put(acc, key, filter)
              end

            {k, _}, acc ->
              key = k |> String.to_existing_atom()
              Map.put(acc, key, get_filter(k))
          end)

        options = %{
          "sort" => %{
            "sortable?" => get_in(unquote(opts[:table_options]), [:sorting, :enabled]),
            "sort_params" => sort_params
          },
          "pagination" => %{
            "paginate?" => get_in(unquote(opts[:table_options]), [:pagination, :enabled]),
            "page" => params["page"] |> validate_page_num(),
            "per_page" => params["per_page"] |> validate_per_page()
          },
          "filters" => filters
        }

        data_provider = socket.assigns[:data_provider] || unquote(opts[:data_provider])

        {resources, updated_options} =
          case stream_resources(fields(), options, data_provider) do
            {resources, overflow} ->
              has_next_page = length(overflow) > 0
              options = put_in(options["pagination"][:has_next_page], has_next_page)
              {resources, options}

            resources when is_list(resources) ->
              {resources, options}
          end

        # Update LiveSelect components with selected values from URL params
        socket =
          socket
          |> assign_to_socket(resources, unquote(opts[:table_options]))
          |> assign(:options, updated_options)
          |> assign(:current_path, current_path)

        # Update LiveSelect components with selected values from URL params
        for {key, filter} <- filters do
          case filter do
            %LiveTable.Select{options: %{selected: selected}} when selected != [] ->
              # Get the options for this filter
              options =
                case filter.options do
                  %{options: options} when is_list(options) and options != [] ->
                    options

                  %{options_source: {module, function, args}} ->
                    apply(module, function, ["" | args])

                  _ ->
                    []
                end

              # Find the selected options based on the selected IDs
              selected_options =
                Enum.map(selected, fn id ->
                  Enum.find(options, fn
                    %{value: [option_id, _]} -> option_id == id
                    _ -> false
                  end)
                end)
                |> Enum.reject(&is_nil/1)

              # Update the LiveSelect component with the selected options
              if selected_options != [] do
                send_update(LiveSelect.Component, id: filter.key, value: selected_options)
              end

            _ ->
              :ok
          end
        end

        {:noreply, socket}
      end

      defp assign_to_socket(socket, resources, %{use_streams: true}) do
        stream(socket, :resources, resources,
          dom_id: fn resource ->
            # "#{resource}-
            "resource-#{Ecto.UUID.generate()}"
          end,
          reset: true
        )
      end

      defp assign_to_socket(socket, resources, %{use_streams: false}) do
        assign(socket, :resources, resources)
      end

      defp validate_page_num(nil), do: "1"

      defp validate_page_num(n) when is_binary(n) do
        try do
          num = String.to_integer(n)

          cond do
            num > 0 -> n
            true -> "1"
          end
        rescue
          ArgumentError -> "1"
        end
      end

      defp validate_per_page(nil),
        do: get_in(unquote(opts[:table_options]), [:pagination, :default_size]) |> to_string()

      defp validate_per_page(n) when is_binary(n) do
        try do
          num = String.to_integer(n)

          cond do
            num > 0 and num <= 50 -> n
            true -> "50"
          end
        rescue
          ArgumentError ->
            get_in(unquote(opts[:table_options]), [:pagination, :default_size]) |> to_string()
        end
      end

      @impl true
      # Handles all LiveTable related events like sort, paginate and filter

      def handle_event("sort", %{"clear_filters" => "true"}, socket) do
        current_path = socket.assigns.current_path

        options =
          socket.assigns.options
          |> Enum.reduce(%{}, fn
            {"filters", _v}, acc ->
              Map.put(acc, "filters", %{})

            {_, v}, acc when is_map(v) ->
              Map.merge(acc, v)
          end)
          |> Map.take(~w(page per_page sort_params))
          |> Map.reject(fn {_, v} -> v == "" || is_nil(v) end)

        socket =
          socket
          |> push_patch(to: "/#{current_path}?#{Plug.Conn.Query.encode(options)}")

        {:noreply, socket}
      end

      def handle_event("sort", params, socket) do
        shift_key = Map.get(params, "shift_key", false)
        sort_params = Map.get(params, "sort", nil)
        filter_params = Map.get(params, "filters", nil)
        current_path = socket.assigns.current_path

        options =
          socket.assigns.options
          |> Enum.reduce(%{}, fn
            {"filters", %{"search" => search_term} = v}, acc ->
              filters = encode_filters(v)
              Map.put(acc, "filters", filters) |> Map.put("search", search_term)

            {_, v}, acc when is_map(v) ->
              Map.merge(acc, v)
          end)
          |> Map.merge(params, fn
            "filters", v1, v2 when is_map(v1) and is_map(v2) -> v1
            _, _, v -> v
          end)
          |> update_sort_params(sort_params, shift_key)
          |> update_filter_params(filter_params)
          |> Map.take(~w(page per_page search sort_params filters))
          |> Map.reject(fn {_, v} -> v == "" || is_nil(v) end)
          |> remove_unused_keys()

        socket =
          socket
          |> push_patch(to: "/#{current_path}?#{Plug.Conn.Query.encode(options)}")

        {:noreply, socket}
      end

      def handle_event("change", params, socket) do
        params |> dbg()
        {:noreply, socket}
      end

      def handle_event("submit", params, socket) do
        params |> dbg()
        {:noreply, socket}
      end

      def handle_event("live_select_change", %{"text" => text, "id" => id}, socket) do
        options =
          case get_filter(id) do
            %LiveTable.Select{
              options: %{options: _options, options_source: {module, function, args}}
            } ->
              apply(module, function, [text | args])

            %LiveTable.Select{options: %{options: options, options_source: nil}} ->
              options
          end

        send_update(LiveSelect.Component, id: id, options: options)

        {:noreply, socket}
      end

      def remove_unused_keys(map) when is_map(map) do
        map
        |> Map.reject(fn {key, _value} ->
          key_string = to_string(key)
          String.starts_with?(key_string, "_unused")
        end)
        |> Enum.map(fn {key, value} ->
          {key, remove_unused_keys(value)}
        end)
        |> Enum.into(%{})
      end

      def remove_unused_keys(value), do: value
    end
  end
end
