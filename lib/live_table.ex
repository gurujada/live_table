defmodule LiveTable do
  @moduledoc """

  A powerful Phoenix LiveView component library for building dynamic, interactive data tables with real-time updates. Perfect for admin panels, dashboards, and any application requiring advanced data presentation.

  ## ✨ Features

  - **🔍 Advanced Filtering** - Text search, range filters, select dropdowns, boolean toggles
  - **📊 Smart Sorting** - Multi-column sorting with shift-click support
  - **📄 Flexible Pagination** - Configurable page sizes with efficient querying
  - **📤 Export Capabilities** - CSV and PDF exports with background processing
  - **⚡ Real-time Updates** - Built for Phoenix LiveView with instant feedback
  - **🎨 Multiple View Modes** - Table and card layouts with custom components
  - **🔗 Custom Queries** - Support for complex joins and computed fields
  - **🚀 Performance Optimized** - Streams-based rendering for large datasets

  ![LiveTable Demo](../demo.gif)

  **[Live Demo with 1M+ records →](https://livetable.gurujada.com)**

  **[Advanced Demo with custom queries, & transformer usage →](https://josaa.gurujada.com)**

  **[Advanced Demo Git Url →](https://github.com/ChivukulaVirinchi/college-app)**


  ## 🚀 Quick Start

  ### 1. Installation

  Add to your `mix.exs`:

  ```elixir
  def deps do
  [
    {:live_table, "~> 0.3.1"},
    {:oban, "~> 2.19"}  # Required for exports
  ]
  end
  ```

  ### 2. Basic Configuration

  In your `config/config.exs`:

  ```elixir
  config :live_table,
  repo: YourApp.Repo,
  pubsub: YourApp.PubSub

  # Configure Oban for exports
  config :your_app, Oban,
  repo: YourApp.Repo,
  queues: [exports: 10]
  ```

  ### 3. Setup Assets

  Add to `assets/js/app.js`:

  ```javascript
  import hooks_default from "../../deps/live_table/priv/static/live-table.js";

  const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: { _csrf_token: csrfToken },
  hooks: hooks_default,
  });
  ```

  Add to `assets/css/app.css`:

  ```css
  @source "../../deps/live_table/lib";

  @import "../../deps/live_table/priv/static/live-table.css";
  ```

  ### 4. Create Your First Table
  LiveTable requires field & filter definitions to build a table. Additional configuration options can be defined per table under `table_options`.

  ```elixir
  # lib/your_app_web/live/product_live/index.ex
  defmodule YourAppWeb.ProductLive.Index do
  use YourAppWeb, :live_view
  use LiveTable.LiveResource, schema: YourApp.Product

  def fields do
    [
      id: %{label: "ID", sortable: true},
      name: %{label: "Product Name", sortable: true, searchable: true},
      price: %{label: "Price", sortable: true},
      stock_quantity: %{label: "Stock", sortable: true}
    ]
  end

  def filters do
    [
      in_stock: Boolean.new(:stock_quantity, "in_stock", %{
        label: "In Stock Only",
        condition: dynamic([p], p.stock_quantity > 0)
      }),

      price_range: Range.new(:price, "price_range", %{
        type: :number,
        label: "Price Range",
        min: 0,
        max: 1000
      })
    ]
  end
  end
  ```

  ### 5. Add to Your Template

  ```elixir
  # lib/your_app_web/live/product_live/index.html.heex
  <.live_table
  fields={fields()}
  filters={filters()}
  options={@options}
  streams={@streams}
  />
  ```

  That's it! You now have a fully functional data table with sorting, filtering, pagination, and search.

  ## 🏗 Usage Patterns

  ### Simple Tables (Single Schema)

  For basic tables querying a single schema, use the `schema:` parameter. The field keys must match the schema field names exactly:

  ```elixir
  defmodule YourAppWeb.UserLive.Index do
  use YourAppWeb, :live_view
  use LiveTable.LiveResource, schema: YourApp.User

  def fields do
    [
      id: %{label: "ID", sortable: true},        # Must match User.id field
      email: %{label: "Email", sortable: true, searchable: true},   # Must match User.email field
      name: %{label: "Name", sortable: true, searchable: true}      # Must match User.name field
    ]
  end
  end
  ```

  ### Complex Tables (Custom Queries)

  For tables with joins, computed fields, or complex logic, you must define a custom data provider. The field keys must match the keys in your query's `select` clause:

  ```elixir
  defmodule YourAppWeb.OrderReportLive.Index do
  use YourAppWeb, :live_view
  use LiveTable.LiveResource

  def mount(_params, _session, socket) do
    # Assign your custom data provider
    socket = assign(socket, :data_provider, {YourApp.Orders, :list_with_details, []})
    {:ok, socket}
  end

  def fields do
    [
      order_id: %{label: "Order #", sortable: true},        # Must match select key
      customer_name: %{label: "Customer", sortable: true, searchable: true},  # Must match select key
      total_amount: %{label: "Total", sortable: true},      # Must match select key
      # For sorting by joined fields, specify the alias used in your query
      product_name: %{
        label: "Product",
        sortable: true,
        assoc: {:order_items, :name}    # Must match query alias and field
      }
    ]
  end

  def filters do
    [
      status: Select.new({:orders, :status}, "status", %{
        label: "Order Status",
        options: [
          %{label: "Pending", value: ["pending"]},
          %{label: "Completed", value: ["completed"]}
        ]
      })
    ]
  end
  end
  ```

  ```elixir
  # In your context
  defmodule YourApp.Orders do
  def list_with_details do
    from o in Order,
      join: c in Customer, on: o.customer_id == c.id,
      join: oi in OrderItem, on: oi.order_id == o.id, as: :order_items,
      select: %{
        order_id: o.id,               # Field key must match this
        customer_name: c.name,        # Field key must match this
        total_amount: o.total_amount, # Field key must match this
        product_name: oi.product_name # Field key must match this
      }
  end
  end
  ```

  ## 📚 Documentation

  - **[Installation & Setup](docs/installation.md)** - Complete setup guide
  - **[Quick Start Guide](docs/quick-start.md)** - Get up and running in 5 minutes
  - **[Configuration](docs/configuration.md)** - Customize table behavior
  - **[API Reference](docs/api/fields.md)** - Complete API documentation
  - **[Examples](docs/examples/simple-table.md)** - Real-world usage examples
  - **[Troubleshooting](docs/troubleshooting.md)** - Common issues and solutions

  ## 🎯 Use Cases

  LiveTable is perfect for:

  - **Admin Dashboards** - Manage users, orders, products with advanced filtering
  - **E-commerce Catalogs** - Product listings with search, filters, and sorting
  - **Data Analytics** - Present large datasets with exports and real-time updates
  - **CRM Systems** - Customer and lead management with custom views
  - **Inventory Management** - Track stock with complex filtering and reporting

  ## 📄 License

  MIT License. See LICENSE for details.

  ## 🤝 Contributing

  1. Fork the repository
  2. Create your feature branch (`git checkout -b feature/amazing-feature`)
  3. Commit your changes (`git commit -m 'Add amazing feature'`)
  4. Push to the branch (`git push origin feature/amazing-feature`)
  5. Open a Pull Request

  ## 📞 Support

  - **Issues**: [GitHub Issues](https://github.com/gurujada/live_table/issues)
  - **Discussions**: [GitHub Discussions](https://github.com/gurujada/live_table/discussions)
  - **Documentation**: [API Docs](https://hexdocs.pm/live_table)

  ---

  Built with ❤️ for the Phoenix LiveView community.
  """
end
