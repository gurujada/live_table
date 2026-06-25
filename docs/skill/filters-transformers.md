# Filters And Transformers

Use this for constructing `Boolean`, `Range`, `Select`, and `Transformer` filters.

## Boolean

Use for checkbox/toggle filters that apply a fixed Ecto condition.

```elixir
alias LiveTable.Boolean
import Ecto.Query

Boolean.new(:active, "active", %{
  label: "Active",
  condition: dynamic([p], p.active == true),
  default: false,
  class: ""
})
```

The first argument is the field or joined field. The second argument is the URL/filter key.

For joined data, align the dynamic bindings with the query:

```elixir
Boolean.new({:supplier, :active}, "active_supplier", %{
  label: "Active Supplier",
  condition: dynamic([product: p, supplier: s], s.active == true)
})
```

## Range

Use for numeric ranges.

```elixir
alias LiveTable.Range

Range.new(:price, "price", %{
  label: "Price",
  min: 0,
  max: 100_000,
  step: 1_000,
  default_min: 0,
  default_max: 100_000,
  unit: "$",
  pips: true,
  pips_mode: "positions",
  pips_values: [0, 25, 50, 75, 100],
  css_classes: "",
  slider_classes: "w-full h-2 mt-6 mb-8",
  label_classes: "block text-sm font-medium leading-6 text-foreground"
})
```

Use a transformer for custom date logic or non-numeric domain-specific ranges.

## Select

Use for single or multi-select filters.

```elixir
alias LiveTable.Select

Select.new({:category, :name}, "category", %{
  label: "Category",
  mode: :tags,
  options_source: {MyApp.Catalog, :search_categories, []},
  option_template: &option_template/1,
  placeholder: "Search...",
  allow_clear: false,
  max_selectable: 0,
  user_defined_options: false,
  debounce: 100
})
```

Selection modes:

- `:single`
- `:tags`
- `:quick_tags`

Static options are also valid:

```elixir
Select.new(:status, "status", %{
  label: "Status",
  mode: :single,
  allow_clear: true,
  options: [
    %{label: "Active", value: "active"},
    %{label: "Archived", value: "archived"}
  ]
})
```

Dynamic `options_source` callbacks receive the typed search text as the first argument and return options:

```elixir
def search_categories(text) do
  Category
  |> where([c], ilike(c.name, ^"%#{text}%"))
  |> select([c], {c.name, c.id})
  |> limit(10)
  |> Repo.all()
end
```

For options that return a list value, put the primary key first:

```elixir
{label, [id, extra_info]}
```

Do not return row data from `options_source`; it is only for select options.

Do not add undocumented Select options; stick to the options listed here and in the module docs.

## Transformer

Use when a control must modify the full query.

```elixir
alias LiveTable.Transformer

Transformer.new("eligibility", %{
  query_transformer: &apply_eligibility/2
})
```

The callback receives `(query, applied_data)` and must return a query:

```elixir
def apply_eligibility(query, %{"rank" => ""}), do: query

def apply_eligibility(query, %{"rank" => rank}) do
  rank = String.to_integer(rank)

  from [rank_cutoff: rc] in query,
    where: rc.closing_rank >= ^rank
end

def apply_eligibility(query, _params), do: query
```

Use transformers for:

- subqueries
- aggregations
- `group_by`/`having`
- rank/eligibility business rules
- custom sort modes
- custom date ranges
- replacing or extending `order_by`

## Dynamic Sort Modes

Use a transformer to override ordering from a custom selector:

```elixir
def sort_query(query, %{"sort_by" => "NIRF Ranking"}) do
  query
  |> exclude(:order_by)
  |> order_by([nirf: nr], asc: nr.nirf_rank)
end

def sort_query(query, %{"sort_by" => "Name (A-Z)"}) do
  query
  |> exclude(:order_by)
  |> order_by([college: c], asc: c.name)
end

def sort_query(query, _params), do: query
```

Prefer named bindings when the provider query declares them.
