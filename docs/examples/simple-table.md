# Simple Table Examples

This guide shows how to create basic LiveTable implementations for common single-schema use cases.

## Basic Product Table

A simple product listing with minimal configuration:

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
      stock_quantity: %{label: "Stock", sortable: true},
      active: %{label: "Status", sortable: true, renderer: &render_status/1}
    ]
  end

  def filters do
    [
      active: Boolean.new(:active, "active", %{
        label: "Active Products Only",
        condition: dynamic([p], p.active == true)
      }),

      price_range: Range.new(:price, "price_range", %{
        type: :number,
        label: "Price Range",
        min: 0,
        max: 1000
      })
    ]
  end

  defp render_status(active) do
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

```elixir
# lib/your_app_web/live/product_live/index.html.heex
<div class="p-6">
  <h1 class="text-2xl font-bold mb-6">Products</h1>

  <.live_table
    fields={fields()}
    filters={filters()}
    options={@options}
    streams={@streams}
  />
</div>
```

## User Management Table

A user listing with role-based rendering:

```elixir
# lib/your_app_web/live/user_live/index.ex
defmodule YourAppWeb.UserLive.Index do
  use YourAppWeb, :live_view
  use LiveTable.LiveResource, schema: YourApp.User

  def fields do
    [
      id: %{label: "ID", sortable: true},
      email: %{label: "Email", sortable: true, searchable: true},
      name: %{label: "Name", sortable: true, searchable: true},
      role: %{label: "Role", sortable: true, renderer: &render_role/1},
      inserted_at: %{label: "Joined", sortable: true, renderer: &render_date/1},
      last_sign_in_at: %{label: "Last Active", sortable: true, renderer: &render_last_active/1}
    ]
  end

  def filters do
    [
      active: Boolean.new(:active, "active", %{
        label: "Active Users Only",
        condition: dynamic([u], u.active == true)
      }),

      role: Select.new(:role, "role", %{
        label: "User Role",
        options: [
          %{label: "Admin", value: ["admin"]},
          %{label: "Manager", value: ["manager"]},
          %{label: "User", value: ["user"]}
        ]
      }),

      signup_date: Range.new(:inserted_at, "signup_range", %{
        type: :date,
        label: "Registration Date",
        min: ~D[2020-01-01],
        max: Date.utc_today()
      })
    ]
  end

  defp render_role(role) do
    assigns = %{role: role}
    ~H"""
    <span class={[
      "px-2 py-1 text-xs font-medium rounded-full uppercase",
      case @role do
        "admin" -> "bg-purple-100 text-purple-700"
        "manager" -> "bg-blue-100 text-blue-700"
        "user" -> "bg-gray-100 text-gray-700"
      end
    ]}>
      <%= @role %>
    </span>
    """
  end

  defp render_date(date) do
    assigns = %{date: date}
    ~H"""
    <span class="text-sm text-gray-600">
      <%= Calendar.strftime(@date, "%b %d, %Y") %>
    </span>
    """
  end

  defp render_last_active(nil) do
    assigns = %{}
    ~H"""
    <span class="text-sm text-gray-400">Never</span>
    """
  end

  defp render_last_active(datetime) do
    assigns = %{datetime: datetime}
    ~H"""
    <span class="text-sm text-gray-600">
      <%= Calendar.strftime(@datetime, "%b %d, %Y at %I:%M %p") %>
    </span>
    """
  end
end
```

## Order History Table

An order listing with status tracking:

```elixir
# lib/your_app_web/live/order_live/index.ex
defmodule YourAppWeb.OrderLive.Index do
  use YourAppWeb, :live_view
  use LiveTable.LiveResource, schema: YourApp.Order

  def fields do
    [
      id: %{label: "Order #", sortable: true},
      customer_email: %{label: "Customer", sortable: true, searchable: true},
      total_amount: %{label: "Total", sortable: true, renderer: &render_currency/1},
      status: %{label: "Status", sortable: true, renderer: &render_order_status/1},
      inserted_at: %{label: "Order Date", sortable: true, renderer: &render_date/1},
    ]
  end

  def filters do
    [
      status: Select.new(:status, "status", %{
        label: "Order Status",
        options: [
          %{label: "Pending", value: ["pending"]},
          %{label: "Processing", value: ["processing"]},
          %{label: "Shipped", value: ["shipped"]},
          %{label: "Delivered", value: ["delivered"]},
          %{label: "Cancelled", value: ["cancelled"]}
        ]
      }),

      order_total: Range.new(:total_amount, "total_range", %{
        type: :number,
        label: "Order Total",
        min: 0,
        max: 5000
      }),

      recent_orders: Boolean.new(:inserted_at, "recent", %{
        label: "Last 30 Days",
        condition: dynamic([o], o.inserted_at >= ago(30, "day"))
      })
    ]
  end

  def table_options do
    %{
      pagination: %{
        enabled: true,
        sizes: [10, 25, 50],
        default_size: 25
      },
      sorting: %{
        default_sort: [inserted_at: :desc]
      },
      exports: %{
        enabled: true,
        formats: [:csv, :pdf]
      }
    }
  end

  defp render_currency(amount) do
    assigns = %{amount: amount}
    ~H"""
    <span class="font-mono text-green-600">
      $<%= :erlang.float_to_binary(@amount, decimals: 2) %>
    </span>
    """
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
          "shipped" -> "bg-purple-400"
          "delivered" -> "bg-green-400"
          "cancelled" -> "bg-red-400"
        end
      ]}></div>
      <span class="capitalize text-sm"><%= @status %></span>
    </div>
    """
  end

  defp render_date(date) do
    assigns = %{date: date}
    ~H"""
    <span class="text-sm">
      <%= Calendar.strftime(@date, "%b %d, %Y") %>
    </span>
    """
  end

  # Actions are provided via the component assign, not as a field.
  def actions do
    %{
      label: "Actions",
      items: [
        view: &order_view_action/1,
        cancel: &order_cancel_action/1
      ]
    }
  end

  defp order_view_action(assigns) do
    ~H"""
    <.link
      navigate={~p"/orders/#{@record.id}"}>
      View
    </.link>
    """
  end

  defp order_cancel_action(assigns) do
    ~H"""
    <%= if @record.status in ["pending", "processing"] do %>
      <button
        phx-click="cancel_order"
        phx-value-id={@record.id}
        class="text-red-600 hover:text-red-800 text-sm font-medium"
        data-confirm="Are you sure you want to cancel this order?"
      >
        Cancel
      </button>
    <% end %>
    """
  end

  def handle_event("cancel_order", %{"id" => id}, socket) do
    order = YourApp.Orders.get_order!(id)
    case YourApp.Orders.cancel_order(order) do
      {:ok, _order} ->
        {:noreply, put_flash(socket, :info, "Order cancelled successfully")}
      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Unable to cancel order")}
    end
  end
end
```

```elixir
# lib/your_app_web/live/order_live/index.html.heex
<div class="p-6">
  <h1 class="text-2xl font-bold mb-6">Orders</h1>
  <.live_table
    fields={fields()}
    filters={filters()}
    actions={actions()}
    options={@options}
    streams={@streams}
  />
</div>
```

## Inventory Management Table

A product inventory table with stock alerts:

```elixir
# lib/your_app_web/live/inventory_live/index.ex
defmodule YourAppWeb.InventoryLive.Index do
  use YourAppWeb, :live_view
  use LiveTable.LiveResource, schema: YourApp.Product

  def fields do
    [
      sku: %{label: "SKU", sortable: true, searchable: true},
      name: %{label: "Product", sortable: true, searchable: true},
      stock_quantity: %{label: "Current Stock", sortable: true, renderer: &render_stock/2},
      reorder_point: %{label: "Reorder Point", sortable: true},
      last_restocked: %{label: "Last Restocked", sortable: true, renderer: &render_date/1},
      supplier_name: %{label: "Supplier", sortable: true, searchable: true},
    ]
  end

  def filters do
    [
      low_stock: Boolean.new(:stock_quantity, "low_stock", %{
        label: "Low Stock Alert",
        condition: dynamic([p], p.stock_quantity <= p.reorder_point)
      }),

      out_of_stock: Boolean.new(:stock_quantity, "out_of_stock", %{
        label: "Out of Stock",
        condition: dynamic([p], p.stock_quantity == 0)
      }),

      stock_range: Range.new(:stock_quantity, "stock_range", %{
        type: :number,
        label: "Stock Quantity",
        min: 0,
        max: 1000
      }),

      needs_reorder: Boolean.new(:stock_quantity, "needs_reorder", %{
        label: "Needs Reorder",
        condition: dynamic([p], p.stock_quantity <= p.reorder_point and p.stock_quantity > 0)
      })
    ]
  end

  def table_options do
    %{
      pagination: %{
        enabled: true,
        sizes: [20, 50, 100],
        default_size: 50
      },
      sorting: %{
        default_sort: [stock_quantity: :asc]  # Show low stock first
      },
      exports: %{
        enabled: true,
        formats: [:csv]
      }
    }
  end

  defp render_stock(stock_quantity, record) do
    assigns = %{stock: stock_quantity, record: record}
    ~H"""
    <div class="flex items-center gap-2">
      <span class={[
        "font-medium",
        cond do
          @stock == 0 -> "text-red-600"
          @stock <= @record.reorder_point -> "text-orange-600"
          @stock <= @record.reorder_point * 2 -> "text-yellow-600"
          true -> "text-green-600"
        end
      ]}>
        <%= @stock %>
      </span>

      <%= cond do %>
        <% @stock == 0 -> %>
          <span class="bg-red-100 text-red-700 text-xs px-2 py-1 rounded">OUT</span>
        <% @stock <= @record.reorder_point -> %>
          <span class="bg-orange-100 text-orange-700 text-xs px-2 py-1 rounded">LOW</span>
        <% @stock <= @record.reorder_point * 2 -> %>
          <span class="bg-yellow-100 text-yellow-700 text-xs px-2 py-1 rounded">WATCH</span>
        <% true -> %>
          <span class="bg-green-100 text-green-700 text-xs px-2 py-1 rounded">OK</span>
      <% end %>
    </div>
    """
  end

  defp render_date(nil) do
    assigns = %{}
    ~H"""
    <span class="text-gray-400 text-sm">Never</span>
    """
  end

  defp render_date(date) do
    assigns = %{date: date}
    ~H"""
    <span class="text-sm">
      <%= Calendar.strftime(@date, "%b %d, %Y") %>
    </span>
    """
  end

  # Inventory actions via component assign
  def actions do
    %{
      label: "Actions",
      items: [
        restock: &restock_action/1,
        auto_reorder: &auto_reorder_action/1,
        adjust: &adjust_action/1
      ]
    }
  end

  defp restock_action(assigns) do
    ~H"""
    <button
      phx-click="restock"
      phx-value-id={@record.id}
      class="bg-blue-600 text-white px-3 py-1 rounded text-sm hover:bg-blue-700"
    >
      Restock
    </button>
    """
  end

  defp auto_reorder_action(assigns) do
    ~H"""
    <%= if @record.stock_quantity <= @record.reorder_point do %>
      <button
        phx-click="auto_reorder"
        phx-value-id={@record.id}
        class="bg-green-600 text-white px-3 py-1 rounded text-sm hover:bg-green-700"
      >
        Auto Reorder
      </button>
    <% end %>
    """
  end

  defp adjust_action(assigns) do
    ~H"""
    <.link
      navigate={~p"/inventory/#{@record.id}/adjust"}
      class="text-gray-600 hover:text-gray-800 text-sm"
    >
      Adjust
    </.link>
    """
  end

  def handle_event("restock", %{"id" => id}, socket) do
    # Handle manual restock
    {:noreply, redirect(socket, to: ~p"/inventory/#{id}/restock")}
  end

  def handle_event("auto_reorder", %{"id" => id}, socket) do
    product = YourApp.Inventory.get_product!(id)
    case YourApp.Inventory.create_reorder(product) do
      {:ok, _reorder} ->
        {:noreply, put_flash(socket, :info, "Reorder created successfully")}
      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to create reorder")}
    end
  end
end
```

```elixir
# lib/your_app_web/live/inventory_live/index.html.heex
<div class="p-6">
  <h1 class="text-2xl font-bold mb-6">Inventory</h1>
  <.live_table
    fields={fields()}
    filters={filters()}
    actions={actions()}
    options={@options}
    streams={@streams}
  />
</div>
```

## Simple Read-Only Table

A minimal table for displaying reference data:

```elixir
# lib/your_app_web/live/category_live/index.ex
defmodule YourAppWeb.CategoryLive.Index do
  use YourAppWeb, :live_view
  use LiveTable.LiveResource, schema: YourApp.Category

  def fields do
    [
      id: %{label: "ID", sortable: true},
      name: %{label: "Category Name", sortable: true, searchable: true},
      description: %{label: "Description", searchable: true},
      product_count: %{label: "Products", sortable: true, renderer: &render_count/1},
      active: %{label: "Status", sortable: true, renderer: &render_active_status/1}
    ]
  end

  def filters do
    [
      active: Boolean.new(:active, "active", %{
        label: "Active Categories Only",
        condition: dynamic([c], c.active == true)
      })
    ]
  end

  def table_options do
    %{
      pagination: %{enabled: false},  # Show all categories
      sorting: %{default_sort: [name: :asc]},
      exports: %{enabled: false},     # No exports needed
      search: %{
        enabled: true,
        placeholder: "Search categories..."
      }
    }
  end

  defp render_count(count) do
    assigns = %{count: count}
    ~H"""
    <span class="bg-gray-100 text-gray-700 px-2 py-1 rounded text-sm">
      <%= @count %>
    </span>
    """
  end

  defp render_active_status(active) do
    assigns = %{active: active}
    ~H"""
    <span class={[
      "w-3 h-3 rounded-full inline-block",
      if(@active, do: "bg-green-400", else: "bg-gray-300")
    ]}></span>
    """
  end
end
```

## Key Patterns for Simple Tables

### 1. Minimal Setup
- Use the LiveResource module with `schema:` parameter
- Define basic fields with labels and sortability
- Add simple filters for common use cases

### 2. Custom Renderers
- Use `renderer: &function/1` for simple formatting
- Use `renderer: &function/2` when you need access to the full record
- Keep renderers focused and lightweight

### 3. Practical Filters
- Boolean filters for status toggles
- Range filters for numeric and date fields
- Select filters for enumerated values

### 4. Sensible Defaults
- Enable pagination for large datasets
- Set reasonable default sort orders
- Configure exports based on user needs

### 5. Row Actions
- Provide row actions via the component assign, not as a field.
- Accept either a list of `{key, component}` tuples or a map `%{label: binary, items: list}`.
- Each action component is a 1-arity function and receives assigns with `:record`.
- In your HEEx template, pass the actions assign: `<.live_table fields={fields()} filters={filters()} actions={actions()} options={@options} streams={@streams} />`.
- If you need interactive UI inside a data cell, use a field renderer or component for that cell — actions are specifically for the dedicated actions column.

These examples demonstrate how LiveTable handles common table requirements with minimal code while providing a clear pattern for row-level actions.
