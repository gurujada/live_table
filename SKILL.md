---
name: livetable
description: Use when building, modifying, or reviewing Phoenix LiveView tables with LiveTable, including schema-backed tables, context-owned data providers, joined queries, filters, transformers, card mode, infinite scroll, custom headers, custom controls, custom content, actions, exports, and query behavior. Use this to avoid hallucinated LiveTable APIs and to stay on LiveTable's public authoring surface.
---

# LiveTable

LiveTable is a Phoenix LiveView table/card library. Use it from a LiveView with `use LiveTable.LiveResource` and render the generated `<.live_table />` component.

## Public Surface

Use these from application code:

- `use LiveTable.LiveResource, schema: MyApp.Schema` for direct single-schema tables.
- `use LiveTable.LiveResource` plus `assign(:data_provider, {Module, :function, args})` for joined/custom/computed queries.
- `fields/0`, `filters/0`, `actions/0`, and `table_options/0` in the LiveView.
- `<.live_table fields={fields()} filters={filters()} options={@options} streams={@streams} />`.
- `actions={actions()}` only when row actions exist.
- Filter constructors: `LiveTable.Boolean.new/3`, `LiveTable.Range.new/3`, `LiveTable.Select.new/3`, `LiveTable.Transformer.new/2`.

Do not call LiveTable internals from application code:

- Do not call `stream_resources`, `list_resources`, `fetch_resources`, `assign_to_socket`, or generated private helpers.
- Do not call `LiveTable.Sorting`, `LiveTable.Paginate`, `LiveTable.Filter`, `LiveTable.Join`, `LiveTable.TableConfig`, parser helpers, sort helpers, or filter helpers directly.
- Do not invent APIs such as `LiveTable.query/2`, `LiveTable.render/1`, `LiveTable.load/2`, or `LiveTable.Sorting.sort/3`.
- Do not manually query/assign rows for ordinary search, filter, sort, page, or load-more behavior.

## Load The Relevant Reference

- For API boundaries and review checklists, read `docs/skill/public-api.md`.
- For schema-backed tables, joined providers, fields, actions, renderers, fixed headers, and exports, read `docs/skill/basic-patterns.md`.
- For pagination, sorting, search, exports, debug, fixed headers, streams, max filters, empty state, and display modes, read `docs/skill/table-options.md`.
- For `Boolean`, `Range`, `Select`, and `Transformer` details, read `docs/skill/filters-transformers.md`.
- For custom headers, domain controls, custom controls/content/footer, and transformer-backed UI state, read `docs/skill/custom-ui.md`.
- For context-owned joined queries, provider arguments, tenants/current-user/parent-id cases, and dynamic provider decisions, read `docs/skill/providers.md`.
- For card mode and infinite scroll, read `docs/skill/card-infinite.md`.

## Core Rules

- Field keys must match schema fields for schema-backed tables.
- Field keys must match selected map keys for provider-backed tables.
- Provider functions must return Ecto queries, not lists. LiveTable owns query execution.
- Use named bindings (`as: :customer`) when fields or filters reference joined tables with `assoc: {:customer, :name}`.
- Use ordinary filters for simple field conditions.
- Use `Transformer.new/2` for query-shaping behavior: rank/eligibility logic, dynamic sort modes, subqueries, aggregations, `group_by`, `having`, date windows, or app-specific query branches.
- Custom header controls should submit LiveTable-compatible params to the `"sort"` event.
- Infinite scroll is configured through `table_options/0`; do not implement a custom `load_more` event.
- Table mode renders full width by default. `fixed_header: true` adds a bounded vertical scroll area and sticky table header; there is no separate fixed-width or horizontal-scroll option.
- Treat direct calls to generated helpers such as `stream_resources/3` as legacy/app-specific code, not as a pattern to copy.

## Minimal Shape

```elixir
defmodule MyAppWeb.ProductLive.Index do
  use MyAppWeb, :live_view
  use LiveTable.LiveResource, schema: MyApp.Catalog.Product

  def fields do
    [
      id: %{label: "ID", hidden: true},
      name: %{label: "Name", sortable: true, searchable: true},
      price: %{label: "Price", sortable: true}
    ]
  end

  def filters, do: []
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

## Common Mistakes

- Using `schema:` and a joined custom provider together.
- Returning lists from provider functions.
- Using field keys that do not exist in the schema or selected map.
- Marking joined fields sortable/searchable/filterable without matching selected keys and `assoc` metadata.
- Calling internal query/sort/pagination/helper modules directly.
- Copying `stream_resources/3` refresh code from an app instead of using public LiveTable flow.
- Writing custom events that manually query and assign rows for normal table interactions.
- Overusing transformers for simple boolean/range/select filters.
- Using custom header controls with arbitrary param names instead of LiveTable param names.
- Implementing infinite scroll manually.
- Forgetting `options={@options}` or `streams={@streams}`.
- Forgetting `actions={actions()}` when actions exist.
