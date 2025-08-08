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
    {:oban, "~> 2.19"}           # Required for background exports
  ]
end
```

Run the dependency installation:

```bash
mix deps.get
```

## Step 2: Application Configuration

Configure LiveTable in your `config/config.exs`:

```elixir
config :live_table,
  repo: YourApp.Repo,
  pubsub: YourApp.PubSub
```

### Oban Configuration (Required for Exports)

Add Oban configuration for background job processing:

```elixir
# config/config.exs
config :your_app, Oban,
  repo: YourApp.Repo,
  engine: Oban.Engines.Basic,
  notifier: Oban.Notifiers.Postgres,
  plugins: [Oban.Plugins.Pruner],
  queues: [exports: 10]
```

Add Oban to your supervision tree in `lib/your_app/application.ex`:

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

## Step 3: Asset Setup

### Configure Tailwind CSS

Update your `assets/tailwind.config.js`:

```javascript
module.exports = {
  content: [
    "./js/**/*.js",
    "../lib/*_web.ex",
    "../lib/*_web/**/*.*ex",
    // Add these LiveTable paths
    "../deps/live_table/priv/static/*.js",
    "../deps/live_table/**/*.*ex"
  ],
  theme: {
    extend: {},
  },
  plugins: [
    require("@tailwindcss/forms")
  ]
}
```

### Add JavaScript Hooks

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

### Add CSS Styles

Add LiveTable styles to your `assets/css/app.css`:

```css
@import "tailwindcss/base";
@import "tailwindcss/components";
@import "tailwindcss/utilities";

/* Add LiveTable styles */
@import "../../deps/live_table/priv/static/live-table.css";

/* Your existing styles */
```

## Step 4: Database Setup

Run migrations to set up Oban tables:

```bash
mix ecto.create_migration add_oban_jobs_table
```

Use the Oban migration generator:

```bash
mix oban.install
mix ecto.migrate
```

## Step 5: Static File Configuration

Add `exports` to your allowed static paths in `lib/your_app_web.ex`:

```elixir
def static_paths, do: ~w(assets fonts images favicon.ico robots.txt exports)
```

This allows LiveTable to serve generated export files.

## Step 6: PDF Export Setup (Optional)

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

## Step 7: Verification

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