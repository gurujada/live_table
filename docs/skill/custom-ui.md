# Custom UI

Use this for custom headers, domain controls, custom controls, custom content, custom footers, and transformer-backed UI state.

## Custom Header Contract

Point `table_options/0` to a component function:

```elixir
def table_options do
  %{
    custom_header: {MyAppWeb.CollegeLive.CustomHeader, :custom_header}
  }
end
```

The function receives LiveTable assigns, including `@fields`, `@filters`, `@options`, and `@table_options`.

Controls should submit through LiveTable's `"sort"` event:

```elixir
defmodule MyAppWeb.CollegeLive.CustomHeader do
  use MyAppWeb, :html

  def custom_header(assigns) do
    ~H"""
    <.form
      for={%{}}
      id="college-controls-form"
      phx-change="sort"
      phx-debounce={@table_options.search.debounce}
    >
      <input
        type="text"
        name="search"
        value={@options["filters"]["search"]}
        autocomplete="off"
      />

      <input
        type="number"
        name="filters[rank][value]"
        value={transformer_value(@options, :rank, "value", "")}
      />

      <select name="filters[sort_mode][sort_by]">
        <option value="">Default</option>
        <option value="NIRF Ranking">NIRF Ranking</option>
        <option value="Name (A-Z)">Name (A-Z)</option>
      </select>

      <button type="button" phx-click="sort" phx-value-clear_filters="true">
        Clear
      </button>
    </.form>
    """
  end

  defp transformer_value(options, key, field, default) do
    case Map.get(options["filters"], key) do
      nil -> default
      transformer -> Map.get(transformer.options.applied_data, field, default)
    end
  end
end
```

Use these parameter names:

- `search` for global search.
- `filters[filter_key]` for simple boolean/select values.
- `filters[transformer_key][field]` for transformer payloads.
- `phx-click="sort"` with `phx-value-clear_filters="true"` to clear filters.

Do not use custom header controls to manually query and assign rows.

## Custom Controls

Use `custom_controls` when replacing only the controls area while keeping LiveTable's header/content structure:

```elixir
def table_options do
  %{
    custom_controls: {MyAppWeb.ProductLive.Controls, :controls}
  }
end
```

`custom_controls` is ignored when `custom_header` is set.

## Custom Content And Footer

Use `custom_content` or `custom_footer` only when the app intentionally replaces those sections:

```elixir
def table_options do
  %{
    custom_content: {MyAppWeb.ProductLive.Content, :content},
    custom_footer: {MyAppWeb.ProductLive.Footer, :footer}
  }
end
```

Custom content receives LiveTable assigns. It should render existing data from assigns and preserve LiveTable's state model. Do not re-query inside custom content.

## Transformer State In UI

Transformer state is stored in `@options["filters"]`:

```elixir
defp transformer_value(options, key, field, default) do
  case Map.get(options["filters"], key) do
    nil -> default
    transformer -> Map.get(transformer.options.applied_data, field, default)
  end
end
```

Use this to keep custom controls in sync with URL params and LiveTable state.
