# mix live_table.install

Installs and configures LiveTable in your Phoenix application.

## Usage

```bash
mix live_table.install
```

With Oban for exports (optional):

```bash
mix live_table.install --oban
```

## What It Does

The install generator automatically configures your Phoenix application:

### 1. Configuration (`config/config.exs`)

Adds LiveTable configuration with your app's Repo and PubSub:

```elixir
config :live_table,
  repo: YourApp.Repo,
  pubsub: YourApp.PubSub
```

### 2. Oban Configuration (Optional)

If you use the `--oban` flag (for CSV/PDF exports):

```elixir
config :your_app, Oban,
  repo: YourApp.Repo,
  plugins: [Oban.Plugins.Pruner],
  queues: [exports: 10]
```

## Manual Steps Required

After running the installer, you must:

### 1. Add Static Paths

In your `lib/your_app_web.ex`, add `"exports"` to your static paths:

```elixir
def static_paths, do: ~w(assets fonts images favicon.ico robots.txt exports)
```

### 2. Start Oban (if using exports)

Add Oban to your supervision tree in `lib/your_app/application.ex`:

```elixir
children = [
  # ... other children
  {Oban, Application.fetch_env!(:your_app, Oban)}
]
```

### 3. Restart Your Server

```bash
mix phx.server
```

## Options

| Option | Description |
|--------|-------------|
| `--oban` | Configure Oban for CSV/PDF exports |
| `--yes` | Skip confirmation prompts |

## Troubleshooting

### "Could not find config/config.exs"

The installer expects a standard Phoenix project structure. If your config is in a different location, you'll need to manually add the configuration.

> **Note**: LiveTable uses colocated hooks (Phoenix 1.8+), so there's no need to import JavaScript hooks or CSS manually.

## See Also

- [Installation Guide](installation.html) - Full installation walkthrough
- [Quick Start](quick-start.html) - Create your first table
- [mix live_table.gen.live](live_table.gen.live.html) - Generate LiveView with table
