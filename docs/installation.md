# Installation

This guide walks you through setting up LiveTable in your Phoenix application.

## Prerequisites

- **Elixir** 1.17 or later
- **Phoenix** 1.8+ with LiveView 1.0+
- **Ecto** 3.10+
- **Tailwind CSS** (recommended, but not required)

## Quick Installation

### Step 1: Add Dependency

```elixir
# mix.exs
def deps do
  [
    {:live_table, "~> 0.4.0"}
  ]
end
```

```bash
mix deps.get
```

### Step 2: Run Installer

```bash
mix live_table.install
```

The installer automatically:
- Adds LiveTable configuration to `config/config.exs`
- Optionally configures Oban for exports (use `--oban` flag or you'll be prompted)

### Step 3: Manual Steps

After the installer completes:

**1. Add static paths** in `lib/your_app_web.ex`:

```elixir
def static_paths, do: ~w(assets fonts images favicon.ico robots.txt exports)
```

**2. If using Oban for exports**, add to your supervision tree in `lib/your_app/application.ex`:

```elixir
children = [
  # ... other children
  {Oban, Application.fetch_env!(:your_app, Oban)}
]
```

**3. Restart your server:**

```bash
mix phx.server
```

That's it! See the [Quick Start Guide](quick-start.html) to create your first table.

> **Note:** LiveTable uses runtime hooks, so no JavaScript configuration is required. 
> Hooks are automatically registered when your LiveView renders.

---

## Manual Configuration

If the installer doesn't work for your project structure, add to `config/config.exs`:

```elixir
config :live_table,
  app: :your_app,
  repo: YourApp.Repo,
  pubsub: YourApp.PubSub
```

The `:app` option is required for exports to work correctly in production releases.

---

## Export Setup (Optional)

LiveTable supports CSV and PDF exports using Oban for background processing.

### Oban Configuration

Add Oban to your dependencies:

```elixir
{:oban, "~> 2.19"}
```

Configure in `config/config.exs`:

```elixir
config :your_app, Oban,
  repo: YourApp.Repo,
  plugins: [Oban.Plugins.Pruner],
  queues: [exports: 10]
```

Add to supervision tree:

```elixir
children = [
  {Oban, Application.fetch_env!(:your_app, Oban)}
]
```

Run Oban migrations:

```bash
mix oban.install
mix ecto.migrate
```

### PDF Export (Typst)

PDF exports require [Typst](https://typst.app) installed on your system:

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

- Verify Oban is running: check `Oban.check_queue(:exports)`
- Ensure `exports` is in your static paths
- Check server logs for detailed error messages

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
