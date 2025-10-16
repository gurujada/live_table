# Installation

This guide will walk you through setting up LiveTable in your Phoenix application.

## Prerequisites

Before installing LiveTable, ensure you have:

- **Elixir** 1.14 or later
- **Phoenix** 1.7+ with LiveView 1.0+
- **Ecto** 3.10+


## Step 1: Add Dependencies

Add LiveTable to your `mix.exs` dependencies:

```elixir
def deps do
  [
    {:live_table, "~> 0.3.1"},
    
    # Optional: Oban is required only if you want CSV/PDF exports.
    # The installer can add Oban for you if you opt in during the prompt.
    {:oban, "~> 2.19"}
  ]
end
```

Run the dependency installation:

```bash
mix deps.get
```

## Step 2: Automatic Installation (Recommended)

Use the built-in installer to automatically configure LiveTable:

```bash
mix live_table.install
```

What the installer does:
- Adds LiveTable configuration to `config/config.exs` (quiet on success)
- Updates `assets/js/app.js` with `TableHooks` (quiet on success)
- Updates `assets/css/app.css` with LiveTable styles (quiet on success)
- Does not modify your web module; instead it reminds you to add `exports` to static paths

Oban integration (for exports):
- The installer will ask: “Configure Oban for exports now?”  
  - If you answer “Yes”, it will:
    - Add `{:oban, "~> 2.19"}` to your `mix.exs`
    - Fetch and compile dependencies
    - Add Oban configuration to `config/config.exs` (repo, plugins, and `queues: [exports: 10]`)
    - Print a next step showing how to start Oban in your supervision tree
  - If you answer “No”, you can configure Oban later manually.

After running the installer, restart your Phoenix server.

## Step 3: Manual Configuration (Alternative)

If you prefer manual setup or need to customize the installation, follow these steps:

### Application Configuration

Configure LiveTable in your `config/config.exs`:

```elixir
config :live_table,
  repo: YourApp.Repo,
  pubsub: YourApp.PubSub
```

### Oban Configuration (Required for Exports)

If you opted in during installation, the installer already added this for you.  
To add manually:

```elixir
# config/config.exs
config :your_app, Oban,
  repo: YourApp.Repo,
  plugins: [Oban.Plugins.Pruner],
  queues: [exports: 10]
```

Start Oban in your supervision tree (`lib/your_app/application.ex`):

```elixir
def start(_type, _args) do
  children = [
    # ... your existing children
    {Oban, Application.fetch_env!(:your_app, Oban)}
  ]
  
  opts = [strategy: :one_for_one, name: YourApp.Supervisor]
  Supervisor.start_link(children, opts)
end
```

### Asset Setup

#### Add JavaScript Hooks

Add LiveTable hooks to your `assets/js/app.js`:

```javascript
// Import LiveTable hooks
import { TableHooks } from "../../deps/live_table/priv/static/live-table.js"

// Your existing imports
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")

// Add TableHooks to your LiveSocket
let liveSocket = new LiveSocket("/live", Socket, {
  params: {_csrf_token: csrfToken},
  hooks: TableHooks  // Add this line
})

// Connect if there are any LiveViews on the page
liveSocket.connect()

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", info => topbar.show())
window.addEventListener("phx:page-loading-stop", info => topbar.hide())

// Make liveSocket available for debugging
window.liveSocket = liveSocket
```

#### Add CSS Styles

Add LiveTable styles to your `assets/css/app.css`.

- If your app uses Tailwind (recommended):
```css
@import "tailwindcss/base";
@import "tailwindcss/components";
@import "tailwindcss/utilities";

/* Source CSS so Tailwind can process @apply/@layer */
@import "../../deps/live_table/assets/css/live-table.css";
```

- If your app does NOT use Tailwind:
```css
/* Use the prebuilt, dependency-free stylesheet */
@import "../../deps/live_table/priv/static/live-table.css";
```

Both options work; choose the one that matches your pipeline.

### Database Setup

Run migrations to set up Oban tables:

```bash
mix ecto.create_migration add_oban_jobs_table
```

Use the Oban migration generator:

```bash
mix oban.install
mix ecto.migrate
```

### Static File Configuration

Add `exports` to your allowed static paths in `lib/your_app_web.ex`:

```elixir
def static_paths, do: ~w(assets fonts images favicon.ico robots.txt exports)
```

The installer does not modify this for you. This allows LiveTable to serve generated export files.

## Step 4: PDF Export Setup (Optional)

For PDF exports, install Typst on your system:

### macOS
```bash
brew install typst
```

### Ubuntu/Debian
```bash
# Download latest release from GitHub
wget https://github.com/typst/typst/releases/latest/download/typst-x86_64-unknown-linux-musl.tar.xz
tar -xf typst-x86_64-unknown-linux-musl.tar.xz
sudo mv typst-x86_64-unknown-linux-musl/typst /usr/local/bin/
```

### Windows
Download from [Typst Releases](https://github.com/typst/typst/releases) and add to PATH.

### Verify Installation
```bash
typst --version
```

## Step 5: Verification

Create a simple test to verify everything is working:

```elixir
# lib/your_app_web/live/test_table_live.ex
defmodule YourAppWeb.TestTableLive do
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

Add a route in `router.ex`:

```elixir
scope "/", YourAppWeb do
  pipe_through :browser
  
  live "/test-table", TestTableLive
end
```

Visit `/test-table` to see your table in action!

## Troubleshooting

### Common Issues

**Hooks not working**: Verify TableHooks are properly imported and added to LiveSocket.

**Styling issues**: Make sure Tailwind CSS is properly configured and processing LiveTable classes.

**Export errors**: Check that Oban is running and the exports queue is configured.

### Development vs Production

**Development**: Assets are compiled automatically with `mix phx.server`

**Production**: Run `mix assets.deploy` to compile assets, or use your deployment pipeline.

## Next Steps

- Read the [Quick Start Guide](quick-start.md) to build your first table
- Explore [Configuration Options](configuration.md) to customize behavior
- Check out [Examples](examples/simple-table.md) for real-world usage patterns