# Changelog

All notable changes to LiveTable will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `:sutra_ui` is now truly optional. LiveTable renders its controls and filters through a components module (`LiveTable.Components`). With Sutra UI installed it uses `LiveTable.Components.Sutra` with no configuration; without it, set `config :live_table, components: MyAppWeb.TableComponents`. See the Custom Components guide. ([#34](https://github.com/gurujada/live_table/issues/34))
- `use LiveTable.Components.Sutra` to override individual components and keep Sutra UI for the rest.
- `mix live_table.install` adds `:sutra_ui`. Run `mix sutra_ui.install` afterwards, or remove it to use your own components.
- `<.live_table>` accepts a `nonce` assign (default `nil`). It is set on LiveTable's inline `.Download` and `.SortableColumn` hook scripts and passed to the components module, so a nonce-based `script-src` Content-Security-Policy works without `'unsafe-inline'`.
- `<.live_table>` accepts an `id` assign (default `"live-table"`), so several tables can share a page. Every DOM id the table renders derives from it; the default id keeps today's ids.

### Changed

- **Breaking: exports no longer use Oban or `priv/static`.** The export button sends the browser a download link with the export's query encrypted in it, valid for 60 seconds, and `LiveTable.ExportPlug` streams the file back. Nothing is stored, so exports work on any node and in releases with a read-only `priv`. To upgrade:
  - Add `forward "/live_table/exports", LiveTable.ExportPlug` to your router, outside the `:browser` pipeline. `mix live_table.install` adds it.
  - Remove `"exports"` from `static_paths` and delete `priv/static/exports`.
  - Remove `app:` and `pubsub:` from `config :live_table`.
- A PDF export shows "Preparing your PDF. The download will start shortly." while it is built.
- **PDF exports use the [`typst`](https://hex.pm/packages/typst) package instead of the `typst` CLI.** It's an optional dependency that ships precompiled, so servers need nothing installed; `mix live_table.install` adds it. Without it the PDF option is hidden. `config :live_table, pdf_font_dirs: [...]` adds fonts for scripts the bundled fonts don't cover.
- `:jason` is no longer a dependency (LiveTable uses Elixir's built-in `JSON`), and `:postgrex` and `:ecto_sql` are only used for LiveTable's own tests.
- LiveTable no longer starts an application of its own or ships its test repo.
- The filter bar no longer uses Sutra UI's `filter-bar` classes, which are deprecated in Sutra UI 0.5 and removed in 0.6.
- `mix live_table.install` adds `@source "../../deps/live_table/lib";` to `assets/css/app.css`. Without it, Tailwind skips classes used only in LiveTable's markup. Existing apps should add the line.
- LiveTable no longer depends on `:oban` or `:oban_web`, and `mix live_table.install` no longer has an `--oban` option.
- Select filter markup uses Sutra UI tokens (`text-foreground`, `text-muted-foreground`) instead of fixed `gray` classes, so dark mode follows the theme.
- Custom export controls now use the `"export"` event with a `format` value instead of `"export-csv"` or `"export-pdf"`.

### Fixed

- LiveTable compiles without `:sutra_ui`. Without it and without a components module, compilation fails with instructions instead of an undefined-module error. ([#34](https://github.com/gurujada/live_table/issues/34))
- Blank or non-numeric range filter bounds fall back to the range defaults instead of crashing the LiveView.
- Export queries preserve pinned values and filters instead of being reconstructed from their printed representation.
- Unsupported export formats raise an error instead of exporting a PDF.
- Export files were publicly readable under a guessable name in `priv/static/exports`, and stayed there if the LiveView died before cleanup.
- The `export` event is ignored when exports are disabled or the format isn't in the table's `formats`.
- CSV text cells starting with `=`, `+`, `-`, `@`, a tab or a carriage return get a leading `'`, so spreadsheet apps don't run them as formulas.
- PDF cell values are passed to Typst as text. Before, a value could be read as Typst markup or code. Each PDF is built in its own temporary directory, which is removed afterwards.
- A failed PDF compile returns an error response and is logged, instead of crashing the export job.
- Transformer data with `min`/`max` or `id` keys no longer crashes: URL filters are parsed by the filter's type, not by the value's shape.
- A Transformer without a `render:` function renders nothing in the filter bar instead of crashing.
- Search matches `%`, `_` and `!` literally instead of treating `%` and `_` as wildcards.
- On PostgreSQL a non-text column, such as a number, can be `searchable`. Before, it raised an `ILIKE` operator error. Trigram indexes on text columns are still used.
- Filter keys in the URL or in events no longer create atoms. Keys that aren't in `filters/0`, and values whose shape doesn't match the filter type, are ignored instead of crashing the LiveView.
- Unknown sort fields or directions in the URL are ignored instead of crashing the LiveView. A non-numeric `per_page` falls back to the default size instead of the maximum.
- Restoring a `Select` filter from the URL and clearing filters now target the LiveSelect component by the filter's name, so they also work when the filter's key differs from its name.

## [0.4.2] - 2026-07-07

### Changed

- Updated installation snippets and package metadata for the 0.4.2 release.
- Updated the optional SutraUI dependency to `~> 0.4.0`.
- Refined LiveTable's agent-facing docs and skill files to keep examples on the public authoring API.
- Improved optional Igniter guidance for `mix live_table.install` and `mix live_table.gen.live`.

### Fixed

- Fixed streamed card container rendering in card mode.
- Kept infinite-scroll load-more paging from leaking into canonical table URL state.
- Added a stable id to the built-in controls form to avoid Phoenix LiveView form recovery warnings.
- Corrected docs that implied non-public events, stale `handle_params/3` ownership, invalid `@impl LiveTable.LiveResource` annotations, or outdated debug configuration.

### Testing

- Added LiveView integration coverage for LiveResource behavior.

## [0.4.1] - 2026-03-06

### Added

- **Filter limits**: Added `table_options.filters.max_filters` to cap how many filters can be active at once.
- **Pagination config**: Added `pagination.max_per_page` support for safer per-page bounds.
- **Search compatibility**: Added configurable text search mode for database compatibility (including SQLite-safe behavior).
- **Internal helper modules**: Split helper logic into focused modules (`FilterHelpers`, `ParseHelpers`, `LiveSelectHelpers`, `LiveViewHelpers`, `SortHelpers`, `ExportHelpers`) with dedicated tests.

### Changed

- Updated `sutra_ui` dependency from `~> 0.2.0` to `~> 0.3.0`.
- Updated installation/version snippets from `0.4.0` to `0.4.1` in docs and usage rules.
- Made `igniter` optional in dependency setup.
- Refined text search implementation after introducing configurable modes to reduce unnecessary complexity.

### Fixed

- Fixed Select filters for non-ID fields so filtering by string fields works correctly.
- Fixed Select/LiveSelect parsing for structured payloads where option values are nested lists (for example `[["1"]]`), preventing false "0 records" results.
- Fixed structured single-select value mapping so string payloads (for example `"open"`) are normalized back to typed option values (for example `:open`) before query filtering.

## [0.4.0] - 2024-12-15

### Breaking Changes

- **Removed bundled JS/CSS assets** - LiveTable no longer ships with pre-bundled JavaScript and CSS files. Hooks are now colocated using Phoenix's runtime hooks feature. Run `mix compile` before `mix assets.deploy`.
- **Removed date/datetime range filters** - Range filters now only support numeric values. Date/datetime range functionality has been removed.
- **Actions refactored** - Actions are now passed via the `actions` assign instead of as a field. Update your templates accordingly.
- **Required `:app` config** - Exports now require the `:app` configuration to be set in your LiveTable config.
- **Sortable defaults to `false`** - Fields no longer require sortable: false to be set. Explicitly set `sortable: true` on fields that should be sortable.

### Added

- **Mix generators** - Added `mix live_table.install` for automatic setup and `mix live_table.gen.live` for scaffolding LiveViews with LiveTable.
- **Infinite scroll** - Added `pagination: :infinite_scroll` mode for card layouts with `phx-viewport-bottom` loading.
- **Custom controls** - New `custom_controls` table option to override header controls (search, per-page, filter toggle) without replacing the entire header.
- **Hidden fields** - New `hidden: true` option for fields to include data without rendering columns.
- **Transformer module** - New `LiveTable.Transformer` module with `render/3` helper for field transformations.
- **Cheatsheets** - Added comprehensive cheatsheets for filters and live-table usage.

### Changed

- **Sutra UI migration** - Replaced `live_select` with `SutraUI.LiveSelect`, `nouislider` with `SutraUI.RangeSlider`, and adopted Sutra UI form components.
- **Colocated hooks** - JavaScript hooks are now colocated in components using Phoenix's runtime hooks feature.
- **Documentation overhaul** - Complete rewrite of documentation with improved installation, configuration, and usage guides.
- **Export dropdown** - Improved positioning and animation with relative/absolute positioning.
- Updated `phoenix_live_view` to 1.1.19.
- Added `igniter` dependency for code rewriting in generators.

### Fixed

- Fixed LiveResource insertion in mix tasks.
- Fixed infinite scroll load_more logic and options updates.
- Fixed filter layout stacking with `contents` class.
- Fixed integer conversion for JSON float values in range filters.
- Fixed empty state colspan calculations.

### Testing

- Added comprehensive test suites for table component, filters, exports, transformers, and mix tasks.
- New test fixtures and support modules.
- Integration tests for joined and single table resources.

## [0.3.1]

### Fixed

- Correct SQL syntax on limit clause.
- Use `table_options` `default_size` for per-page fallback.

### Changed

- Replace pagination links with buttons and update disabled state.
- Refactor resource listing to unify data source handling.

## [0.3.0]

### Added

- PDF export with record limit.
- Query debugging functionality.
- Dark mode support for light and dark themes.

### Changed

- Improved table UI using Tailwind 4.
- Comprehensive tests for TableComponent functionality.
- Moved demo app to separate repository.
