defmodule LiveTable.LiveSelectHelpers do
  import Phoenix.LiveView

  def prepare_live_select_updates(params, socket, filters) do
    already_restored = Map.get(socket.assigns, :live_select_restored, MapSet.new())

    live_select_updates =
      Map.get(params, "filters", %{})
      |> Enum.filter(fn {_key, val} -> match?(%{"id" => _}, val) end)
      |> Enum.map(fn {key, %{"id" => ids}} ->
        filter = LiveTable.ParseHelpers.get_filter(key, filters)
        ids = Enum.map(ids, &LiveTable.ParseHelpers.coerce_select_value/1)
        {filter.key, ids}
      end)
      |> Enum.reject(fn {key, _ids} -> MapSet.member?(already_restored, key) end)

    {live_select_updates, already_restored}
  end

  def track_restored_keys(already_restored, live_select_updates) do
    newly_restored_keys =
      live_select_updates
      |> Enum.map(fn {key, _ids} -> key end)
      |> MapSet.new()

    MapSet.union(already_restored, newly_restored_keys)
  end

  def restore_live_select_from_params([], _filters), do: :ok

  def restore_live_select_from_params(updates, filters) do
    for {key, ids} <- updates do
      filter = LiveTable.ParseHelpers.get_filter(key, filters)

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
            %{value: [opt_id | _]} -> values_match?(opt_id, id)
            %{value: opt_id} -> values_match?(opt_id, id)
            {_label, [opt_id | _]} -> values_match?(opt_id, id)
            {_label, opt_id} -> values_match?(opt_id, id)
            _ -> false
          end) || %{label: to_string(id), value: id}
        end)

      send_update(SutraUI.LiveSelect, id: key, restore_selection: selection)
    end
  end

  defp values_match?(opt_id, id) when is_atom(opt_id) and is_binary(id) do
    opt_id == id or Atom.to_string(opt_id) == id
  end

  defp values_match?(opt_id, id), do: opt_id == id
end
