# Quick Start Guide

Note on styling: LiveTable uses DaisyUI class semantics with a Tailwind-based shim, so it looks good without DaisyUI. If DaisyUI is present, components adopt your active Daisy theme automatically.

Get up and running with LiveTable in 5 minutes! This guide assumes you've already completed the [installation](installation.md).

## What We'll Build

We'll create a product catalog table for an e-commerce application with:
- Product listing with sorting and search
- Price range filtering
- Stock status filtering
- Export functionality

## Step 1: Create Your Schema

First, let's define a simple Product schema:

```elixir
# lib/your_app/catalog/product.ex
defmodule YourApp.Catalog.Product do
  use Ecto.Schema
  
  schema "products" do
    field :name, :string
    field :description, :string
    field :price, :decimal
    field :stock_quantity, :integer
    field :active, :boolean, default: true
    field :sku, :string
    
    timestamps()
  end
end
```

## Step 2: Create a Simple LiveView

Create your products listing LiveView for a single table:

```elixir
# lib/your_app_web/live/product_live/index.ex
defmodule YourAppWeb.ProductLive.Index do
  use YourAppWeb, :live_view
  use LiveTable.LiveResource, schema: YourApp.Catalog.Product
  
  # Define your table columns
  def fields do
    [
      id: %{
        label: "ID",
        sortable: true
      },
      name: %{
        label: "Product Name",
        sortable: true,
        searchable: true
      },
      sku: %{
        label: "SKU",
        sortable: true,
        searchable: true
      },
      price: %{
        label: "Price",
        sortable: true,
        renderer: &format_price/1
      },
      stock_quantity: %{
        label: "Stock",
        sortable: true
      },
      active: %{
        label: "Status",
        sortable: true,
        renderer: &format_status/1
      }
    ]
  end
  
  # Define your filters
  def filters do
    [
      # Boolean filter for active products
      active_only: Boolean.new(:active, "active", %{
        label: "Active Products Only",
        condition: dynamic([p], p.active == true)
      }),
      
      # Range filter for price
      price_range: Range.new(:price, "price_range", %{
        type: :number,
        label: "Price Range",
        unit: "$",
        min: 0,
        max: 1000,
        step: 10
      }),
      
      # Boolean filter for low stock
      low_stock: Boolean.new(:stock_quantity, "low_stock", %{
        label: "Low Stock (< 10)",
        condition: dynamic([p], p.stock_quantity < 10)
      })
    ]
  end
  
  # Custom renderers for better display
  defp format_price(price) do
    assigns = %{price: price}
    ~H"""
    <span class="font-mono text-green-600">
      $<%= :erlang.float_to_binary(@price, decimals: 2) %>
    </span>
    """
  end
  
  defp format_status(active) do
    assigns = %{active: active}
    ~H"""
    <span class={[
      "px-2 py-1 text-xs font-medium rounded-full",
      if(@active, do: "bg-green-100 text-green-700", else: "bg-red-100 text-red-700")
    ]}>
      <%= if @active, do: "Active", else: "Inactive" %>
    </span>
    """
  end
end
```

## Step 3: Create the Template

Create the template file:

```elixir
# lib/your_app_web/live/product_live/index.html.heex
<div class="px-4 py-6 sm:px-0">
  <div class="mb-6">
    <h1 class="text-2xl font-bold text-gray-900">Product Catalog</h1>
    <p class="mt-2 text-sm text-gray-600">
      Manage your product inventory with advanced filtering and search.
    </p>
  </div>

  <.live_table
    fields={fields()}
    filters={filters()}
    options={@options}
    streams={@streams}
    actions={actions()} # optional
  />
</div>
```

## Step 4: Add Routes

Add the route to your router:

```elixir
# lib/your_app_web/router.ex
scope "/", YourAppWeb do
  pipe_through :browser
  
  live "/products", ProductLive.Index, :index
end
```

## Step 5: Seed Some Data

Create some sample data to test with:

```elixir
# priv/repo/seeds.exs
alias YourApp.Repo
alias YourApp.Catalog.Product

# Create products
products = [
  %Product{
    name: "iPhone 15 Pro",
    description: "Latest Apple smartphone",
    price: Decimal.new("999.99"),
    stock_quantity: 25,
    active: true,
    sku: "IPHONE15PRO"
  },
  %Product{
    name: "MacBook Air M2",
    description: "Apple laptop with M2 chip",
    price: Decimal.new("1199.99"),
    stock_quantity: 8,
    active: true,
    sku: "MACBOOKAIR"
  },
  %Product{
    name: "Wireless Mouse",
    description: "Ergonomic wireless mouse",
    price: Decimal.new("45.99"),
    stock_quantity: 50,
    active: true,
    sku: "WMOUSE01"
  },
  %Product{
    name: "USB Cable",
    description: "High-quality USB-C cable",
    price: Decimal.new("24.99"),
    stock_quantity: 3,
    active: true,
    sku: "USBCABLE"
  },
  %Product{
    name: "Discontinued Phone",
    description: "No longer available",
    price: Decimal.new("299.99"),
    stock_quantity: 0,
    active: false,
    sku: "OLDPHONE"
  }
]

Enum.each(products, &Repo.insert!/1)
```

Run the seeds:

```bash
mix run priv/repo/seeds.exs
```

## Step 6: Test Your Table

Start your server and visit your new table:

```bash
mix phx.server
```

Navigate to `http://localhost:4000/products` and you should see:

- ✅ **A fully functional data table** with your products
- ✅ **Sortable columns** - click any column header to sort
- ✅ **Multi-column sorting** - hold Shift and click multiple headers
- ✅ **Search functionality** - type in the search box to filter products
- ✅ **Advanced filters** - toggle active products, adjust price range
- ✅ **Pagination** - if you have many products
- ✅ **Export buttons** - download CSV or PDF reports

## Advanced Example: Custom Query with Joins

For more complex scenarios, you can use custom queries:

```elixir
# lib/your_app_web/live/order_report_live/index.ex
defmodule YourAppWeb.OrderReportLive.Index do
  use YourAppWeb, :live_view
  use LiveTable.LiveResource

  def mount(_params, _session, socket) do
    # Assign your custom data provider function
    socket = assign(socket, :data_provider, {YourApp.Orders, :list_with_products, []})
    {:ok, socket}
  end

  def fields do
    [
      order_id: %{label: "Order #", sortable: true},
      customer_email: %{label: "Customer", sortable: true, searchable: true},
      total_amount: %{label: "Total", sortable: true},
      # Reference the alias used in your custom query
      product_name: %{
        label: "Product", 
        sortable: true, 
        searchable: true,
        assoc: {:order_items, :product_name}
      },
      order_date: %{label: "Date", sortable: true}
    ]
  end

  def filters do
    [
      status: Select.new({:orders, :status}, "status", %{
        label: "Order Status",
        options: [
          %{label: "Pending", value: ["pending"]},
          %{label: "Shipped", value: ["shipped"]},
          %{label: "Delivered", value: ["delivered"]}
        ]
      }),
      
      amount_range: Range.new(:total_amount, "amount_range", %{
        type: :number,
        label: "Order Amount",
        min: 0,
        max: 5000
      })
    ]
  end
end
```

And the corresponding context function:

```elixir
# lib/your_app/orders.ex
defmodule YourApp.Orders do
  import Ecto.Query
  alias YourApp.Repo

  def list_with_products do
    from o in YourApp.Order,
      join: c in YourApp.Customer, on: o.customer_id == c.id,
      join: oi in YourApp.OrderItem, on: oi.order_id == o.id, as: :order_items,
      join: p in YourApp.Product, on: oi.product_id == p.id,
      select: %{
        order_id: o.id,
        customer_email: c.email,
        total_amount: o.total_amount,
        product_name: p.name,  # This field key must match your fields definition
        order_date: o.inserted_at
      }
  end
end
```

## What's Next?

Congratulations! You now have a fully functional LiveTable. Here are some next steps:

### Customize the Appearance
```elixir
def table_options do
  %{
    pagination: %{
      sizes: [5, 10, 25, 50]
    },
    sorting: %{
      default_sort: [name: :asc]  # Only works for single table queries - field must exist in schema
    }
  }
end
```

**Note:** Default sort only works with simple schema fields for single table queries. For custom queries with joins, LiveTable doesn't currently support default sorting on joined fields.

### Override Header Controls

You can override just the header controls (search, per-page, filter toggle) without replacing the entire header.

```elixir
def table_options do
  %{
    custom_controls: {__MODULE__, :my_controls}
  }
end

defp my_controls(assigns) do
  ~H"""
  <.form for={%{}} phx-change="sort">
    <!-- your controls here -->
  </.form>
  """
end
```

Note: If you set `custom_header`, it replaces the whole header; `custom_controls` won’t be used.

### Add Custom Actions

Define actions as component assign items and pass them to `<.live_table>`.

```elixir
# In your LiveView module

def actions do
  %{
    label: "Actions",
    items: [
      edit: &edit_action/1,
      delete: &delete_action/1
    ]
  }
end

# Each action is a 1-arity function component
# It receives assigns with `:record`

defp edit_action(assigns) do
  ~H"""
  <.link 
    navigate={~p"/products/#{@record.id}"} 
    class="text-blue-600 hover:text-blue-800 text-sm"
  >
    Edit
  </.link>
  """
end

defp delete_action(assigns) do
  ~H"""
  <button 
    phx-click="delete" 
    phx-value-id={@record.id}
    class="text-red-600 hover:text-red-800 text-sm"
    data-confirm="Are you sure?"
  >
    Delete
  </button>
  """
end
```

And in your template, pass the actions:

```elixir
<.live_table
  fields={fields()}
  filters={filters()}
  options={@options}
  streams={@streams}
  actions={actions()}
/>
```

### Enable Card View
```elixir
def table_options do
  %{
    mode: :card,
    card_component: &product_card/1
  }
end

defp product_card(assigns) do
  ~H"""
  <div class="bg-white rounded-lg shadow p-6">
    <h3 class="font-semibold text-lg"><%= @record.name %></h3>
    <p class="text-gray-600 text-sm"><%= @record.description %></p>
    <div class="mt-4 flex justify-between items-center">
      <span class="text-lg font-bold text-green-600">
        $<%= @record.price %>
      </span>
      <span class="text-sm text-gray-500">
        Stock: <%= @record.stock_quantity %>
      </span>
    </div>
  </div>
  """
end
```

## Troubleshooting

**Table not showing data?**
- Check that your schema is correct
- Verify you have data in your database
- Ensure the LiveView is properly mounted

**Filters not working?**
- Verify filter field names match your schema
- Check dynamic query syntax in filter conditions
- Ensure Boolean/Range/Select are properly imported

**Sorting not working on custom queries?**
- Make sure field keys in `fields/0` match the select keys in your query
- For joined fields, use `assoc: {:alias_name, :field}` where alias_name matches your query alias

**Styling looks wrong?**
- Ensure your Tailwind CSS build is processing LiveTable's lib directory
- LiveTable depends on [SutraUI](https://github.com/gurujada/sutra_ui) for components

## Learn More

- [Field Configuration](api/fields.md) - Learn about all field options
- [Filter Types](api/filters.md) - Explore Boolean, Range, and Select filters
- [Table Configuration](api/table-options.md) - Customize table behavior
- [Advanced Examples](examples/simple-table.md) - See more complex use cases