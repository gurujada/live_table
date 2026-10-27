defmodule LiveTable.Components do
  @moduledoc """
  The UI components LiveTable renders its controls and filters with.

  LiveTable owns the query, URL state, sorting and exports. A components module
  owns how the controls look. With `:sutra_ui` installed, LiveTable uses
  `LiveTable.Components.Sutra` and nothing needs configuring.

  To use your own UI, implement this behaviour and configure it in `config/config.exs`:

      config :live_table, components: MyAppWeb.TableComponents

  To change only some components and keep the rest from Sutra UI:

      defmodule MyAppWeb.TableComponents do
        use LiveTable.Components.Sutra

        def per_page(assigns), do: ~H"..."
      end

  Every component posts plain form fields inside LiveTable's controls form.
  See the [Custom Components guide](custom-components.html) for the assigns and
  field names each one must use.
  """

  @doc "Search input. Posts `search`."
  @callback search(assigns :: map()) :: Phoenix.LiveView.Rendered.t()

  @doc "Page size picker. Posts `per_page`."
  @callback per_page(assigns :: map()) :: Phoenix.LiveView.Rendered.t()

  @doc "Export menu. Each item sends `phx-click=\"export\"` with `phx-value-format`."
  @callback exports(assigns :: map()) :: Phoenix.LiveView.Rendered.t()

  @doc "Shown when there are no records and no `empty_state` callback is configured."
  @callback empty_state(assigns :: map()) :: Phoenix.LiveView.Rendered.t()

  @doc "`LiveTable.Boolean` filter. Posts `filters[key]` as `\"true\"` or `\"false\"`."
  @callback boolean_filter(assigns :: map()) :: Phoenix.LiveView.Rendered.t()

  @doc "`LiveTable.Range` filter. Posts `filters[key][min]` and `filters[key][max]`."
  @callback range_filter(assigns :: map()) :: Phoenix.LiveView.Rendered.t()

  @doc "`LiveTable.Select` filter. Posts `filters[key][id][]`."
  @callback select_filter(assigns :: map()) :: Phoenix.LiveView.Rendered.t()

  @optional_callbacks boolean_filter: 1, range_filter: 1, select_filter: 1

  @doc false
  def impl do
    resolve(Application.get_env(:live_table, :components), sutra?())
  end

  @doc false
  def resolve(nil, true), do: LiveTable.Components.Sutra

  def resolve(nil, false) do
    raise ArgumentError, """
    LiveTable needs :sutra_ui or a components module.

    Add {:sutra_ui, "~> 0.4.0"} to your deps, or implement LiveTable.Components and configure it:

        config :live_table, components: MyAppWeb.TableComponents

    See the Custom Components guide.
    """
  end

  def resolve(module, _sutra?) when is_atom(module), do: module

  @doc false
  def sutra?, do: Code.ensure_loaded?(SutraUI)

  @doc false
  def render(component, assigns) do
    module = impl()

    if Code.ensure_loaded?(module) and function_exported?(module, component, 1) do
      apply(module, component, [assigns])
    else
      raise ArgumentError,
            "#{inspect(module)} does not implement #{component}/1, " <>
              "which LiveTable needs to render this filter. See the Custom Components guide."
    end
  end
end
