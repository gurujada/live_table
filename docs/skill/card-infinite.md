# Card Mode And Infinite Scroll

Use this when records should render as cards or when the user asks for infinite scroll.

## Card Mode

Configure cards through `table_options/0`:

```elixir
def table_options do
  %{
    mode: :card,
    card_component: &project_card/1,
    pagination: %{default_size: 12}
  }
end
```

The card component receives `%{record: record}`:

```elixir
defp project_card(assigns) do
  ~H"""
  <article class="rounded-lg border p-4">
    <h3 class="font-semibold"><%= @record.name %></h3>
    <p><%= @record.client_name %></p>
  </article>
  """
end
```

The selected record must contain every field the card reads:

```elixir
def list_project_rows do
  from p in Project,
    join: c in assoc(p, :client),
    as: :client,
    select: %{
      id: p.id,
      name: p.name,
      status: p.status,
      client_name: c.name
    }
end
```

## Infinite Scroll

Enable infinite scroll through pagination options:

```elixir
def table_options do
  %{
    mode: :card,
    card_component: &project_card/1,
    pagination: %{
      mode: :infinite_scroll,
      sizes: [12, 24, 48],
      default_size: 12,
      loading_component: &loading_spinner/1
    },
    sorting: %{default_sort: [inserted_at: :desc]}
  }
end
```

Do not write your own `handle_event("load_more", ...)`. LiveTable's generated code and component already wire `phx-viewport-bottom` and the internal load-more behavior for infinite scroll.

## Fields Still Matter In Card Mode

Even when no table columns are visible, `fields/0` should describe the searchable/sortable/filterable data:

```elixir
def fields do
  [
    id: %{label: "ID", hidden: true},
    name: %{label: "Project", sortable: true, searchable: true},
    client_name: %{label: "Client", sortable: true, searchable: true, assoc: {:client, :name}},
    status: %{label: "Status"}
  ]
end
```

Use hidden fields when records need data for cards but the table/card controls should not display a column.

## Custom Loading UI

LiveTable supports a custom infinite-scroll loading component through pagination options:

```elixir
def table_options do
  %{
    mode: :card,
    card_component: &project_card/1,
    pagination: %{
      mode: :infinite_scroll,
      default_size: 12,
      loading_component: &loading_spinner/1
    }
  }
end
```

Keep the loading component presentational. Do not move data fetching into it.
