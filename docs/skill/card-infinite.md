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

## Audit Trails And Activity Feeds

Use card mode with infinite scroll when records are naturally consumed as a descending timeline:

```elixir
defmodule MyAppWeb.AuditLogLive.Index do
  use MyAppWeb, :live_view
  use LiveTable.LiveResource

  alias LiveTable.{Boolean, Select, Transformer}
  import Ecto.Query

  def mount(_params, _session, socket) do
    {:ok, assign(socket, :data_provider, {MyApp.Audit, :list_events, []})}
  end

  def fields do
    [
      id: %{label: "ID", hidden: true},
      actor_name: %{label: "Actor", searchable: true, assoc: {:actor, :name}},
      action: %{label: "Action", searchable: true},
      resource_type: %{label: "Resource", searchable: true},
      severity: %{label: "Severity"},
      inserted_at: %{label: "Time", sortable: true}
    ]
  end

  def filters do
    [
      severity:
        Select.new(:severity, "severity", %{
          label: "Severity",
          mode: :tags,
          options: [
            %{label: "Info", value: "info"},
            %{label: "Warning", value: "warning"},
            %{label: "Critical", value: "critical"}
          ]
        }),
      failed_only:
        Boolean.new(:success, "failed", %{
          label: "Failed only",
          condition: dynamic([e], e.success == false)
        }),
      window:
        Transformer.new("window", %{
          query_transformer: &MyApp.Audit.filter_window/2
        })
    ]
  end

  def table_options do
    %{
      mode: :card,
      card_component: &audit_event_card/1,
      pagination: %{mode: :infinite_scroll, default_size: 25},
      sorting: %{default_sort: [inserted_at: :desc]},
      search: %{placeholder: "Search audit events..."}
    }
  end
end
```

Provider:

```elixir
def list_events do
  from e in AuditEvent,
    join: a in assoc(e, :actor),
    as: :actor,
    select: %{
      id: e.id,
      actor_name: a.name,
      action: e.action,
      resource_type: e.resource_type,
      severity: e.severity,
      success: e.success,
      metadata: e.metadata,
      inserted_at: e.inserted_at
    }
end
```

Keep the feed query stable. Use filters or transformers for event windows, severity, actor, resource, and permission-aware scoping. Do not implement a custom `load_more` handler.

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
