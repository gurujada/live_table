defmodule LiveTable do
  @moduledoc """
  Phoenix LiveView component library for building dynamic, interactive data tables.

  LiveTable provides sorting, filtering, pagination, and exports for Phoenix LiveView
  applications. It supports both simple single-schema tables and complex queries with
  joins, aggregations, and computed fields.

  ## Getting Started

  ```bash
  # Add to mix.exs: {:live_table, "~> 0.3.1"}
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
  """
end
