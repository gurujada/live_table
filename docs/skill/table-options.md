# Table Options

Use this for `table_options/0`, app defaults, display modes, pagination, sorting, search, exports, debug, fixed headers, streams, max filters, and empty states.

## Configuration Levels

LiveTable merges built-in defaults, application config, and per-table overrides:

```elixir
config :live_table,
  repo: MyApp.Repo,
  pubsub: MyApp.PubSub,
  app: :my_app,
  defaults: %{
    pagination: %{sizes: [10, 25, 50], default_size: 25},
    search: %{debounce: 300}
  }
```

Per-table overrides live in `table_options/0`:

```elixir
def table_options do
  %{
    pagination: %{enabled: true, sizes: [10, 25, 50], default_size: 25, max_per_page: 50},
    sorting: %{enabled: true, default_sort: [name: :asc]},
    search: %{enabled: true, debounce: 300, placeholder: "Search...", mode: :auto},
    exports: %{enabled: true, formats: [:csv, :pdf]},
    mode: :table,
    use_streams: true,
    fixed_header: false,
    max_filters: 3,
    debug: :off
  }
end
```

## Pagination

```elixir
pagination: %{
  enabled: true,
  mode: :buttons,
  sizes: [10, 25, 50],
  default_size: 25,
  max_per_page: 50
}
```

- `enabled: false` shows all rows from the query.
- `mode: :buttons` is the normal Previous/Next footer.
- `mode: :infinite_scroll` is for card mode only; see `docs/skill/card-infinite.md`.
- `max_per_page` caps URL-manipulated page sizes.

## Sorting

```elixir
sorting: %{enabled: true, default_sort: [inserted_at: :desc]}
```

Column sorting requires `sortable: true` on fields. Shift-click multi-sort is built into the component.

## Search

```elixir
search: %{
  enabled: true,
  debounce: 300,
  placeholder: "Search records...",
  mode: :auto
}
```

Search modes:

- `:auto` picks `:ilike` on PostgreSQL and `:like_lower` elsewhere.
- `:ilike` forces PostgreSQL ILIKE.
- `:like_lower` uses portable `lower()` comparisons.

Only fields marked `searchable: true` are included.

## Display And Scroll Behavior

```elixir
mode: :table
fixed_header: true
```

- `mode: :table` renders a full-width table layout.
- `mode: :card` requires `card_component: &component/1`.
- Table mode is full width by default.
- `fixed_header: true` adds a `max-h-[600px]` vertical scroll area and makes the table header sticky.
- There is no separate fixed-width or horizontal-scroll option in the current implementation.

## Streams

```elixir
use_streams: true
```

- `true` uses Phoenix streams and the template should pass `streams={@streams}`.
- `false` uses regular assigns and the template should pass `streams={@resources}`.

## Filters Display

```elixir
max_filters: 3
```

If the number of filters is greater than `max_filters`, the filter area starts hidden behind the Show Filters toggle.

## Empty State

```elixir
empty_state: &empty_state/1
```

The callback receives assigns and should render presentational HEEx. Do not query from the empty state component.

## Debug

```elixir
debug: :off
```

Supported values:

- `:off`
- `:query`
- `:trace`

Debug output is for development; do not enable query tracing in production.

## Exports

```elixir
exports: %{enabled: true, formats: [:csv, :pdf]}
```

CSV/PDF exports require LiveTable export setup: `repo`, `pubsub`, and `app` config; Oban running an `exports` queue; static serving for `exports`; and Typst installed for PDF.
