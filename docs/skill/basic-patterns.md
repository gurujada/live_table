# Basic Patterns

Use this for schema-backed tables, joined/custom provider tables, fields, actions, renderers, fixed headers, and exports.

## Schema-Backed Table

Use this when the table is a direct query over one schema.

```elixir
defmodule MyAppWeb.ContactLive.Index do
  use MyAppWeb, :live_view
  use LiveTable.LiveResource, schema: MyApp.Contacts.Contact

  alias LiveTable.Boolean
  import Ecto.Query

  def fields do
    [
      id: %{label: "ID", hidden: true},
      name: %{label: "Name", sortable: true, searchable: true},
      email: %{label: "Email", searchable: true},
      active: %{label: "Active"}
    ]
  end

  def filters do
    [
      active:
        Boolean.new(:active, "active", %{
          label: "Active",
          condition: dynamic([c], c.active == true)
        })
    ]
  end

  def table_options do
    %{
      pagination: %{sizes: [10, 25, 50], default_size: 25},
      sorting: %{default_sort: [name: :asc]},
      search: %{placeholder: "Search contacts..."}
    }
  end
end
```

## Joined Provider Table

Use this when rows need joins, computed fields, selected maps, or app-specific base conditions.

```elixir
defmodule MyAppWeb.InvoiceLive.Index do
  use MyAppWeb, :live_view
  use LiveTable.LiveResource

  alias LiveTable.{Boolean, Range}
  import Ecto.Query

  def mount(_params, _session, socket) do
    {:ok, assign(socket, :data_provider, {MyApp.Billing, :list_invoice_rows, []})}
  end

  def fields do
    [
      id: %{label: "ID", hidden: true},
      invoice_number: %{label: "Invoice #", sortable: true, searchable: true},
      customer_name: %{label: "Customer", sortable: true, searchable: true, assoc: {:customer, :name}},
      total: %{label: "Total", sortable: true, renderer: &money_cell/1},
      status: %{label: "Status"}
    ]
  end

  def filters do
    [
      amount:
        Range.new(:amount, "amount", %{
          label: "Amount",
          min: 0,
          max: 500_000,
          step: 5_000
        }),
      paid:
        Boolean.new(:status, "paid", %{
          label: "Paid",
          condition: dynamic([i], i.status == "paid")
        })
    ]
  end

  def table_options do
    %{
      pagination: %{default_size: 50},
      sorting: %{default_sort: [inserted_at: :desc]},
      fixed_header: true
    }
  end

  defp money_cell(amount) do
    assigns = %{amount: amount}

    ~H"""
    <span class="font-mono"><%= @amount %></span>
    """
  end
end
```

Provider:

```elixir
defmodule MyApp.Billing do
  import Ecto.Query

  def list_invoice_rows do
    from i in MyApp.Billing.Invoice,
      join: c in assoc(i, :customer),
      as: :customer,
      select: %{
        id: i.id,
        invoice_number: i.invoice_number,
        amount: i.amount,
        total: i.amount + coalesce(i.tax_amount, 0),
        status: i.status,
        customer_name: c.name,
        inserted_at: i.inserted_at
      }
  end
end
```

## Render Contract

```heex
<.live_table
  fields={fields()}
  filters={filters()}
  options={@options}
  streams={@streams}
/>
```

Add `actions={actions()}` only when `actions/0` returns row actions.

## Fields

Field keys must match the data source:

- Schema table: keys are schema fields.
- Provider table: keys are selected map keys.
- Card mode: fields can be hidden but should still describe searchable/sortable/filterable selected data.

Common options:

```elixir
name: %{
  label: "Name",
  sortable: true,
  searchable: true,
  hidden: false,
  renderer: &render_name/1,
  component: &name_component/1,
  empty_text: "N/A",
  computed: dynamic([r], fragment("? * ?", r.price, r.quantity)),
  assoc: {:joined_binding, :field_name}
}
```

Use `assoc` only when the provider query has the matching named binding. Use `renderer/1` for value-only formatting, `renderer/2` when the full record is needed, `component/1` for `%{value: value, record: record}` assigns, and `component/2` for `(value, record)`.

For schema-backed tables, `computed` values are included in LiveTable's generated select. For provider tables, select the computed value in the provider query; use `computed` only when LiveTable needs the expression for sorting.

## Actions

Actions render row-level controls. Handle their events in the LiveView.

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
  <button phx-click="view_invoice" phx-value-id={@record.id}>
    View
  </button>
  """
end

def handle_event("view_invoice", %{"id" => id}, socket) do
  {:noreply, push_navigate(socket, to: ~p"/invoices/#{id}")}
end
```

## Exports

Configure exports through `table_options/0`; do not implement export queries manually unless the app needs separate non-LiveTable export behavior.

```elixir
def table_options do
  %{
    exports: %{enabled: true, formats: [:csv, :pdf]},
    pagination: %{default_size: 50}
  }
end
```

See `docs/skill/table-options.md` for export setup requirements.
