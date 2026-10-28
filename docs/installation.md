# Installation

This guide walks you through setting up LiveTable in your Phoenix application.

## Prerequisites

- **Elixir** 1.20 or later
- **Phoenix** 1.8+ with LiveView 1.2+
- **Ecto** 3.13+
- **Tailwind CSS** (recommended, but not required)

## Quick Installation

### Step 1: Add Dependency

```elixir
# mix.exs
def deps do
  [
    {:live_table, "~> 0.4.2"}
  ]
end
```

```bash
mix deps.get
```

### Step 2: Run Installer

If you want to use installer/generator tasks, add the optional Igniter dependency first:

```elixir
{:igniter, "~> 0.7", only: :dev, runtime: false}
```

```bash
mix deps.get
```

```bash
mix live_table.install
```

The installer automatically:
- Adds LiveTable configuration to `config/config.exs`
- Adds [Sutra UI](https://github.com/gurujada/sutra_ui), the recommended UI components
- Adds the exports route to your router (`forward "/live_table/exports", LiveTable.ExportPlug`)

Then set up Sutra UI's CSS with `mix sutra_ui.install` (see the [Sutra UI installation guide](https://hexdocs.pm/sutra_ui/readme.html#installation)).

To use your own components instead, remove `sutra_ui` from your deps and follow [Custom Components](custom-components.md).

### Step 3: Restart your server

```bash
mix phx.server
```

That's it! See the [Quick Start Guide](quick-start.html) to create your first table.

> **Note:** LiveTable uses runtime hooks, so no JavaScript configuration is required. 
> Hooks are automatically registered when your LiveView renders.

---

## Manual Configuration

If the installer doesn't work for your project structure, add `{:sutra_ui, "~> 0.4.0"}` to your deps
(or configure [your own components](custom-components.md)), and add to `config/config.exs`:

```elixir
config :live_table, repo: YourApp.Repo
```

and add the exports route to your router, outside any `scope` that pipes through `:browser`:

```elixir
forward "/live_table/exports", LiveTable.ExportPlug
```

---

## PDF Exports (Typst)

CSV exports need nothing else. PDF exports require [Typst](https://typst.app) installed on your system:

**macOS:**
```bash
brew install typst
```

**Ubuntu/Debian:**
```bash
wget https://github.com/typst/typst/releases/latest/download/typst-x86_64-unknown-linux-musl.tar.xz
tar -xf typst-x86_64-unknown-linux-musl.tar.xz
sudo mv typst-x86_64-unknown-linux-musl/typst /usr/local/bin/
```

**Windows:** Download from [Typst Releases](https://github.com/typst/typst/releases).

Verify:
```bash
typst --version
```

---

## Verification

Test your installation with a minimal table:

```elixir
# lib/your_app_web/live/test_live.ex
defmodule YourAppWeb.TestLive do
  use YourAppWeb, :live_view
  use LiveTable.LiveResource, schema: YourApp.User

  def fields do
    [
      id: %{label: "ID", sortable: true},
      email: %{label: "Email", sortable: true, searchable: true}
    ]
  end

  def filters, do: []
end
```

```elixir
# router.ex
live "/test", TestLive
```

Visit `/test` - you should see a working table!

---

## Troubleshooting

### Exports failing

- Check that your router has `forward "/live_table/exports", LiveTable.ExportPlug`
- For PDF, check that `typst --version` works on the server
- See [Exports](api/exports.md#troubleshooting)

### "Unknown column" errors

- Field keys must match your schema field names exactly
- For custom queries, field keys must match your `select` clause keys

See the [Troubleshooting Guide](troubleshooting.html) for more detailed solutions.

---

## Next Steps

- [Quick Start](quick-start.html) - Build your first table
- [Fields API](api/fields.html) - Field configuration options  
- [Filters API](api/filters.html) - Add filtering to your tables
- [Table Options](api/table-options.html) - Pagination, exports, debug mode
