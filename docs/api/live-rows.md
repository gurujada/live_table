# Live Rows

A table shows the rows as they were when the page loaded. Live rows keep it up to date when
someone else, or a background job, creates, updates or deletes rows: every open table showing
that data refreshes without a reload.

## Setup

Subscribe the table in your LiveView's `mount/3`:

```elixir
def mount(_params, _session, socket) do
  {:ok, LiveTable.subscribe(socket, MyApp.PubSub, "products")}
end
```

Broadcast the primary keys of the rows you changed, wherever you change them:

```elixir
def update_product(product, attrs) do
  with {:ok, product} <- product |> Product.changeset(attrs) |> Repo.update() do
    LiveTable.broadcast(MyApp.PubSub, "products", [product.id])
    {:ok, product}
  end
end
```

Use the same call for created, updated and deleted rows.

## What happens on a broadcast

Each subscribed table re-runs its current query, with its own filters, search, sort and page, and
updates what changed:

- A new row appears in its sorted place.
- An updated row changes in place, or leaves the page if it now sorts or filters elsewhere.
- A deleted row disappears.

With infinite scroll, every page loaded so far is refreshed.

Only what changed is sent to the browser: the rows whose ids you broadcast, a new row at its
position, and the removal of a row that left. So a new row at the top of a feed costs one row,
however far the user has scrolled. Only when rows swap places, say after an edit to the sorted
column, is the whole page sent again. There is nothing to configure.

Only ids are broadcast. Each table reads the rows through its own query, so a viewer never
receives a row their filters or scoping exclude.

## Topics

Use the narrowest topic that covers the data, so only tables showing it refresh:

```elixir
LiveTable.subscribe(socket, MyApp.PubSub, "org:#{org.id}:products")
```

## Many rows at once

Each broadcast costs every subscribed table one query, the one it runs when the user changes page.
When an import or bulk update changes many rows, send one broadcast with all their ids, not one per
row:

```elixir
LiveTable.broadcast(MyApp.PubSub, "products", Enum.map(products, & &1.id))
```

## Notes

- Your own `handle_info/2` still receives every other message.
- `subscribe/3` only subscribes once the LiveView is connected, so the static render doesn't.
- For a composite primary key, pass each id as a list of its values in key order.
