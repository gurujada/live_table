defmodule LiveTable.LiveViewHelpers do
  @moduledoc false
  defmacro __using__(opts) do
    quote do
      use LiveTable.ExportHelpers, schema: unquote(opts[:schema])
      import LiveTable.LiveSelectHelpers
      import LiveTable.ParseHelpers
      import LiveTable.ResourceLoader

      @impl true
      def handle_params(params, url, socket) do
        current_path = URI.parse(url).path |> String.trim_leading("/")
        default_sort = get_in(unquote(opts[:table_options]), [:sorting, :default_sort])
        table_options = unquote(opts[:table_options])
        data_provider = socket.assigns[:data_provider] || unquote(opts[:data_provider])

        sort_params = parse_sort_params(params, default_sort)
        {live_select_updates, already_restored} = prepare_live_select_updates(params, socket)
        filters = parse_filters(params, socket)
        options = build_options(sort_params, filters, params, table_options)

        {resources, updated_options} = fetch_resources(options, data_provider)
        updated_restored = track_restored_keys(already_restored, live_select_updates)

        socket =
          socket
          |> assign_to_socket(resources, table_options)
          |> assign(:options, updated_options)
          |> assign(:current_path, current_path)
          |> assign(:live_select_restored, updated_restored)
          |> maybe_assign_infinite_scroll(table_options)

        restore_live_select_from_params(live_select_updates)

        {:noreply, socket}
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

        # Clear all LiveSelect components when clearing filters
        for {_filter_key, filter} <- filters() do
          case filter do
            %LiveTable.Select{} ->
              send_update(SutraUI.LiveSelect, id: filter.key, reset_value: [])

            _ ->
              :ok
          end
        end

        socket =
          socket
          |> assign(:live_select_restored, MapSet.new())
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

        socket =
          socket
          |> push_patch(to: "/#{current_path}?#{Plug.Conn.Query.encode(options)}")

        {:noreply, socket}
      end

      # Handle range_change events from Sutra's range_slider
      # Payload format: %{"key_min" => val, "key_max" => val}
      # Transforms to: %{"filters" => %{key => %{"min" => val, "max" => val}}}
      def handle_event("range_change", params, socket) do
        {key, min, max} = extract_range_params(params)

        handle_event(
          "sort",
          %{"filters" => %{key => %{"min" => min, "max" => max}}},
          socket
        )
      end

      defp extract_range_params(params) do
        {min_key, min_val} =
          Enum.find(params, fn {k, _v} -> String.ends_with?(k, "_min") end)

        {_max_key, max_val} =
          Enum.find(params, fn {k, _v} -> String.ends_with?(k, "_max") end)

        key = String.replace_suffix(min_key, "_min", "")
        filter = get_filter(key)
        {min_val, max_val} = maybe_convert_to_integer(min_val, max_val, filter)

        {key, min_val, max_val}
      end

      defp maybe_convert_to_integer(min_val, max_val, %LiveTable.Range{options: %{step: step}})
           when is_integer(step) do
        {trunc(min_val), trunc(max_val)}
      end

      defp maybe_convert_to_integer(min_val, max_val, _filter), do: {min_val, max_val}

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

        send_update(SutraUI.LiveSelect, id: id, options: options)

        {:noreply, socket}
      end

      def handle_event("load_more", _params, socket) do
        next_page = socket.assigns.infinite_scroll_page + 1

        options =
          socket.assigns.options
          |> put_in(["pagination", "page"], to_string(next_page))

        data_provider = socket.assigns[:data_provider] || unquote(opts[:data_provider])

        {resources, has_next_page} =
          case stream_resources(fields(), options, data_provider) do
            {resources, overflow} ->
              {resources, length(overflow) > 0}

            resources when is_list(resources) ->
              {resources, false}
          end

        updated_options =
          put_in(options["pagination"][:has_next_page], has_next_page)

        socket =
          socket
          |> stream(:resources, resources,
            dom_id: fn _resource -> "resource-#{Ecto.UUID.generate()}" end
          )
          |> assign(:infinite_scroll_page, next_page)
          |> assign(:options, updated_options)

        {:noreply, socket}
      end

      def assign_to_socket(socket, resources, %{use_streams: true}) do
        stream(socket, :resources, resources,
          dom_id: fn _resource ->
            "resource-#{Ecto.UUID.generate()}"
          end,
          reset: true
        )
      end

      def assign_to_socket(socket, resources, %{use_streams: false}) do
        assign(socket, :resources, resources)
      end

      def maybe_assign_infinite_scroll(socket, %{
            pagination: %{mode: :infinite_scroll}
          }) do
        assign(socket, :infinite_scroll_page, 1)
      end

      def maybe_assign_infinite_scroll(socket, _table_options), do: socket

      def fetch_resources(options, data_provider) do
        case stream_resources(fields(), options, data_provider) do
          {resources, overflow} ->
            has_next_page = length(overflow) > 0
            updated_options = put_in(options["pagination"][:has_next_page], has_next_page)
            {resources, updated_options}

          resources when is_list(resources) ->
            {resources, options}
        end
      end
    end
  end
end
