# Custom Components

LiveTable handles the query, URL state, sorting, pagination and exports. The
controls the user sees (search, page size, export menu, empty state and the
filter widgets) come from a **components module**.

- **With [Sutra UI](https://github.com/gurujada/sutra_ui)** (recommended), LiveTable
  uses `LiveTable.Components.Sutra`. There is nothing to configure.
- **Without Sutra UI**, write a module that implements `LiveTable.Components` and
  configure it. LiveTable compiles and runs without `:sutra_ui`.

## Configuring a components module

```elixir
# config/config.exs
config :live_table, components: MyAppWeb.TableComponents
```

Set this in `config/config.exs`, not `runtime.exs`: LiveTable checks it when your
LiveViews compile. If there is neither Sutra UI nor a components module, compilation
fails with a message pointing here.

## Changing a few components, keeping Sutra UI

`use LiveTable.Components.Sutra` inherits every Sutra UI component. Define only
the ones you want to change:

```elixir
defmodule MyAppWeb.TableComponents do
  use LiveTable.Components.Sutra
  use Phoenix.Component

  def per_page(assigns) do
    ~H"""
    <select name="per_page">
      <option :for={size <- @sizes} value={size} selected={to_string(size) == @value}>
        {size}
      </option>
    </select>
    """
  end
end
```

## The contract

Every component renders inside LiveTable's controls form, which sends a
`phx-change="sort"` event. A component only has to render inputs with the
field names below. LiveTable reads them, updates the URL and runs the query.

| Function | Assigns | Must post |
|---|---|---|
| `search/1` | `id`, `value`, `placeholder`, `debounce` | `search` |
| `per_page/1` | `id`, `nonce`, `value` (string), `sizes` | `per_page` |
| `exports/1` | `id`, `nonce`, `formats` (e.g. `[:csv, :pdf]`) | a `phx-click="export"` button per format, with `phx-value-format` |
| `empty_state/1` | `table_options` | nothing |
| `boolean_filter/1` | `key`, `filter`, `applied_filters` | `filters[key]` as `"true"`, plus a hidden `"false"` |
| `range_filter/1` | `key`, `filter`, `applied_filters`, `current_min`, `current_max`, `pips_config` | `filters[key][min]` and `filters[key][max]` |
| `select_filter/1` | `key`, `filter`, `applied_filters` | `filters[key][id][]`, one value per selected id |

`id` is derived from the table's `id` assign, so several tables can share a page.
`nonce` is the table's CSP nonce (or `nil`); set it on any inline `<script>` you render.

`boolean_filter/1`, `range_filter/1` and `select_filter/1` are optional. Implement
the ones for the filter types you use. If a table uses a filter type your module
does not implement, LiveTable raises an error naming the missing function.

`filter.options` holds the options passed to `Boolean.new/3`, `Range.new/3` or
`Select.new/3`, with defaults applied, such as `label`, `min`, `max`, `step`,
`default_min`, `default_max` and `options`.

Blank or non-numeric range bounds fall back to `default_min` and `default_max`.

### Select with `options_source`

Search-as-you-type for `Select` (`options_source`) is driven by Sutra UI's
LiveSelect. Without Sutra UI, a select component works with static `options:`.
For search-as-you-type, build it into your own component, or use a
[Transformer](transformers.md) with a custom `render`.

## A complete module without Sutra UI

Plain HTML inputs. Add your own classes or use your app's components.

```elixir
defmodule MyAppWeb.TableComponents do
  @behaviour LiveTable.Components
  use Phoenix.Component

  @impl true
  def search(assigns) do
    ~H"""
    <input type="search" id={@id} name="search" value={@value}
      placeholder={@placeholder} phx-debounce={@debounce} />
    """
  end

  @impl true
  def per_page(assigns) do
    ~H"""
    <select id={@id} name="per_page">
      <option :for={size <- @sizes} value={size} selected={to_string(size) == @value}>
        {size}
      </option>
    </select>
    """
  end

  @impl true
  def exports(assigns) do
    ~H"""
    <button :for={format <- @formats} type="button" phx-click="export" phx-value-format={format}>
      Export {String.upcase(to_string(format))}
    </button>
    """
  end

  @impl true
  def empty_state(assigns) do
    ~H"""
    <p>No records found.</p>
    """
  end

  @impl true
  def boolean_filter(assigns) do
    ~H"""
    <input type="hidden" name={"filters[#{@key}]"} value="false" />
    <input type="checkbox" id={"filters-#{@key}"} name={"filters[#{@key}]"} value="true"
      checked={Map.has_key?(@applied_filters, @key)} />
    <label for={"filters-#{@key}"}>{@filter.options.label}</label>
    """
  end

  @impl true
  def range_filter(assigns) do
    ~H"""
    <fieldset>
      <legend>{@filter.options.label}</legend>
      <input type="number" name={"filters[#{@key}][min]"} step={@filter.options.step}
        value={@current_min || @filter.options.default_min} />
      <input type="number" name={"filters[#{@key}][max]"} step={@filter.options.step}
        value={@current_max || @filter.options.default_max} />
    </fieldset>
    """
  end

  @impl true
  def select_filter(assigns) do
    ~H"""
    <label for={"filters-#{@key}"}>{@filter.options.label}</label>
    <select id={"filters-#{@key}"} name={"filters[#{@key}][id][]"} multiple>
      <option :for={option <- @filter.options.options} value={option_id(option)}
        selected={option_id(option) in selected_ids(@applied_filters, @key)}>
        {option.label}
      </option>
    </select>
    """
  end

  defp option_id(%{value: [id | _]}), do: id
  defp option_id(%{value: id}), do: id

  defp selected_ids(applied_filters, key) do
    case Map.get(applied_filters, key) do
      %LiveTable.Select{options: %{selected: selected}} -> selected
      _ -> []
    end
  end
end
```

## Styling the rest of the table

The table, sort headers, pagination buttons and filter layout are LiveTable's own
markup. They use Sutra UI class names (`table`, `btn-outline`) and
theme colors (`bg-muted`, `text-foreground`, `border-border`). Without Sutra UI,
style those classes in your CSS, or replace the sections with `custom_header`,
`custom_controls`, `custom_content` and `custom_footer`
(see [Configuration](configuration.md#custom-components)).
