# Fields API Reference

Fields define the columns displayed in your LiveTable. They control what data is shown, how it's formatted, and whether columns can be sorted or searched.

## Overview

Fields are defined in the `fields/0` function as a keyword list where each key represents a column and maps to configuration options.

```elixir
def fields do
  [
    id: %{label: "ID", sortable: true},
    name: %{label: "Product Name", sortable: true, searchable: true},
    price: %{label: "Price", sortable: true, renderer: &format_price/1}
  ]
end
```

## Field Configuration Options

### Required Options

#### `label` (string)
The display name for the column header and exports.

```elixir
name: %{label: "Product Name"}
```

#### `sortable` (boolean)
Whether the column can be sorted. Adds clickable sort controls to the header.

```elixir
price: %{label: "Price", sortable: true}
```

#### `searchable` (boolean)
Whether the column is included in global text search using ILIKE matching.

```elixir
name: %{label: "Name", searchable: true}
```

### Optional Options

#### `renderer` (function)
Custom function component for formatting cell display. You can use either:

- **`function/1`** - Receives only the cell value
- **`function/2`** - Receives the cell value and the entire record

```elixir
# Using function/1 - only gets the cell value
status: %{
  label: "Status", 
  renderer: &format_status/1
}

defp format_status(status) do
  assigns = %{status: status}
  ~H"""
  <span class={status_class(@status)}>
    <%= String.capitalize(@status) %>
  </span>
  """
end

# Using function/2 - gets cell value AND entire record
priority: %{
  label: "Priority",
  renderer: &format_priority_with_context/2
}

defp format_priority_with_context(priority, record) do
  assigns = %{priority: priority, record: record}
  ~H"""
  <div class="flex items-center gap-2">
    <span class={priority_class(@priority)}>
      <%= String.upcase(@priority) %>
    </span>
    <%= if @record.is_urgent do %>
      <span class="text-red-500 text-xs">URGENT</span>
    <% end %>
  </div>
  """
end
```

#### `component` (function)
Alternative to `renderer` - a function component that receives assigns with `:value` and `:record`.

```elixir
status: %{
  label: "Status",
  component: &status_badge/1
}

defp status_badge(assigns) do
  ~H"""
  <span class={[
    "px-2 py-1 rounded-full text-xs font-medium",
    status_color(@value)
  ]}>
    <%= @value %>
  </span>
  """
end

defp status_color("active"), do: "bg-green-100 text-green-800"
defp status_color("pending"), do: "bg-yellow-100 text-yellow-800"
defp status_color(_), do: "bg-gray-100 text-gray-800"
```

**Difference from `renderer`:**
- `renderer` receives the value directly (and optionally the record as second arg)
- `component` receives assigns map with `@value` and `@record` keys

#### `empty_text` (string)
Text to display when the cell value is `nil`.

```elixir
price: %{
  label: "Price",
  sortable: true,
  empty_text: "N/A"
}

description: %{
  label: "Description",
  empty_text: "No description provided"
}

discount: %{
  label: "Discount",
  empty_text: "-"
}
```

**Notes:**
- Defaults to empty string if not specified
- Useful for optional fields where `nil` is meaningful
- Works with or without custom renderers

#### `computed` (dynamic query)
Define calculated fields using Ecto dynamic expressions.

```elixir
total_value: %{
  label: "Total Value",
  sortable: true,
  computed: dynamic([r], fragment("? * ?", r.price, r.quantity))
}
```

#### `assoc` (tuple) - For Custom Queries Only
When using custom queries with joins, specify the table alias used in your query.

```elixir
# Only needed when you have a custom query with joins
customer_name: %{
  label: "Customer",
  sortable: true,
  searchable: true,
  assoc: {:customers, :name}  # :customers must match your query alias
}
```

## Usage Patterns

### Simple Tables (Single Schema)

For basic tables querying a single schema, just reference the schema fields directly:

```elixir
defmodule YourAppWeb.ProductLive.Index do
  use YourAppWeb, :live_view
  use LiveTable.LiveResource, schema: YourApp.Product

  def fields do
    [
      id: %{label: "ID", sortable: true},
      name: %{label: "Product Name", sortable: true, searchable: true},
      price: %{label: "Price", sortable: true},
      stock_quantity: %{label: "Stock", sortable: true},
      active: %{label: "Active", sortable: true, renderer: &render_boolean/1}
    ]
  end
end
```

### Custom Queries with Joins

For complex scenarios with joins, provide a custom data provider and reference aliases:

```elixir
defmodule YourAppWeb.OrderReportLive.Index do
  use YourAppWeb, :live_view
  use LiveTable.LiveResource

  def mount(_params, _session, socket) do
    socket = assign(socket, :data_provider, {YourApp.Orders, :list_with_details, []})
    {:ok, socket}
  end

  def fields do
    [
      order_id: %{label: "Order #", sortable: true},
      customer_email: %{label: "Customer", sortable: true, searchable: true},
      total_amount: %{label: "Total", sortable: true},
      # Reference the alias from your custom query
      product_name: %{
        label: "Product", 
        sortable: true, 
        searchable: true,
        assoc: {:order_items, :product_name}
      }
    ]
  end
end
```

The corresponding context function must use matching aliases:

```elixir
defmodule YourApp.Orders do
  def list_with_details do
    from o in Order,
      join: c in Customer, on: o.customer_id == c.id,
      join: oi in OrderItem, on: oi.order_id == o.id, as: :order_items,
      join: p in Product, on: oi.product_id == p.id,
      select: %{
        order_id: o.id,
        customer_email: c.email,
        total_amount: o.total_amount,
        product_name: p.name  # Field key must match
      }
  end
end
```

## Computed Fields

Create calculated fields using database functions:

```elixir
def fields do
  [
    # Simple calculation
    total_value: %{
      label: "Total Value",
      sortable: true,
      computed: dynamic([r], fragment("? * ?", r.price, r.stock_quantity))
    },
    
    # Conditional logic
    stock_status: %{
      label: "Stock Status",
      sortable: true,
      computed: dynamic([r], 
        fragment("CASE WHEN ? > 50 THEN 'High' WHEN ? > 10 THEN 'Medium' ELSE 'Low' END", 
                 r.stock_quantity, r.stock_quantity)
      )
    },
    
    # Using joined tables (for custom queries)
    category_product_count: %{
      label: "Products in Category",
      sortable: true,
      assoc: {:categories, :name},  # Must match your query alias
      computed: dynamic([r, categories: c], 
        fragment("(SELECT COUNT(*) FROM products WHERE category_id = ?)", c.id)
      )
    }
  ]
end
```

## Custom Renderers

Transform how data appears in your table cells:

### Simple Formatting (function/1)

```elixir
def fields do
  [
    price: %{
      label: "Price",
      sortable: true,
      renderer: &format_currency/1
    },
    created_at: %{
      label: "Created",
      sortable: true,
      renderer: &format_date/1
    }
  ]
end

defp format_currency(amount) do
  assigns = %{amount: amount}
  ~H"""
  <span class="font-mono text-green-600">
    $<%= :erlang.float_to_binary(@amount, decimals: 2) %>
  </span>
  """
end

defp format_date(datetime) do
  assigns = %{datetime: datetime}
  ~H"""
  <time datetime={DateTime.to_iso8601(@datetime)} class="text-sm text-gray-600">
    <%= Calendar.strftime(@datetime, "%b %d, %Y") %>
  </time>
  """
end
```

### Status Indicators

```elixir
def fields do
  [
    status: %{
      label: "Order Status",
      renderer: &render_order_status/1
    },
    priority: %{
      label: "Priority",
      renderer: &render_priority_badge/1  
    }
  ]
end

defp render_order_status(status) do
  assigns = %{status: status}
  ~H"""
  <div class="flex items-center gap-2">
    <div class={[
      "w-2 h-2 rounded-full",
      case @status do
        "pending" -> "bg-yellow-400"
        "processing" -> "bg-blue-400" 
        "shipped" -> "bg-green-400"
        "delivered" -> "bg-green-600"
        "cancelled" -> "bg-red-400"
      end
    ]}></div>
    <span class="capitalize text-sm"><%= @status %></span>
  </div>
  """
end

defp render_priority_badge(priority) do
  assigns = %{priority: priority}
  ~H"""
  <span class={[
    "px-2 py-1 text-xs font-medium rounded-full",
    case @priority do
      "high" -> "bg-red-100 text-red-700"
      "medium" -> "bg-yellow-100 text-yellow-700"  
      "low" -> "bg-green-100 text-green-700"
    end
  ]}>
    <%= String.upcase(@priority) %>
  </span>
  """
end
```

### Interactive Elements (function/2)

```elixir
def fields do
  [
    primary_action: %{
      label: "Action",
      sortable: false,
      renderer: &render_primary_action/2  # function/2 to access full record
    }
  ]
end

defp render_primary_action(_value, record) do
  assigns = %{record: record}
  ~H"""
  <.link 
    navigate={~p"/products/#{@record.id}"} 
    class="text-blue-600 hover:text-blue-800 text-sm font-medium"
  >
    View
  </.link>
  """
end
```

Note: For row actions like edit/delete, use the component's `actions` assign instead of defining an `actions` field. Example:

```elixir
<.live_table ... actions={%{label: "Actions", items: [edit: &edit_action/1, delete: &delete_action/1]}} />
```

### Conditional Rendering with Context (function/2)

```elixir
def fields do
  [
    stock_status: %{
      label: "Stock",
      sortable: true,
      renderer: &render_stock_with_alerts/2
    }
  ]
end

defp render_stock_with_alerts(stock_quantity, record) do
  assigns = %{stock: stock_quantity, record: record}
  ~H"""
  <div class="flex items-center gap-2">
    <span class={[
      "font-medium",
      cond do
        @stock > 50 -> "text-green-600"
        @stock > 10 -> "text-yellow-600"
        @stock > 0 -> "text-orange-600"
        true -> "text-red-600"
      end
    ]}>
      <%= @stock %> in stock
    </span>
    
    <%= if @record.reorder_point && @stock <= @record.reorder_point do %>
      <span class="bg-yellow-100 text-yellow-800 text-xs px-2 py-1 rounded">
        Reorder needed
      </span>
    <% end %>
    
    <%= if @record.category == "perishable" && @stock > 0 do %>
      <span class="text-blue-600 text-xs">
        Expires: <%= @record.expiry_date %>
      </span>
    <% end %>
  </div>
  """
end
```

## Common Patterns

### E-commerce Product Table

```elixir
def fields do
  [
    image: %{
      label: "Image",
      sortable: false,
      renderer: &render_product_image/1
    },
    name: %{
      label: "Product",
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
      renderer: &format_currency/1
    },
    stock: %{
      label: "Stock",
      sortable: true,
      renderer: &render_stock_status/1
    },
    status: %{
      label: "Status",
      sortable: true,
      renderer: &render_product_status/1
    }
  ]
end

defp render_product_image(image_url) do
  assigns = %{image_url: image_url}
  ~H"""
  <img src={@image_url} alt="Product" class="w-12 h-12 object-cover rounded" />
  """
end

defp render_stock_status(quantity) do
  assigns = %{quantity: quantity}
  ~H"""
  <span class={[
    "text-sm font-medium",
    cond do
      @quantity > 50 -> "text-green-600"
      @quantity > 10 -> "text-yellow-600"
      @quantity > 0 -> "text-orange-600"
      true -> "text-red-600"
    end
  ]}>
    <%= @quantity %> in stock
  </span>
  """
end
```

### User Management Table

```elixir
def fields do
  [
    avatar: %{
      label: "",
      sortable: false,
      renderer: &render_avatar/1
    },
    name: %{
      label: "Name",
      sortable: true,
      searchable: true
    },
    email: %{
      label: "Email",
      sortable: true,
      searchable: true
    },
    role: %{
      label: "Role",
      sortable: true,
      renderer: &render_role_badge/1
    },
    last_sign_in: %{
      label: "Last Active",
      sortable: true,
      renderer: &format_relative_time/1
    },
    active: %{
      label: "Status",
      sortable: true,
      renderer: &render_user_status/1
    }
  ]
end

defp render_avatar(user) do
  assigns = %{user: user}
  ~H"""
  <div class="flex items-center">
    <img src={@user.avatar_url || "/images/default-avatar.png"} 
         alt={@user.name} 
         class="w-8 h-8 rounded-full" />
  </div>
  """
end

defp render_role_badge(role) do
  assigns = %{role: role}
  ~H"""
  <span class={[
    "px-2 py-1 text-xs font-medium rounded-full",
    case @role do
      "admin" -> "bg-purple-100 text-purple-700"
      "manager" -> "bg-blue-100 text-blue-700"
      "user" -> "bg-gray-100 text-gray-700"
    end
  ]}>
    <%= String.capitalize(@role) %>
  </span>
  """
end
```

## Key Rules

### For Simple Tables (Single Schema)
1. Use the LiveResource with `schema: YourSchema`
2. Field keys must match your schema attributes
3. No `assoc:` needed - LiveTable handles everything

### For Custom Queries
1. Use the LiveResource (no schema)
2. Assign `:data_provider` in mount/handle_params
3. Field keys must match your query's select keys
4. Use `assoc: {:alias_name, :field}` only for sorting joined fields
5. The alias_name must match your query's `as:` alias

### Troubleshooting

**Field not displaying?**
- For simple tables: ensure field key matches schema attribute
- For custom queries: ensure field key matches select key in your query

**Sorting not working?**
- Confirm `sortable: true` is set
- For custom queries with joins: use `assoc: {:alias, :field}` where alias matches your query

**Search not finding results?**
- Verify `searchable: true` is set
- Search only works on text/string fields
- For custom queries: searchable fields must be in your select clause

## Actions

Actions provide row-level operations like edit, delete, or custom actions. Unlike fields, actions are passed directly to the `<.live_table>` component.

### Basic Actions

```elixir
# In your LiveView
def actions do
  [
    edit: &edit_action/1,
    delete: &delete_action/1
  ]
end

defp edit_action(assigns) do
  ~H"""
  <.link navigate={~p"/products/#{@record.id}/edit"} class="text-blue-600 hover:text-blue-800">
    Edit
  </.link>
  """
end

defp delete_action(assigns) do
  ~H"""
  <.link
    phx-click="delete"
    phx-value-id={@record.id}
    data-confirm="Are you sure?"
    class="text-red-600 hover:text-red-800"
  >
    Delete
  </.link>
  """
end
```

```heex
<%# In your template %>
<.live_table
  fields={fields()}
  filters={filters()}
  options={@options}
  streams={@streams}
  actions={actions()}
/>
```

### Actions with Label

Use a map format to customize the column header:

```elixir
def actions do
  %{
    label: "Actions",  # Column header text
    items: [
      edit: &edit_action/1,
      delete: &delete_action/1,
      view: &view_action/1
    ]
  }
end
```

### Action Component Assigns

Each action component receives assigns with:
- `@record` - The full record for that row

```elixir
defp view_action(assigns) do
  ~H"""
  <.link navigate={~p"/products/#{@record.id}"}>
    View <%= @record.name %>
  </.link>
  """
end
```

### Conditional Actions

Show/hide actions based on record state:

```elixir
defp publish_action(assigns) do
  ~H"""
  <button
    :if={!@record.published}
    phx-click="publish"
    phx-value-id={@record.id}
    class="text-green-600 hover:text-green-800"
  >
    Publish
  </button>
  <span :if={@record.published} class="text-gray-400">Published</span>
  """
end

defp archive_action(assigns) do
  ~H"""
  <button
    :if={@record.status != "archived"}
    phx-click="archive"
    phx-value-id={@record.id}
    class="text-yellow-600 hover:text-yellow-800"
  >
    Archive
  </button>
  """
end
```

### Dropdown Actions

For many actions, use a dropdown menu:

```elixir
defp actions_dropdown(assigns) do
  ~H"""
  <div class="relative" x-data="{ open: false }">
    <button @click="open = !open" class="text-gray-500 hover:text-gray-700">
      <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
        <path d="M10 6a2 2 0 110-4 2 2 0 010 4zM10 12a2 2 0 110-4 2 2 0 010 4zM10 18a2 2 0 110-4 2 2 0 010 4z" />
      </svg>
    </button>
    <div x-show="open" @click.away="open = false" class="absolute right-0 mt-2 w-48 bg-white rounded-md shadow-lg z-10">
      <.link navigate={~p"/products/#{@record.id}"} class="block px-4 py-2 hover:bg-gray-100">
        View
      </.link>
      <.link navigate={~p"/products/#{@record.id}/edit"} class="block px-4 py-2 hover:bg-gray-100">
        Edit
      </.link>
      <button phx-click="duplicate" phx-value-id={@record.id} class="block w-full text-left px-4 py-2 hover:bg-gray-100">
        Duplicate
      </button>
      <hr class="my-1" />
      <button phx-click="delete" phx-value-id={@record.id} class="block w-full text-left px-4 py-2 text-red-600 hover:bg-red-50">
        Delete
      </button>
    </div>
  </div>
  """
end

def actions do
  %{
    label: "",  # No header for dropdown column
    items: [
      menu: &actions_dropdown/1
    ]
  }
end
```

### Handling Action Events

Handle action events in your LiveView:

```elixir
def handle_event("delete", %{"id" => id}, socket) do
  product = Products.get_product!(id)
  {:ok, _} = Products.delete_product(product)
  
  {:noreply, 
   socket
   |> put_flash(:info, "Product deleted")
   |> push_navigate(to: ~p"/products")}
end

def handle_event("publish", %{"id" => id}, socket) do
  product = Products.get_product!(id)
  {:ok, _} = Products.update_product(product, %{published: true})
  
  {:noreply, put_flash(socket, :info, "Product published")}
end
```