# mix live_table.install

Installs and configures LiveTable in your Phoenix application.

## Usage

This task requires the optional `:igniter` dependency in your app:

```elixir
{:igniter, "~> 0.7", only: :dev, runtime: false}
```

```bash
mix live_table.install
```

## What It Does

The install generator automatically configures your Phoenix application:

### 1. Configuration (`config/config.exs`)

Adds LiveTable configuration with your Repo:

```elixir
config :live_table, repo: YourApp.Repo
```

### 2. Sutra UI

Adds `{:sutra_ui, "~> 0.4.0"}`, the recommended UI components, to your deps. Run
`mix sutra_ui.install` afterwards to set up its CSS. To use your own components,
remove it and see [Custom Components](../custom-components.html).

### 3. Typst

Adds `{:typst, "~> 0.4.4"}` for PDF exports. Remove it if you don't need PDF; the PDF option
is then hidden.

### 4. Exports route

Adds the route that serves CSV and PDF exports to your router, outside the `:browser`
pipeline:

```elixir
scope "/" do
  forward "/live_table/exports", LiveTable.ExportPlug
end
```

## After installing

### 1. Set up Sutra UI

```bash
mix sutra_ui.install
```

### 2. Restart Your Server

```bash
mix phx.server
```

## Options

| Option | Description |
|--------|-------------|
| `--yes` | Skip confirmation prompts |

## Troubleshooting

### Config or route not added

The installer creates `config/config.exs` if it is missing, and leaves it alone if it already has a `config :live_table` entry. If it cannot find your Phoenix router, it skips the exports route; add `forward "/live_table/exports", LiveTable.ExportPlug` manually.

## See Also

- [Installation Guide](../installation.html) - Full installation walkthrough
- [Quick Start](../quick-start.html) - Create your first table
- [mix live_table.gen.live](live_table.gen.live.html) - Generate LiveView with table
