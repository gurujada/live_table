# Public API And Review Checklist

Use this when reviewing LiveTable code, deciding whether an API is public, or preventing agents from copying internals.

## Public Authoring Surface

Application LiveViews should use:

```elixir
use LiveTable.LiveResource, schema: MyApp.Schema
```

or:

```elixir
use LiveTable.LiveResource

def mount(_params, _session, socket) do
  {:ok, assign(socket, :data_provider, {MyApp.Context, :provider_query, args})}
end
```

The LiveView may define:

- `fields/0`
- `filters/0`
- `actions/0`
- `table_options/0`
- ordinary action-specific `handle_event/3` callbacks for row buttons or app-specific controls

Render with:

```heex
<.live_table
  fields={fields()}
  filters={filters()}
  options={@options}
  streams={@streams}
/>
```

Add `actions={actions()}` when the LiveView defines row actions.

## Provider Contract

Provider functions return Ecto queries:

```elixir
def list_product_rows do
  from p in Product,
    join: b in assoc(p, :brand),
    as: :brand,
    select: %{
      id: p.id,
      name: p.name,
      brand_name: b.name
    }
end
```

Do not call `Repo.all/1` inside the provider. LiveTable owns execution.

Field keys must match selected keys:

```elixir
def fields do
  [
    name: %{label: "Product", searchable: true},
    brand_name: %{label: "Brand", searchable: true, sortable: true, assoc: {:brand, :name}}
  ]
end
```

Use named bindings (`as: :brand`) for joined field sorting/searching/filtering.

## Internal APIs To Avoid

Do not use these from app code:

- `stream_resources/3`
- `list_resources/3`
- `fetch_resources/2`
- `assign_to_socket/3`
- `LiveTable.Sorting`
- `LiveTable.Paginate`
- `LiveTable.Filter`
- `LiveTable.Join`
- `LiveTable.TableConfig`
- `LiveTable.ParseHelpers`
- `LiveTable.SortHelpers`
- `LiveTable.FilterHelpers`
- `LiveTable.LiveViewHelpers`

If existing application code calls `stream_resources/3`, treat it as a legacy/app-specific workaround. Do not copy it into new LiveTable work.

## Review Checklist

- The LiveView uses `use LiveTable.LiveResource`.
- It chooses either `schema:` or `:data_provider`, not both for a joined/custom query.
- Provider functions return queries, not lists.
- Joined providers use named bindings when fields/filters reference joined tables.
- `fields/0` keys match schema fields or selected map keys.
- Filters use `Boolean.new/3`, `Range.new/3`, `Select.new/3`, or `Transformer.new/2`.
- Transformers always return a query.
- Custom headers submit LiveTable params to the `"sort"` event.
- Infinite scroll is configured through `table_options/0`, not a custom `load_more` handler.
- The template renders `fields`, `filters`, `options`, and `streams`.
- No internal LiveTable helper/module is called directly from app code.
