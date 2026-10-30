# Bulk Actions

Bulk actions let users select rows and act on them together: archive, delete, mark as paid.

## Setup

Define `bulk_actions/0` in your LiveView:

```elixir
def bulk_actions do
  [
    archive: %{
      label: "Archive",
      confirm: "Archive the selected products?",
      handler: &__MODULE__.archive/2
    }
  ]
end

def archive(query, socket) do
  MyApp.Repo.update_all(query, set: [archived: true])
  put_flash(socket, :info, "Archived.")
end
```

And pass them to the table:

```heex
<.live_table
  fields={fields()}
  filters={filters()}
  options={@options}
  streams={@streams}
  bulk_actions={bulk_actions()}
/>
```

Each action takes:

- `label` - the button text
- `handler` - a function of `(query, socket)` that returns the socket
- `confirm` - optional; the question asked before the action runs

## What users see

- A checkbox on each row, and one in the header that selects the page.
- Once rows are selected, a bar above the table: "2 selected", a button per action, and Clear.
- When the whole page is selected and there are more rows, "Select all matching" selects every
  row that matches the current filters and search, not just the page.

Without `bulk_actions`, none of this is shown.

Selecting happens in the browser: ticking rows sends nothing to the server and re-renders nothing.
Only clicking an action sends the chosen row ids, or "all matching", to the server. Ticks survive
[live rows](live-rows.md) updates; changing filters, search, sort or page clears them, so an action
only ever runs on rows the user saw selected. After an action runs, the selection clears and the
table reloads.

## Cards

In card mode, your card draws its own checkbox, styled however you like. Give it the
`data-live-table-select` attribute and the card's `@row_id` as its value:

```elixir
def product_card(assigns) do
  ~H"""
  <label class="card has-[:checked]:ring-2 has-[:checked]:ring-primary">
    <input type="checkbox" class="sr-only" data-live-table-select value={@row_id} />
    {@record.name}
  </label>
  """
end
```

Wrapping the card in a `<label>` makes the whole card toggle the checkbox, and CSS `:has(:checked)`
styles the selected card. Cards have no header, so the bar offers "Select page" instead.

`confirm` renders a `data-confirm` attribute, which `phoenix_html` (included in new Phoenix apps)
shows as the browser's confirm dialog.

## The query

The handler gets an `Ecto.Query` for the chosen rows, so `Repo.update_all/3` and
`Repo.delete_all/2` work directly:

```elixir
def delete(query, socket) do
  {count, _} = MyApp.Repo.delete_all(query)
  put_flash(socket, :info, "Deleted #{count} products.")
end
```

It's a plain query on the table's root schema, with the table's filters, search and data provider
applied. That holds whether the user picked rows or selected all matching, and even when your data
provider joins, groups or selects. Rows outside the table's query can't be selected, so a forged
id does nothing.

To act on the records one by one, load them: `MyApp.Repo.all(query)`.

If the table uses [live rows](live-rows.md), broadcast the change from the handler so other open
tables update too.

## Requirements

A single-column primary key. Bulk actions work in table and card mode, with or without streams.
