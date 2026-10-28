# Exports API Reference

LiveTable exports the table's data as CSV or PDF. An export includes every row that matches the
current search, filters and sort, not just the current page.

## Overview

LiveTable supports two export formats:
- **CSV** - Comma-separated values for spreadsheet applications
- **PDF** - Formatted documents using the Typst typesetting engine

`formats` accepts only formats LiveTable can actually produce. Any other entry raises an
`ArgumentError` listing the supported formats, rather than rendering a button that dispatches to
the wrong exporter.

## How it works

1. The user clicks an export button. The LiveView builds the export's query exactly as it builds
   the table's, including your `data_provider` and any per-user scoping.
2. The query is encrypted with your endpoint's `secret_key_base` into a download link that is
   valid for 60 seconds, and the browser follows it straight away.
3. `LiveTable.ExportPlug` decrypts the link, runs the query and streams the file back.

Nothing is written to `priv/static`, nothing needs cleaning up, and the download works whichever
node it lands on. The link can't be read or altered, and it carries its own authorisation, so the
plug doesn't need your login pipeline.

## Basic Setup

### 1. Route exports to LiveTable

`mix live_table.install` adds this to your router. To add it by hand, put it outside any `scope`
that pipes through `:browser`:

```elixir
# lib/your_app_web/router.ex
forward "/live_table/exports", LiveTable.ExportPlug
```

### 2. Enable exports in table configuration

Exports are enabled with both formats by default. To choose:

```elixir
def table_options do
  %{
    exports: %{
      enabled: true,
      formats: [:csv, :pdf]
    }
  }
end
```

The `export` event is ignored when exports are disabled or the format isn't in `formats`.

### Application-wide configuration

```elixir
# config/config.exs
config :live_table,
  defaults: %{
    exports: %{
      enabled: true,
      formats: [:csv]
    }
  }
```

## CSV Exports

CSV exports are streamed straight from the database to the browser with NimbleCSV, so large
exports use little memory.

- The header row uses your field labels.
- Text cells starting with `=`, `+`, `-`, `@`, a tab or a carriage return get a leading `'`,
  so spreadsheet apps show them as text instead of running them as formulas.

```csv
ID,Product Name,Price,Stock,Category
1,iPhone 15 Pro,999.99,25,Electronics
2,MacBook Air,1199.99,8,Electronics
```

## PDF Exports

PDF exports are limited to 10,000 rows. Above that, the user is asked to filter the table first.

PDF export uses the [`typst`](https://hex.pm/packages/typst) package, an optional dependency
that `mix live_table.install` adds. It ships precompiled, so there is nothing to install on the
server. Without it, the PDF option isn't shown, even if `formats` lists `:pdf`:

```elixir
{:typst, "~> 0.4.4"}
```

The bundled fonts cover Latin, Devanagari, Arabic and Hebrew. For other scripts, such as Telugu,
point LiveTable at a folder of fonts (for example Noto Sans Telugu) and ship it with your release:

```elixir
config :live_table, pdf_font_dirs: [Path.expand("../priv/fonts", __DIR__)]
```

Cell values are passed to Typst as text, never as markup or code.

## Upgrade Notes

When upgrading from 0.4.2 or earlier: exports no longer use Oban or files in `priv/static`:

- Add `forward "/live_table/exports", LiveTable.ExportPlug` to your router.
- Remove `"exports"` from `static_paths` and delete `priv/static/exports`.
- Remove the `app:` and `pubsub:` keys from `config :live_table`. They are no longer used.
- PDF uses the `typst` package instead of the `typst` CLI: add `{:typst, "~> 0.4.4"}` to your deps.
- LiveTable no longer depends on `:oban` or `:oban_web`. If your app doesn't use Oban elsewhere,
  you can remove it and its `exports` queue.

Custom export buttons should send `phx-click="export"` with `phx-value-format="csv"` or
`phx-value-format="pdf"`. The previous `"export-csv"` and `"export-pdf"` events are no longer
handled.

## Troubleshooting

**Clicking export does nothing:**
- Check that exports are enabled and the format is in `formats`.
- Check that the router forwards `/live_table/exports` to `LiveTable.ExportPlug`.

**The download is a 404 page:**
- The link expires 60 seconds after the click. Click export again.
- If the route is inside a `scope` with a path prefix, move it to the top level of the router.

**There is no PDF option:**
- Add `{:typst, "~> 0.4.4"}` to your deps.

**PDF export fails:**
- The error is logged as `LiveTable PDF export failed: ...`, with Typst's message.
- Text shows as boxes: add a font for that script with `pdf_font_dirs` (see above).
