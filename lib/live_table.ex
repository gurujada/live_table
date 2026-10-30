defmodule LiveTable do
  @moduledoc """
  Phoenix LiveView component library for building dynamic, interactive data tables.

  LiveTable provides sorting, filtering, pagination, and exports for Phoenix LiveView
  applications. It supports both simple single-schema tables and complex queries with
  joins, aggregations, and computed fields.

  ## Getting Started

  ```bash
  # Add to mix.exs: {:live_table, "~> #{Mix.Project.config()[:version]}"}
  mix deps.get
  mix live_table.install
  ```

  See the [Installation Guide](installation.html) and [Quick Start](quick-start.html).

  ## Key Modules

  - `use LiveTable.LiveResource` - Main entry point for creating tables
  - `LiveTable.Boolean`, `LiveTable.Range`, `LiveTable.Select` - Filter types
  - `LiveTable.Transformer` - Advanced query transformations (most powerful feature)

  ## Documentation

  - [Overview](overview.html) - Architecture and concepts
  - [Fields API](fields.html) - Field configuration options
  - [Filters API](filters.html) - Filter types and usage
  - [Transformers](transformers.html) - Advanced query control
  - [Table Options](table-options.html) - Pagination, exports, debug mode
  - [Examples](simple-table.html) - Real-world usage patterns
  - [Live Rows](live-rows.html) - Update open tables when data changes
  - [Bulk Actions](bulk-actions.html) - Act on selected rows
  """

  @doc """
  Keeps the table up to date with changes broadcast on `topic`. Call it in `mount/3`:

      def mount(_params, _session, socket) do
        {:ok, LiveTable.subscribe(socket, MyApp.PubSub, "products")}
      end

  On each `broadcast/3` to the topic, the table re-runs its current query. Other messages still
  reach your `handle_info/2`.
  """
  def subscribe(socket, pubsub, topic) do
    if Phoenix.LiveView.connected?(socket), do: Phoenix.PubSub.subscribe(pubsub, topic)

    Phoenix.LiveView.attach_hook(socket, :live_table, :handle_info, fn
      {LiveTable, :changed, _ids}, socket ->
        {:halt, socket.view.__live_table_refresh__(socket)}

      _message, socket ->
        {:cont, socket}
    end)
  end

  @doc """
  Tells the tables subscribed to `topic` that the rows with these primary keys were created,
  updated or deleted. Send one broadcast for a batch of changes, not one per row:

      LiveTable.broadcast(MyApp.PubSub, "products", [product.id])

  Only the ids are sent; each table re-reads the rows through its own query and filters.
  For a composite primary key, pass each id as a list of its values in key order.
  """
  def broadcast(pubsub, topic, ids) do
    Phoenix.PubSub.broadcast(pubsub, topic, {LiveTable, :changed, List.wrap(ids)})
  end
end
