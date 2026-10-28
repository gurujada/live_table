# LiveTable 0.5: our plan (for Virinchi to merge with his work)

Written 28 Oct 2026 from Gurujada's library design. Nothing here is binding: keep what fits
your work, change what doesn't, and say what you drop. LiveTable stays a server-rendered
table with no JS bundle.

## Already done on this branch (`csp-ids-sutraui-0.5`)

- `nonce` assign on `<.live_table>`, passed to every inline hook script it renders
  (`.Download`, `.SortableColumn`, SutraUI's dropdown). Apps can use
  `script-src 'self' 'nonce-…'; style-src 'self'`.
- `id` assign: every DOM id the table renders is `"<id>-<name>"` (search, per-page select,
  export dropdown, filters, stream containers, empty placeholders, sort links), so two
  tables can share a page. The default id `"live-table"` keeps today's ids exactly.
- Fixed grays in `select.ex` replaced by SutraUI tokens (`text-foreground`,
  `text-muted-foreground`).
- SutraUI is a required dependency (fixes #34), from GitHub master until SutraUI 0.5.0 is
  on Hex. Version left at 0.4.2 and the changelog "Unreleased", for you to set.
- 455 tests pass against SutraUI master.

Left open: filter component ids come from the filter key only (`filters-<key>`,
`range_filter[<key>]`, `select_filter[<key>]`), so two tables with the same filter key on
one page still collide. The lock pins `decimal` 2.4.1 and `postgrex` 0.21.1, which have
advisories (Decimal.round DoS; Postgrex.Notifications channel-name injection); update them.

## 0.5 features

| Area | Plan |
|---|---|
| Dependencies | Oban and `oban_web` removed. `nimble_csv`, `xlsx_writer` and `typst` optional |
| Exports | LiveTable provides the API; the app decides where it runs (below) |
| Sources | A `LiveTable.Source` behaviour: an Ecto query (today), a list, or your own. A slow source loads in a task, with Stop and a timeout |
| Paging | Read the next page by key after the last row instead of `OFFSET`. The total count deferred, on demand, or skipped. Page numbers kept for small tables |
| Filters and sorting | Filter chips that name each filter and open it, an "Add filter" button, a header menu per column with its sorts and its filter, and an enum's values with counts (one `GROUP BY`). Filter ids derive from the table id |
| Views | Sort, filters, search and columns in the URL; named views saved per person (an Ecto store the app generates) |
| Actions | Bulk actions on the selected rows, with "all rows of the query" as one `Ecto.Query`; a row menu; confirmation; long actions as jobs with progress |
| Live rows | `live={{PubSub, topic}}`: changed rows arrive, keeping each person's sort, filters and scroll |
| Columns | Hide, pin and reorder; decimals sent as text |
| Look | SutraUI tokens only, no fixed palette colours, no `style=` attributes |
| Test | `LiveTable.Test`: read, sort, filter and act on a table in LiveView tests |

## Exports: an API, not a job runner

- `LiveTable.Export.render(table, params, format)` returns the file for CSV, XLSX or PDF.
- A normal-size export streams straight back from a route the app mounts
  (`live_table_exports` in the router), rendered in a task with a timeout.
- For a large export, the app calls the same `render/3` from its own Oban worker and stores
  or mails the file. LiveTable itself runs no jobs and does not depend on Oban.
- Formats:
  - CSV: NimbleCSV, streamed.
  - XLSX: `xlsx_writer` (Rust NIF, precompiled; maintained, unlike `elixlsx`).
  - PDF: the `typst` hex package (Typst as a precompiled Rust NIF, dirty CPU scheduler):
    `Typst.render_to_pdf(markup, bindings, extra_fonts: [dir])`. In-process: no Chrome,
    no external `typst` binary, no temp files. A default template the app can replace.
- Checked on 28 Oct with typst 0.4.4: a 2,000-row table with Telugu and Devanagari names
  rendered 45 pages in about 1 s, with the header repeated and "Page n of 45". Fonts are
  not bundled: the app passes a fonts directory (Noto Sans, Noto Sans Telugu, Noto Sans
  Devanagari), and the release must ship it. (Today's tests warn "unknown font family:
  dejavu sans" for the same reason.)

## What moves in from elsewhere

- **From SutraUI:** `filter_bar` is deprecated in SutraUI 0.5.0 (removed in 0.6); its job
  becomes LiveTable's filter chips. `table` and `pagination` stay in SutraUI as building
  blocks. LiveTable 0.5 should be published no later than SutraUI 0.5.0, so the
  deprecation points at a real replacement.
- **From Gurujada** (`lib/gurujada_web/components/ui/controls.ex` in the gurujada app):
  `filter_chips`, `filter_popover`, `sort_head` and `sort_menu`, used today by the people,
  roster, scores and question bank lists. They are the reference for the chips and header
  menus above.
- **Ideas from Masu** (ideas only, no code or dependency): key-based block reads, live rows
  that keep sort and scroll, saved views, test helpers. Masu's virtual grid and spreadsheet
  editing stay out; an edit grid would be a separate component when an app needs one.

## SutraUI 0.5 pieces LiveTable can build on (all on SutraUI master now)

- `select`: a real `<select>` underneath with SutraUI's list on top and a bottom sheet on
  phones. Its hook is extracted, so apps merge `phoenix-colocated/sutra_ui` hooks into
  their LiveSocket.
- Popover, dropdown and select cards are `position: fixed` and stay on screen (flip,
  shift, cap); they are not clipped inside dialogs. Good for header menus and filter
  popovers.
- `data-confirm` opens SutraUI's own confirmation dialog (from P2, being merged), for bulk
  and row actions.
- Toasts that LiveComponents can send (P2), for "Exported 2,000 rows" and undo.
- `relative_time` and `local_time` for date columns; `segmented` and `filter_tabs`; URL
  tabs (`patch` / `navigate`).
- Badge tones (`success`, `info`, `warning`, `brand`, `ai`) with `appearance` solid, soft
  or dashed, for status columns.
