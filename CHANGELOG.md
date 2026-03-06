# Changelog

All notable changes to LiveTable will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
