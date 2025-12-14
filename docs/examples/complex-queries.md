# Complex Query Examples

This guide demonstrates how to use LiveTable with custom queries, joins, computed fields, and advanced data transformations.

## Order Report with Customer Details

A comprehensive order report joining multiple tables:

```elixir
# lib/your_app_web/live/order_report_live/index.ex
defmodule YourAppWeb.OrderReportLive.Index do
  use YourAppWeb, :live_view
  use LiveTable.LiveResource

  def mount(_params, _session, socket) do
    socket = assign(socket, :data_provider, {YourApp.Reports, :order_details, []})
    {:ok, socket}
  end

  def fields do
    [
      order_id: %{label: "Order #", sortable: true},
      customer_name: %{label: "Customer", sortable: true, searchable: true},
      customer_email: %{label: "Email", sortable: true, searchable: true},
      product_count: %{label: "Items", sortable: true},
      total_amount: %{label: "Total", sortable: true, renderer: &render_currency/1},
      order_date: %{label: "Order Date", sortable: true, renderer: &render_date/1},
      shipping_method: %{
        label: "Shipping", 
        sortable: true,
        assoc: {:shipping, :method}
      },
      status: %{label: "Status", sortable: true, renderer: &render_status/1},
      days_since_order: %{label: "Age (Days)", sortable: true, renderer: &render_days/1}
    ]
  end

  def filters do
    [
      status: Select.new({:orders, :status}, "status", %{
        label: "Order Status",
        options: [
          %{label: "Pending", value: ["pending"]},
          %{label: "Processing", value: ["processing"]},
          %{label: "Shipped", value: ["shipped"]},
          %{label: "Delivered", value: ["delivered"]}
        ]
      }),
      
      order_value: Range.new(:total_amount, "order_value", %{
        type: :number,
        label: "Order Value",
        min: 0,
        max: 10000,
        step: 100
      }),
      
      customer_type: Select.new({:customers, :type}, "customer_type", %{
        label: "Customer Type",
        options: [
          %{label: "Individual", value: ["individual"]},
          %{label: "Business", value: ["business"]}
        ]
      }),
      
      recent_orders: Boolean.new(:order_date, "recent", %{
        label: "Last 30 Days",
        condition: dynamic([o, customers: c, shipping: s], o.inserted_at >= ago(30, "day"))
      })
    ]
  end

  defp render_currency(amount) do
    assigns = %{amount: amount}
    ~H"""
    <span class="font-mono text-green-600">$<%= :erlang.float_to_binary(@amount, decimals: 2) %></span>
    """
  end

  defp render_date(date) do
    assigns = %{date: date}
    ~H"""
    <span class="text-sm"><%= Calendar.strftime(@date, "%b %d, %Y") %></span>
    """
  end

  defp render_status(status) do
    assigns = %{status: status}
    ~H"""
    <span class={[
      "px-2 py-1 text-xs font-medium rounded-full",
      case @status do
        "pending" -> "bg-yellow-100 text-yellow-700"
        "processing" -> "bg-blue-100 text-blue-700"
        "shipped" -> "bg-purple-100 text-purple-700"
        "delivered" -> "bg-green-100 text-green-700"
      end
    ]}>
      <%= String.capitalize(@status) %>
    </span>
    """
  end

  defp render_days(days) do
    assigns = %{days: days}
    ~H"""
    <span class={[
      "text-sm",
      if(@days > 30, do: "text-red-600", else: "text-gray-600")
    ]}>
      <%= @days %> days
    </span>
    """
  end
end
```

The corresponding context function:

```elixir
# lib/your_app/reports.ex
defmodule YourApp.Reports do
  import Ecto.Query
  alias YourApp.Repo

  def order_details do
    from o in YourApp.Order,
      join: c in YourApp.Customer, on: o.customer_id == c.id, as: :customers,
      join: s in YourApp.ShippingMethod, on: o.shipping_method_id == s.id, as: :shipping,
      left_join: oi in YourApp.OrderItem, on: oi.order_id == o.id,
      group_by: [o.id, c.id, s.id],
      select: %{
        order_id: o.id,
        customer_name: fragment("? || ' ' || ?", c.first_name, c.last_name),
        customer_email: c.email,
        product_count: count(oi.id),
        total_amount: o.total_amount,
        order_date: o.inserted_at,
        shipping_method: s.name,
        status: o.status,
        days_since_order: fragment("DATE_PART('day', NOW() - ?)", o.inserted_at)
      }
  end
end
```

## Product Analytics with Sales Data

Advanced product performance analytics:

```elixir
# lib/your_app_web/live/product_analytics_live/index.ex
defmodule YourAppWeb.ProductAnalyticsLive.Index do
  use YourAppWeb, :live_view
  use LiveTable.LiveResource

  def mount(%{"period" => period}, _session, socket) do
    data_provider = {YourApp.Analytics, :product_performance, [period]}
    socket = assign(socket, :data_provider, data_provider)
    {:ok, socket}
  end

  def mount(_params, _session, socket) do
    mount(%{"period" => "30"}, nil, socket)
  end

  def fields do
    [
      product_name: %{label: "Product", sortable: true, searchable: true},
      sku: %{label: "SKU", sortable: true, searchable: true},
      category_name: %{
        label: "Category", 
        sortable: true,
        assoc: {:categories, :name}
      },
      units_sold: %{label: "Units Sold", sortable: true},
      revenue: %{label: "Revenue", sortable: true, renderer: &render_currency/1},
      avg_order_value: %{label: "AOV", sortable: true, renderer: &render_currency/1},
      profit_margin: %{label: "Margin %", sortable: true, renderer: &render_percentage/1},
      conversion_rate: %{label: "Conv. Rate", sortable: true, renderer: &render_percentage/1},
      stock_turns: %{label: "Stock Turns", sortable: true, renderer: &render_decimal/1},
      performance_score: %{label: "Score", sortable: true, renderer: &render_score/1}
    ]
  end

  def filters do
    [
      category: Select.new({:categories, :name}, "category", %{
        label: "Category",
        options_source: {YourApp.Catalog, :list_categories, []}
      }),
      
      revenue_range: Range.new(:revenue, "revenue_range", %{
        type: :number,
        label: "Revenue Range",
        min: 0,
        max: 100000,
        step: 1000
      }),
      
      high_performers: Boolean.new(:performance_score, "high_performers", %{
        label: "High Performers (Score > 80)",
        condition: dynamic([p, categories: c], p.performance_score > 80)
      }),
      
      low_margin: Boolean.new(:profit_margin, "low_margin", %{
        label: "Low Margin (< 20%)",
        condition: dynamic([p, categories: c], p.profit_margin < 20)
      })
    ]
  end

  def table_options do
    %{
      pagination: %{
        enabled: true,
        sizes: [25, 50, 100],
        default_size: 50
      },
      sorting: %{
        default_sort: [performance_score: :desc, revenue: :desc]
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
    <span class="font-mono text-green-600">$<%= :erlang.float_to_binary(@amount, decimals: 2) %></span>
    """
  end

  defp render_percentage(value) do
    assigns = %{value: value}
    ~H"""
    <span class={[
      "font-medium",
      if(@value >= 20, do: "text-green-600", else: "text-red-600")
    ]}>
      <%= :erlang.float_to_binary(@value, decimals: 1) %>%
    </span>
    """
  end

  defp render_decimal(value) do
    assigns = %{value: value}
    ~H"""
    <span class="text-sm"><%= :erlang.float_to_binary(@value, decimals: 2) %></span>
    """
  end

  defp render_score(score) do
    assigns = %{score: score}
    ~H"""
    <div class="flex items-center gap-2">
      <div class="w-12 bg-gray-200 rounded-full h-2">
        <div 
          class={[
            "h-2 rounded-full",
            cond do
              @score >= 80 -> "bg-green-500"
              @score >= 60 -> "bg-yellow-500"
              true -> "bg-red-500"
            end
          ]}
          style={"width: #{@score}%"}
        ></div>
      </div>
      <span class="text-sm font-medium"><%= round(@score) %></span>
    </div>
    """
  end
end
```

Complex analytics context:

```elixir
# lib/your_app/analytics.ex
defmodule YourApp.Analytics do
  import Ecto.Query
  alias YourApp.Repo

  def product_performance(days \\ 30) do
    cutoff_date = Date.add(Date.utc_today(), -days)
    
    from p in YourApp.Product,
      join: c in YourApp.Category, on: p.category_id == c.id, as: :categories,
      left_join: oi in YourApp.OrderItem, on: oi.product_id == p.id,
      left_join: o in YourApp.Order, on: oi.order_id == o.id and o.inserted_at >= ^cutoff_date,
      left_join: v in YourApp.ProductView, on: v.product_id == p.id and v.inserted_at >= ^cutoff_date,
      group_by: [p.id, c.id],
      select: %{
        product_name: p.name,
        sku: p.sku,
        category_name: c.name,
        units_sold: coalesce(sum(oi.quantity), 0),
        revenue: coalesce(sum(fragment("? * ?", oi.quantity, oi.unit_price)), 0.0),
        avg_order_value: fragment("CASE WHEN COUNT(DISTINCT ?) > 0 THEN ? / COUNT(DISTINCT ?) ELSE 0 END", 
                                 o.id, coalesce(sum(fragment("? * ?", oi.quantity, oi.unit_price)), 0.0), o.id),
        profit_margin: fragment("CASE WHEN ? > 0 THEN ((? - ?) / ?) * 100 ELSE 0 END",
                               p.price, p.price, p.cost_price, p.price),
        conversion_rate: fragment("CASE WHEN COUNT(?) > 0 THEN (COUNT(DISTINCT ?) * 100.0 / COUNT(?)) ELSE 0 END",
                                 v.id, o.id, v.id),
        stock_turns: fragment("CASE WHEN ? > 0 THEN ? / ? ELSE 0 END",
                             p.stock_quantity, coalesce(sum(oi.quantity), 0), p.stock_quantity),
        performance_score: fragment("""
          LEAST(100, GREATEST(0, 
            (CASE WHEN ? > 0 THEN ? / ? * 20 ELSE 0 END) +
            (CASE WHEN ? > 0 THEN LEAST(20, ? / 1000 * 20) ELSE 0 END) +
            (CASE WHEN ? > 0 THEN ? / 50 * 20 ELSE 0 END) +
            (CASE WHEN ? > 0 THEN ? / 5 * 20 ELSE 0 END) +
            (CASE WHEN ? > 10 THEN 20 ELSE ? / 10 * 20 END)
          ))
        """,
        # Stock turns score (0-20)
        p.stock_quantity, coalesce(sum(oi.quantity), 0), p.stock_quantity,
        # Revenue score (0-20)
        coalesce(sum(fragment("? * ?", oi.quantity, oi.unit_price)), 0.0),
        coalesce(sum(fragment("? * ?", oi.quantity, oi.unit_price)), 0.0),
        # Margin score (0-20)
        fragment("((? - ?) / ?) * 100", p.price, p.cost_price, p.price),
        fragment("((? - ?) / ?) * 100", p.price, p.cost_price, p.price),
        # Conversion score (0-20)
        fragment("CASE WHEN COUNT(?) > 0 THEN (COUNT(DISTINCT ?) * 100.0 / COUNT(?)) ELSE 0 END",
                 v.id, o.id, v.id),
        fragment("CASE WHEN COUNT(?) > 0 THEN (COUNT(DISTINCT ?) * 100.0 / COUNT(?)) ELSE 0 END",
                 v.id, o.id, v.id),
        # Units sold score (0-20)
        coalesce(sum(oi.quantity), 0), coalesce(sum(oi.quantity), 0))
      }
  end
end
```

## Multi-Table Inventory Report

Comprehensive inventory analysis across suppliers and warehouses:

```elixir
# lib/your_app_web/live/inventory_report_live/index.ex
defmodule YourAppWeb.InventoryReportLive.Index do
  use YourAppWeb, :live_view
  use LiveTable.LiveResource

  def mount(_params, _session, socket) do
    socket = assign(socket, :data_provider, {YourApp.Inventory, :comprehensive_report, []})
    {:ok, socket}
  end

  def fields do
    [
      product_name: %{label: "Product", sortable: true, searchable: true},
      sku: %{label: "SKU", sortable: true, searchable: true},
      supplier_name: %{
        label: "Supplier", 
        sortable: true,
        assoc: {:suppliers, :name}
      },
      warehouse_location: %{
        label: "Warehouse", 
        sortable: true,
        assoc: {:warehouses, :location}
      },
      current_stock: %{label: "Current Stock", sortable: true, renderer: &render_stock/2},
      reserved_stock: %{label: "Reserved", sortable: true},
      available_stock: %{label: "Available", sortable: true, renderer: &render_available/1},
      reorder_point: %{label: "Reorder Point", sortable: true},
      max_stock: %{label: "Max Stock", sortable: true},
      avg_daily_usage: %{label: "Daily Usage", sortable: true, renderer: &render_usage/1},
      days_of_supply: %{label: "Days Supply", sortable: true, renderer: &render_days_supply/2},
      last_movement: %{label: "Last Movement", sortable: true, renderer: &render_date/1},
      status: %{label: "Status", renderer: &render_inventory_status/2}
    ]
  end

  def filters do
    [
      supplier: Select.new({:suppliers, :name}, "supplier", %{
        label: "Supplier",
        options_source: {YourApp.Suppliers, :list_active, []}
      }),
      
      warehouse: Select.new({:warehouses, :location}, "warehouse", %{
        label: "Warehouse",
        options_source: {YourApp.Warehouses, :list_locations, []}
      }),
      
      stock_status: Select.new(:current_stock, "stock_status", %{
        label: "Stock Status",
        options: [
          %{label: "Out of Stock", value: ["out_of_stock"]},
          %{label: "Low Stock", value: ["low_stock"]},
          %{label: "Normal", value: ["normal"]},
          %{label: "Overstock", value: ["overstock"]}
        ]
      }),
      
      needs_reorder: Boolean.new(:current_stock, "needs_reorder", %{
        label: "Needs Reorder",
        condition: dynamic([p, suppliers: s, warehouses: w], 
          p.current_stock <= p.reorder_point and p.current_stock > 0)
      }),
      
      slow_moving: Boolean.new(:avg_daily_usage, "slow_moving", %{
        label: "Slow Moving (< 1/day)",
        condition: dynamic([p, suppliers: s, warehouses: w], p.avg_daily_usage < 1.0)
      })
    ]
  end

  def table_options do
    %{
      pagination: %{
        enabled: true,
        sizes: [50, 100, 200],
        default_size: 100
      },
      sorting: %{
        default_sort: [days_of_supply: :asc, current_stock: :asc]
      },
      exports: %{
        enabled: true,
        formats: [:csv, :pdf]
      }
    }
  end

  defp render_stock(stock, record) do
    assigns = %{stock: stock, record: record}
    ~H"""
    <div class="flex items-center gap-2">
      <span class={[
        "font-medium",
        cond do
          @stock == 0 -> "text-red-600"
          @stock <= @record.reorder_point -> "text-orange-600"
          @stock >= @record.max_stock -> "text-purple-600"
          true -> "text-green-600"
        end
      ]}>
        <%= @stock %>
      </span>
    </div>
    """
  end

  defp render_available(available) do
    assigns = %{available: available}
    ~H"""
    <span class={[
      "font-medium",
      if(@available <= 0, do: "text-red-600", else: "text-blue-600")
    ]}>
      <%= @available %>
    </span>
    """
  end

  defp render_usage(usage) do
    assigns = %{usage: usage}
    ~H"""
    <span class="text-sm">
      <%= :erlang.float_to_binary(@usage, decimals: 1) %>/day
    </span>
    """
  end

  defp render_days_supply(days, record) do
    assigns = %{days: days, record: record}
    ~H"""
    <span class={[
      "font-medium",
      cond do
        @days <= 7 -> "text-red-600"
        @days <= 14 -> "text-orange-600"
        @days >= 90 -> "text-purple-600"
        true -> "text-green-600"
      end
    ]}>
      <%= round(@days) %> days
    </span>
    """
  end

  defp render_date(nil) do
    assigns = %{}
    ~H"""
    <span class="text-gray-400 text-sm">No movement</span>
    """
  end

  defp render_date(date) do
    assigns = %{date: date}
    ~H"""
    <span class="text-sm">
      <%= Calendar.strftime(@date, "%b %d") %>
    </span>
    """
  end

  defp render_inventory_status(_value, record) do
    assigns = %{record: record}
    ~H"""
    <div class="flex flex-col gap-1">
      <%= cond do %>
        <% @record.current_stock == 0 -> %>
          <span class="bg-red-100 text-red-700 text-xs px-2 py-1 rounded">OUT OF STOCK</span>
        <% @record.current_stock <= @record.reorder_point -> %>
          <span class="bg-orange-100 text-orange-700 text-xs px-2 py-1 rounded">LOW STOCK</span>
        <% @record.current_stock >= @record.max_stock -> %>
          <span class="bg-purple-100 text-purple-700 text-xs px-2 py-1 rounded">OVERSTOCK</span>
        <% @record.days_of_supply <= 7 -> %>
          <span class="bg-yellow-100 text-yellow-700 text-xs px-2 py-1 rounded">URGENT</span>
        <% true -> %>
          <span class="bg-green-100 text-green-700 text-xs px-2 py-1 rounded">OK</span>
      <% end %>
      
      <%= if @record.avg_daily_usage < 1.0 do %>
        <span class="bg-gray-100 text-gray-600 text-xs px-2 py-1 rounded">SLOW</span>
      <% end %>
    </div>
    """
  end
end
```

The comprehensive inventory context:

```elixir
# lib/your_app/inventory.ex
defmodule YourApp.Inventory do
  import Ecto.Query
  alias YourApp.Repo

  def comprehensive_report do
    from p in YourApp.Product,
      join: s in YourApp.Supplier, on: p.supplier_id == s.id, as: :suppliers,
      join: w in YourApp.Warehouse, on: p.warehouse_id == w.id, as: :warehouses,
      left_join: im in YourApp.InventoryMovement, 
        on: im.product_id == p.id and im.inserted_at >= ago(30, "day"),
      group_by: [p.id, s.id, w.id],
      select: %{
        product_name: p.name,
        sku: p.sku,
        supplier_name: s.name,
        warehouse_location: w.location,
        current_stock: p.stock_quantity,
        reserved_stock: coalesce(p.reserved_quantity, 0),
        available_stock: p.stock_quantity - coalesce(p.reserved_quantity, 0),
        reorder_point: p.reorder_point,
        max_stock: p.max_stock_level,
        avg_daily_usage: fragment("""
          CASE 
            WHEN COUNT(?) > 0 THEN ABS(SUM(CASE WHEN ?.movement_type = 'out' THEN ?.quantity ELSE 0 END)) / 30.0
            ELSE 0 
          END
        """, im.id, im, im),
        days_of_supply: fragment("""
          CASE 
            WHEN COUNT(?) > 0 AND SUM(CASE WHEN ?.movement_type = 'out' THEN ?.quantity ELSE 0 END) > 0 
            THEN ? / (ABS(SUM(CASE WHEN ?.movement_type = 'out' THEN ?.quantity ELSE 0 END)) / 30.0)
            ELSE 999
          END
        """, im.id, im, im, p.stock_quantity, im, im),
        last_movement: max(im.inserted_at)
      }
  end
end
```

## Customer Lifetime Value Analysis

Complex customer analytics with cohort analysis:

```elixir
# lib/your_app_web/live/customer_ltv_live/index.ex
defmodule YourAppWeb.CustomerLtvLive.Index do
  use YourAppWeb, :live_view
  use LiveTable.LiveResource

  def mount(%{"cohort" => cohort}, _session, socket) do
    data_provider = {YourApp.Analytics, :customer_ltv_analysis, [cohort]}
    socket = assign(socket, :data_provider, data_provider)
    {:ok, socket}
  end

  def mount(_params, _session, socket) do
    mount(%{"cohort" => "2024"}, nil, socket)
  end

  def fields do
    [
      customer_name: %{label: "Customer", sortable: true, searchable: true},
      email: %{label: "Email", sortable: true, searchable: true},
      first_order_date: %{label: "First Order", sortable: true, renderer: &render_date/1},
      customer_segment: %{
        label: "Segment", 
        sortable: true,
        assoc: {:segments, :name}
      },
      total_orders: %{label: "Orders", sortable: true},
      total_spent: %{label: "Total Spent", sortable: true, renderer: &render_currency/1},
      avg_order_value: %{label: "AOV", sortable: true, renderer: &render_currency/1},
      order_frequency: %{label: "Frequency (days)", sortable: true, renderer: &render_frequency/1},
      ltv_score: %{label: "LTV Score", sortable: true, renderer: &render_ltv_score/1},
      predicted_ltv: %{label: "Predicted LTV", sortable: true, renderer: &render_currency/1},
      churn_risk: %{label: "Churn Risk", sortable: true, renderer: &render_churn_risk/1},
      last_order_date: %{label: "Last Order", sortable: true, renderer: &render_last_order/1}
    ]
  end

  def filters do
    [
      segment: Select.new({:segments, :name}, "segment", %{
        label: "Customer Segment",
        options: [
          %{label: "VIP", value: ["vip"]},
          %{label: "Regular", value: ["regular"]},
          %{label: "New", value: ["new"]},
          %{label: "At Risk", value: ["at_risk"]}
        ]
      }),
      
      ltv_range: Range.new(:predicted_ltv, "ltv_range", %{
        type: :number,
        label: "Predicted LTV",
        min: 0,
        max: 50000,
        step: 1000
      }),
      
      high_value: Boolean.new(:total_spent, "high_value", %{
        label: "High Value (> $1000)",
        condition: dynamic([c, segments: s], c.total_spent > 1000)
      }),
      
      churn_risk: Boolean.new(:churn_risk, "churn_risk", %{
        label: "High Churn Risk (> 70%)",
        condition: dynamic([c, segments: s], c.churn_risk > 70)
      }),
      
      active_customers: Boolean.new(:last_order_date, "active", %{
        label: "Active (Last 90 Days)",
        condition: dynamic([c, segments: s], c.last_order_date >= ago(90, "day"))
      })
    ]
  end

  def table_options do
    %{
      pagination: %{
        enabled: true,
        sizes: [25, 50, 100],
        default_size: 50
      },
      sorting: %{
        default_sort: [predicted_ltv: :desc, total_spent: :desc]
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
    <span class="font-mono text-green-600">$<%= :erlang.float_to_binary(@amount, decimals: 2) %></span>
    """
  end

  defp render_date(date) do
    assigns = %{date: date}
    ~H"""
    <span class="text-sm"><%= Calendar.strftime(@date, "%b %d, %Y") %></span>
    """
  end

  defp render_frequency(days) do
    assigns = %{days: days}
    ~H"""
    <span class="text-sm"><%= round(@days) %> days</span>
    """
  end

  defp render_ltv_score(score) do
    assigns = %{score: score}
    ~H"""
    <div class="flex items-center gap-2">
      <div class="w-16 bg-gray-200 rounded-full h-2">
        <div 
          class={[
            "h-2 rounded-full",
            cond do
              @score >= 80 -> "bg-green-500"
              @score >= 60 -> "bg-yellow-500"
              @score >= 40 -> "bg-orange-500"
              true -> "bg-red-500"
            end
          ]}
          style={"width: #{@score}%"}
        ></div>
      </div>
      <span class="text-sm font-medium"><%= round(@score) %></span>
    </div>
    """
  end

  defp render_churn_risk(risk) do
    assigns = %{risk: risk}
    ~H"""
    <span class={[
      "px-2 py-1 text-xs font-medium rounded-full",
      cond do
        @risk >= 80 -> "bg-red-100 text-red-700"
        @risk >= 60 -> "bg-orange-100 text-orange-700"
        @risk >= 40 -> "bg-yellow-100 text-yellow-700"
        true -> "bg-green-100 text-green-700"
      end
    ]}>
      <%= round(@risk) %>%
    </span>
    """
  end

  defp render_last_order(date) do
    assigns = %{date: date, days_ago: Date.diff(Date.utc_today(), date)}
    ~H"""
    <div class="flex flex-col">
      <span class="text-sm"><%= Calendar.strftime(@date, "%b %d") %></span>
      <span class={[
        "text-xs",
        cond do
          @days_ago <= 30 -> "text-green-600"
          @days_ago <= 90 -> "text-yellow-600"
          true -> "text-red-600"
        end
      ]}>
        <%= @days_ago %> days ago
      </span>
    </div>
    """
  end
end
```

Advanced customer analytics context:

```elixir
# lib/your_app/analytics.ex (addition to existing module)
def customer_ltv_analysis(cohort_year) do
  cohort_start = Date.new!(String.to_integer(cohort_year), 1, 1)
  cohort_end = Date.new!(String.to_integer(cohort_year), 12, 31)
  
  from c in YourApp.Customer,
    join: s in YourApp.CustomerSegment, on: c.segment_id == s.id, as: :segments,
    left_join: o in YourApp.Order, on: o.customer_id == c.id,
    where: c.inserted_at >= ^cohort_start and c.inserted_at <= ^cohort_end,
    group_by: [c.id, s.id],
    select: %{
      customer_name: fragment("? || ' ' || ?", c.first_name, c.last_name),
      email: c.email,
      first_order_date: min(o.inserted_at),
      customer_segment: s.name,
      total_orders: count(o.id),
      total_spent: coalesce(sum(o.total_amount), 0.0),
      avg_order_value: fragment("CASE WHEN COUNT(?) > 0 THEN ? / COUNT(?) ELSE 0 END",
                               o.id, coalesce(sum(o.total_amount), 0.0), o.id),
      order_frequency: fragment("""
        CASE 
          WHEN COUNT(?) > 1 THEN 
            DATE_PART('day', MAX(?) - MIN(?)) / (COUNT(?) - 1)
          ELSE 0 
        END
      """, o.id, o.inserted_at, o.inserted_at, o.id),
      ltv_score: fragment("""
        LEAST(100, GREATEST(0,
          (CASE WHEN ? > 0 THEN LEAST(25, ? / 2000 * 25) ELSE 0 END) +
          (CASE WHEN COUNT(?) > 0 THEN LEAST(25, COUNT(?) / 10 * 25) ELSE 0 END) +
          (CASE WHEN ? > 0 THEN LEAST(25, ? / 500 * 25) ELSE 0 END) +
          (CASE WHEN ? <= 60 THEN 25 ELSE GREATEST(0, 25 - (? - 60) / 10) END)
        ))
      """,
      # Total spent score (0-25)
      coalesce(sum(o.total_amount), 0.0), coalesce(sum(o.total_amount), 0.0),
      # Order frequency score (0-25)
      o.id, o.id,
      # AOV score (0-25)
      fragment("CASE WHEN COUNT(?) > 0 THEN ? / COUNT(?) ELSE 0 END",
               o.id, coalesce(sum(o.total_amount), 0.0), o.id),
      fragment("CASE WHEN COUNT(?) > 0 THEN ? / COUNT(?) ELSE 0 END",
               o.id, coalesce(sum(o.total_amount), 0.0), o.id),
      # Recency score (0-25, based on days since last order)
      fragment("DATE_PART('day', NOW() - MAX(?))", o.inserted_at),
      fragment("DATE_PART('day', NOW() - MAX(?))", o.inserted_at)),
      predicted_ltv: fragment("""
        CASE 
          WHEN COUNT(?) > 0 THEN 
            ? * (? / ?) * 
            CASE 
              WHEN ? <= 30 THEN 5.0
              WHEN ? <= 90 THEN 3.0
              WHEN ? <= 180 THEN 2.0
              ELSE 1.5
            END
          ELSE 0 
        END
      """, 
      o.id, 
      coalesce(sum(o.total_amount), 0.0),
      fragment("CASE WHEN COUNT(?) > 0 THEN ? / COUNT(?) ELSE 0 END",
               o.id, coalesce(sum(o.total_amount), 0.0), o.id),
      fragment("CASE WHEN COUNT(?) > 1 THEN DATE_PART('day', MAX(?) - MIN(?)) / (COUNT(?) - 1) ELSE 365 END",
               o.id, o.inserted_at, o.inserted_at, o.id),
      fragment("DATE_PART('day', NOW() - MAX(?))", o.inserted_at),
      fragment("DATE_PART('day', NOW() - MAX(?))", o.inserted_at),
      fragment("DATE_PART('day', NOW() - MAX(?))", o.inserted_at)),
      churn_risk: fragment("""
        CASE 
          WHEN COUNT(?) = 0 THEN 95
          WHEN ? > 365 THEN 90
          WHEN ? > 180 THEN 70
          WHEN ? > 90 THEN 50
          WHEN ? > 60 THEN 30
          WHEN ? > 30 THEN 20
          ELSE 10
        END
      """, 
      o.id,
      fragment("DATE_PART('day', NOW() - MAX(?))", o.inserted_at),
      fragment("DATE_PART('day', NOW() - MAX(?))", o.inserted_at),
      fragment("DATE_PART('day', NOW() - MAX(?))", o.inserted_at),
      fragment("DATE_PART('day', NOW() - MAX(?))", o.inserted_at),
      fragment("DATE_PART('day', NOW() - MAX(?))", o.inserted_at)),
      last_order_date: max(o.inserted_at)
    }
end
```

## Key Patterns for Complex Queries

### 1. Data Provider Assignment
- Assign `:data_provider` in `mount/3` or `handle_params/3`
- Use `{Module, :function, [args]}` tuple format
- Pass parameters dynamically based on route or user input

### 2. Query Design
- Use meaningful aliases with `as:` keyword
- Group by all non-aggregated fields
- Use `fragment/2` for complex calculations
- Leverage window functions for advanced analytics

### 3. Field References
- Use `assoc: {:alias_name, :field}` for joined fields
- Ensure field keys match query select keys exactly
- Use computed fields sparingly for performance

### 4. Complex Renderers
- Use `renderer: &function/2` to access full record
- Implement conditional rendering based on multiple fields
- Create reusable renderer functions for common patterns

### 5. Advanced Filters
- Reference table aliases in dynamic queries
- Use complex conditions with multiple criteria
- Combine filters with AND logic automatically

These examples demonstrate how LiveTable handles sophisticated reporting requirements while maintaining clean, maintainable code.