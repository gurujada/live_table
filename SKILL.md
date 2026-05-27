---
name: livetable
description: Use when building, modifying, or reviewing Phoenix LiveView tables with LiveTable, including schema-backed tables, custom data providers, filters, transformers, card mode, custom headers, actions, and query behavior. This skill prevents hallucinated LiveTable APIs and teaches the public usage patterns only.
---

# LiveTable

LiveTable is a Phoenix LiveView library for realtime data tables. Use it from a LiveView by calling `use LiveTable.LiveResource` and rendering the generated `<.live_table />` component. Do not call LiveTable's internal query, sorting, pagination, filter, or helper modules directly from application code.

## First Decision

Pick exactly one data source pattern.

Use a standalone schema table when the table is a direct query over one Ecto schema:

```elixir
use LiveTable.LiveResource, schema: MyApp.Products.Product
```

Use a custom data provider when the table needs joins, computed fields, custom selects, aggregations, subqueries, or any app-specific base query:

```elixir
use LiveTable.LiveResource

def mount(_params, _session, socket) do
  {:ok, assign(socket, :data_provider, {MyApp.Products, :list_product_rows, []})}
end
```

The provider function must return an Ecto query. It must not call `Repo.all/1`. LiveTable will apply filters, transformers, sorting, pagination, and execution.

## Non-Negotiable Rules

- Only use LiveTable through `use LiveTable.LiveResource` in a LiveView and `<.live_table />` in the template/render function.
- Do not invent functions such as `LiveTable.query/2`, `LiveTable.render/1`, `LiveTable.load/2`, `LiveTable.Sorting.sort/3`, or direct calls to `Sorting.sort`, `Paginate.paginate`, `Filter.apply_text_search`, `list_resources`, or `stream_resources`.
- Do not call private or internal LiveTable modules from app code. If a behavior is not available through fields, filters, table options, custom providers, transformers, renderers, actions, or custom headers, do not assume it exists.
- Field keys must match the data source exactly: schema field names for standalone schema tables, selected map keys for custom providers.
- For joined fields used in filters/sorting, use named bindings in the provider query and reference them with `assoc: {:binding_name, :field}` or filter fields like `{:binding_name, :field}`.
- Keep complex query construction in context modules. Keep LiveTable UI configuration in the LiveView.
- Render the table with `fields`, `filters`, `options`, and `streams`. Pass `actions` only when row actions exist.

## Standalone Schema Pattern

Use this for direct single-schema tables.

```elixir
defmodule MyAppWeb.ProductLive.Index do
  use MyAppWeb, :live_view
  use LiveTable.LiveResource, schema: MyApp.Products.Product

  alias LiveTable.{Boolean, Range}
  import Ecto.Query

  def fields do
    [
      id: %{label: "ID", sortable: true},
      name: %{label: "Name", sortable: true, searchable: true},
      price: %{label: "Price", sortable: true, renderer: &price_cell/1},
      in_stock: %{label: "In Stock"}
    ]
  end

  def filters do
    [
      price:
        Range.new(:price, "price", %{
          label: "Price",
          type: :number,
          min: 0,
          max: 100_000
        }),
      in_stock:
        Boolean.new(:in_stock, "in_stock", %{
          label: "In Stock",
          condition: dynamic([p], p.in_stock == true)
        })
    ]
  end

  def table_options do
    %{
      pagination: %{default_size: 25},
      sorting: %{default_sort: [name: :asc]},
      search: %{placeholder: "Search products..."}
    }
  end

  defp price_cell(price) do
    assigns = %{price: price}

    ~H"""
    <span class="font-mono"><%= @price %></span>
    """
  end
end
```

```heex
<.live_table
  fields={fields()}
  filters={filters()}
  options={@options}
  streams={@streams}
/>
```

## Custom Provider Pattern

Use this for joins, computed values, selected maps, or app-controlled base queries.

```elixir
defmodule MyAppWeb.ProductReportLive do
  use MyAppWeb, :live_view
  use LiveTable.LiveResource

  alias LiveTable.{Boolean, Select}
  import Ecto.Query

  def mount(_params, _session, socket) do
    {:ok, assign(socket, :data_provider, {MyApp.Products, :list_product_report_rows, []})}
  end

  def fields do
    [
      id: %{label: "ID", hidden: true},
      name: %{label: "Product", sortable: true, searchable: true},
      brand_name: %{label: "Brand", sortable: true, searchable: true, assoc: {:brand, :name}},
      category_name: %{label: "Category", assoc: {:category, :name}},
      margin: %{label: "Margin", sortable: true}
    ]
  end

  def filters do
    [
      category:
        Select.new({:category, :name}, "category", %{
          label: "Category",
          mode: :tags,
          options_source: {MyApp.Products, :search_categories, []}
        }),
      active:
        Boolean.new(:active, "active", %{
          label: "Active",
          condition: dynamic([p], p.active == true)
        })
    ]
  end
end
```

```elixir
defmodule MyApp.Products do
  import Ecto.Query

  alias MyApp.Products.{Product, Brand, Category}

  def list_product_report_rows do
    from p in Product,
      join: b in Brand,
      as: :brand,
      on: b.id == p.brand_id,
      join: c in Category,
      as: :category,
      on: c.id == p.category_id,
      select: %{
        id: p.id,
        name: p.name,
        brand_name: b.name,
        category_name: c.name,
        margin: (p.price - p.cost) / p.cost * 100
      }
  end
end
```

The keys in `fields/0` must match the selected keys: `:brand_name`, `:category_name`, `:margin`, etc.

## Transformers

Transformers are LiveTable's most powerful feature. Use them when a normal Boolean, Range, or Select filter is not enough.

Use transformers for:

- Custom business rules.
- User-controlled query clauses.
- Dynamic sorting modes.
- Rank/eligibility filters.
- Subqueries.
- Aggregations, `group_by`, and `having`.
- Complex date filtering.
- Queries that need to modify joins, ordering, or selected logic.

Define the transformer in `filters/0`:

```elixir
alias LiveTable.Transformer

def filters do
  [
    rank:
      Transformer.new("rank", %{
        label: "Rank",
        render: &rank_filter/1,
        query_transformer: &rank_filter_query/2
      })
  ]
end
```

Render any custom controls you need. The control must submit through LiveTable's `"sort"` event and place values under `filters[transformer_key]`.

```elixir
defp rank_filter(assigns) do
  ~H"""
  <div class="field">
    <label><%= @label %></label>
    <input
      type="number"
      name={"filters[#{@key}][value]"}
      value={@value["value"]}
      phx-debounce="300"
    />
  </div>
  """
end
```

The transformer receives the current Ecto query and the applied data map. It must always return a query.

```elixir
defp rank_filter_query(query, %{"value" => ""}), do: query

defp rank_filter_query(query, %{"value" => rank}) do
  rank = String.to_integer(rank)

  from [rank_cutoff: rc] in query,
    where: rc.closing_rank >= ^rank
end

defp rank_filter_query(query, _params), do: query
```

Transformer data is available from `@options["filters"]`:

```elixir
Map.get(@options["filters"], :rank).options.applied_data["value"]
```

For reusable transformers, use `{Module, :function}`:

```elixir
Transformer.new("eligibility", %{
  query_transformer: {MyApp.Admissions.Filters, :apply_eligibility}
})
```

## Custom Headers

Use `custom_header` when the default search/filter controls are not enough. This is the right place for domain-specific controls like rank input, category selects, sort mode selects, quick toggles, or grouped forms.

```elixir
def table_options do
  %{
    custom_header: {MyAppWeb.ProductLive.CustomHeader, :custom_header}
  }
end
```

Custom header controls should submit `phx-change="sort"` or `phx-click="sort"` and use names LiveTable understands:

```heex
<.form for={%{}} phx-change="sort" phx-debounce={@table_options.search.debounce}>
  <input type="text" name="search" value={@options["filters"]["search"]} />

  <select name="filters[sort_mode][sort_by]">
    <option value="Name">Name</option>
    <option value="NIRF Ranking">NIRF Ranking</option>
  </select>
</.form>
```

Do not create separate data-loading events for normal table controls. Let LiveTable update URL params and re-run the query.

## Fields

Common field options:

```elixir
name: %{
  label: "Name",
  sortable: true,
  searchable: true,
  hidden: false,
  renderer: &render_name/1,
  assoc: {:joined_binding, :field_name}
}
```

Use `renderer: &fun/1` for value-only rendering and `renderer: &fun/2` when the cell needs the whole record. Return HEEx from renderers.

Use `hidden: true` for fields needed in records but not displayed.

Use `assoc` only when the query has the matching named binding.

## Filters

Use normal filters for simple conditions.

Boolean:

```elixir
Boolean.new(:status, "active", %{
  label: "Active",
  condition: dynamic([p], p.status == "active")
})
```

Range:

```elixir
Range.new(:price, "price", %{
  label: "Price",
  type: :number,
  min: 0,
  max: 100_000,
  step: 1_000
})
```

Select:

```elixir
Select.new({:category, :name}, "category", %{
  label: "Category",
  mode: :tags,
  options_source: {MyApp.Products, :search_categories, []}
})
```

Use a transformer instead of forcing a normal filter when the condition requires subqueries, aggregation, or custom control over the final query.

## Card Mode

Use card mode when each record should render as a custom card instead of a table row.

```elixir
def table_options do
  %{
    mode: :card,
    card_component: &product_card/1,
    pagination: %{mode: :infinite_scroll, default_size: 20}
  }
end

defp product_card(assigns) do
  ~H"""
  <article>
    <h3><%= @record.name %></h3>
    <p><%= @record.category_name %></p>
  </article>
  """
end
```

## Actions

Use `actions/0` for row-level commands.

```elixir
def actions do
  %{
    label: "Actions",
    items: [
      view: &view_action/1,
      edit: &edit_action/1
    ]
  }
end

defp view_action(assigns) do
  ~H"""
  <button phx-click="view_product" phx-value-id={@record.id}>
    View
  </button>
  """
end
```

Handle the action event in the LiveView.

## Dynamic Providers

When a parent page control changes the base query arguments, update `:data_provider` and let LiveTable reload through its public LiveView flow. For ordinary search/filter/sort controls, prefer URL-param updates through `"sort"`.

```elixir
def handle_event("change_category", %{"seat_type" => seat_type}, socket) do
  provider = {MyApp.Programs, :list_colleges, [socket.assigns.program_id, seat_type]}
  current_path = "/" <> socket.assigns.current_path

  socket =
    socket
    |> assign(:data_provider, provider)
    |> push_patch(to: current_path)

  {:noreply, socket}
end
```

Do not reach for internal query helpers to reload data unless the library explicitly exposes a public API for that use case.

## Common Mistakes

- Using `schema:` and then also building a joined custom provider. For joined/custom queries, remove `schema:`.
- Returning lists from provider functions. Providers return queries.
- Using field keys that do not exist in the schema or selected map.
- Marking a joined field sortable/searchable without providing the right selected key and `assoc` metadata.
- Writing custom events that manually query and assign rows for normal table interactions.
- Calling `LiveTable.Sorting.sort`, `Sorting.sort`, `Paginate.paginate`, `Filter.apply_filters`, `list_resources`, `stream_resources`, or other internals directly.
- Assuming LiveTable builds arbitrary joins for standalone tables. For joined tables, the application owns the base query through a provider.
- Overusing transformers for simple boolean/range/select filters.
- Forgetting to render `options={@options}` and `streams={@streams}`.
- Forgetting `filters={filters()}` when the table defines filters.
- Forgetting `actions={actions()}` when row actions are defined.

## Minimal Checklist

Before finishing LiveTable code, verify:

- The LiveView uses `use LiveTable.LiveResource` correctly.
- Standalone schema tables have `schema: MyApp.Schema`.
- Custom/joined/computed tables assign `:data_provider`.
- Provider functions return Ecto queries.
- Field keys match the schema fields or selected map keys.
- Filters use public filter constructors: `Boolean.new`, `Range.new`, `Select.new`, `Transformer.new`.
- Transformers always return a query.
- The template renders `<.live_table fields={fields()} filters={filters()} options={@options} streams={@streams} />`.
- No internal LiveTable query/sort/pagination/helper functions are called from application code.
