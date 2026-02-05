defmodule LiveTable.LiveViewHelpers do
  @moduledoc false
  defmacro __using__(opts) do
    quote do
      use LiveTable.ExportHelpers, schema: unquote(opts[:schema])

      @impl true
      def handle_params(params, url, socket) do
        current_path = URI.parse(url).path |> String.trim_leading("/")
        default_sort = get_in(unquote(opts[:table_options]), [:sorting, :default_sort])
        table_options = unquote(opts[:table_options])
        data_provider = socket.assigns[:data_provider] || unquote(opts[:data_provider])

        sort_params = parse_sort_params(params, default_sort)
        {live_select_updates, already_restored} = prepare_live_select_updates(params, socket)
        filters = parse_filters(params)
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

      defp parse_sort_params(params, default_sort) do
        Map.get(params, "sort_params", default_sort)
        |> Enum.map(fn
          {k, v} when is_atom(k) and is_atom(v) -> {k, v}
          {k, v} -> {String.to_existing_atom(k), String.to_existing_atom(v)}
        end)
      end

      defp prepare_live_select_updates(params, socket) do
        already_restored = Map.get(socket.assigns, :live_select_restored, MapSet.new())

        live_select_updates =
          Map.get(params, "filters", %{})
          |> Enum.filter(fn {_key, val} -> match?(%{"id" => _}, val) end)
          |> Enum.map(fn {key, %{"id" => ids}} ->
            filter = get_filter(key)
            ids = Enum.map(ids, &String.to_integer/1)
            {filter.key, ids}
          end)
          |> Enum.reject(fn {key, _ids} -> MapSet.member?(already_restored, key) end)

        {live_select_updates, already_restored}
      end

      defp parse_filters(params) do
        Map.get(params, "filters", %{})
        |> Map.put("search", params["search"] || "")
        |> Enum.reduce(%{}, fn
          {"search", search_term}, acc ->
            Map.put(acc, "search", search_term)

          {key, %{"min" => min, "max" => max}}, acc ->
            parse_range_filter(key, min, max, acc)

          {key, %{"id" => id}}, acc ->
            parse_select_filter(key, id, acc)

          {key, custom_data}, acc when is_map(custom_data) ->
            parse_custom_filter(key, custom_data, acc)

          {k, _}, acc ->
            key = k |> String.to_existing_atom()
            Map.put(acc, key, get_filter(k))
        end)
      end

      defp parse_range_filter(key, min, max, acc) do
        filter = get_filter(key)
        {min_val, max_val} = parse_range_values(filter.options, min, max)

        updated_filter =
          filter
          |> Map.update!(:options, fn options ->
            options
            |> Map.put(:current_min, min_val)
            |> Map.put(:current_max, max_val)
          end)

        Map.put(acc, String.to_atom(key), updated_filter)
      end

      defp parse_select_filter(key, id, acc) do
        filter = %LiveTable.Select{} = get_filter(key)
        id = id |> Enum.map(&String.to_integer/1)
        filter = %{filter | options: Map.update!(filter.options, :selected, &(&1 ++ id))}
        Map.put(acc, String.to_existing_atom(key), filter)
      end

      defp parse_custom_filter(key, custom_data, acc) do
        filter = get_filter(key)

        case filter do
          %LiveTable.Transformer{} ->
            updated_filter = %{
              filter
              | options: Map.put(filter.options, :applied_data, custom_data)
            }

            Map.put(acc, String.to_existing_atom(key), updated_filter)

          _ ->
            Map.put(acc, String.to_existing_atom(key), filter)
        end
      end

      defp build_options(sort_params, filters, params, table_options) do
        %{
          "sort" => %{
            "sortable?" => get_in(table_options, [:sorting, :enabled]),
            "sort_params" => sort_params
          },
          "pagination" => %{
            "paginate?" => get_in(table_options, [:pagination, :enabled]),
            "page" => params["page"] |> validate_page_num(),
            "per_page" => params["per_page"] |> validate_per_page()
          },
          "filters" => filters
        }
      end

      defp fetch_resources(options, data_provider) do
        case stream_resources(fields(), options, data_provider) do
          {resources, overflow} ->
            has_next_page = length(overflow) > 0
            updated_options = put_in(options["pagination"][:has_next_page], has_next_page)
            {resources, updated_options}

          resources when is_list(resources) ->
            {resources, options}
        end
      end

      defp track_restored_keys(already_restored, live_select_updates) do
        newly_restored_keys =
          live_select_updates
          |> Enum.map(fn {key, _ids} -> key end)
          |> MapSet.new()

        MapSet.union(already_restored, newly_restored_keys)
      end

      defp restore_live_select_from_params([]), do: :ok

      defp restore_live_select_from_params(updates) do
        for {key, ids} <- updates do
          filter = get_filter(key)

          options =
            case filter.options do
              %{options: opts} when is_list(opts) and opts != [] ->
                opts

              %{options_source: {module, function, args}} ->
                apply(module, function, ["" | args])

              _ ->
                []
            end

          selection =
            Enum.map(ids, fn id ->
              Enum.find(options, fn
                %{value: [opt_id | _]} -> opt_id == id
                %{value: opt_id} -> opt_id == id
                {_label, [opt_id | _]} -> opt_id == id
                {_label, opt_id} -> opt_id == id
                _ -> false
              end) || %{label: to_string(id), value: id}
            end)

          send_update(SutraUI.LiveSelect, id: key, restore_selection: selection)
        end
      end

      defp assign_to_socket(socket, resources, %{use_streams: true}) do
        stream(socket, :resources, resources,
          dom_id: fn resource ->
            "resource-#{Ecto.UUID.generate()}"
          end,
          reset: true
        )
      end

      defp assign_to_socket(socket, resources, %{use_streams: false}) do
        assign(socket, :resources, resources)
      end

      defp maybe_assign_infinite_scroll(socket, %{
             pagination: %{mode: :infinite_scroll}
           }) do
        assign(socket, :infinite_scroll_page, 1)
      end

      defp maybe_assign_infinite_scroll(socket, _table_options), do: socket

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
        max_per_page = get_in(unquote(opts[:table_options]), [:pagination, :max_per_page])

        try do
          num = String.to_integer(n)

          cond do
            num > 0 and num <= max_per_page -> n
            true -> max_per_page |> to_string()
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
          |> remove_unused_keys()

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
