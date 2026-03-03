# Filters API Reference

Filters provide interactive filtering capabilities for your LiveTable. They allow users to narrow down displayed data using various input types like checkboxes, dropdowns, and range sliders.

## Overview

Filters are defined in the `filters/0` function as a keyword list where each key represents a filter and maps to a filter struct (Boolean, Range, or Select).

```elixir
def filters do
  [
    active: Boolean.new(:active, "active", %{
      label: "Active Only",
      condition: dynamic([p], p.active == true)
    }),
    
    price_range: Range.new(:price, "price_range", %{
      type: :number,
      label: "Price Range",
      min: 0,
      max: 1000
    }),
    
    category: Select.new({:category, :name}, "category", %{
      label: "Category",
      options: [
        %{label: "Electronics", value: ["electronics"]},
        %{label: "Books", value: ["books"]}
      ]
    })
  ]
end
```

## Filter Types

LiveTable supports three types of filters:

- **Boolean** - Checkbox filters for true/false conditions
- **Range** - Slider filters for numeric, date, or datetime ranges
- **Select** - Dropdown filters with static or dynamic options

## Common Filter Patterns

### Filter Constructor Arguments

All filters use the same constructor pattern:

```elixir
FilterType.new(field, key, options)
```

- **`field`** - The database field to filter on (atom for simple fields, `{:table_alias, :field}` for joined fields)
- **`key`** - URL parameter key (string, used for persistence and routing)
- **`options`** - Map of filter-specific configuration options

### Field References

#### Simple Schema Fields
For single-table queries, reference schema fields directly:

```elixir
# Filter on Product.active field
active_filter: Boolean.new(:active, "active", %{...})

# Filter on Product.price field  
price_filter: Range.new(:price, "price_range", %{...})
```

#### Joined Fields (Custom Queries Only)
For custom queries with joins, reference the table alias:

```elixir
# Filter on joined suppliers table
supplier_filter: Select.new({:suppliers, :name}, "supplier", %{...})

# Filter on joined categories table
category_filter: Boolean.new({:categories, :active}, "category_active", %{...})
```

## Boolean Filters

Boolean filters render as checkboxes and apply dynamic query conditions when checked.

### Basic Usage

```elixir
def filters do
  [
    active: Boolean.new(:active, "active", %{
      label: "Active Products Only",
      condition: dynamic([p], p.active == true)
    }),
    
    in_stock: Boolean.new(:stock_quantity, "in_stock", %{
      label: "In Stock",
      condition: dynamic([p], p.stock_quantity > 0)
    })
  ]
end
```

### Advanced Conditions

```elixir
def filters do
  [
    # Complex condition with multiple criteria
    premium_products: Boolean.new(:price, "premium", %{
      label: "Premium Products (>$500 & Featured)",
      condition: dynamic([p], p.price > 500 and p.featured == true)
    }),
    
    # Condition using joined tables (for custom queries)
    verified_suppliers: Boolean.new({:suppliers, :verified}, "verified", %{
      label: "Verified Suppliers Only",
      condition: dynamic([p, suppliers: s], s.verified == true and s.active == true)
    })
  ]
end
```

### Boolean Options

```elixir
Boolean.new(field, key, %{
  label: "Filter Label",           # Required: Display text
  condition: dynamic_expression,   # Required: Ecto dynamic query
  default: false,                  # Optional: Default checked state
  class: "custom-css-class"        # Optional: CSS classes
})
```

## Range Filters

Range filters provide sliders for filtering numeric values, dates, or datetimes within specified ranges.

### Numeric Ranges

```elixir
def filters do
  [
    price_range: Range.new(:price, "price_range", %{
      type: :number,
      label: "Price Range",
      unit: "$",
      min: 0,
      max: 1000,
      step: 10,
      default_min: 0,
      default_max: 1000
    }),
    
    age_range: Range.new(:age, "age_range", %{
      type: :number,
      label: "Age",
      min: 18,
      max: 65,
      step: 1
    })
  ]
end
```

### Date Ranges

```elixir
def filters do
  [
    created_date: Range.new(:inserted_at, "created_range", %{
      type: :date,
      label: "Created Date",
      min: ~D[2024-01-01],
      max: ~D[2024-12-31],
      default_min: ~D[2024-01-01],
      default_max: ~D[2024-12-31]
    })
  ]
end
```

### DateTime Ranges

```elixir
def filters do
  [
    updated_time: Range.new(:updated_at, "updated_range", %{
      type: :datetime,
      label: "Last Updated",
      min: ~N[2024-01-01 00:00:00],
      max: ~N[2024-12-31 23:59:59],
      step: 3600  # Step in seconds (1 hour)
    })
  ]
end
```

### Range Options

```elixir
Range.new(field, key, %{
  type: :number,                    # Required: :number, :date, or :datetime
  label: "Range Label",             # Required: Display text
  min: 0,                          # Required: Minimum value
  max: 100,                        # Required: Maximum value
  step: 1,                         # Optional: Step increment
  default_min: 0,                  # Optional: Default minimum
  default_max: 100,                # Optional: Default maximum
  unit: "$",                       # Optional: Unit display
  css_classes: "custom-wrapper",   # Optional: CSS classes
  slider_classes: "custom-slider", # Optional: Slider CSS classes
  pips: true,                      # Optional: Show slider markers
  event_type: "change"             # Optional: JS event type
})
```

## Select Filters

Select filters provide dropdown selection with static or dynamic options. The filter uses the `field` parameter to determine which database column to filter on, making it flexible enough to filter by ID, string values, or any other column type.

### Filtering by Non-ID Fields

The Select filter now supports filtering by any database field, not just IDs. The `field` parameter directly determines which column is used in the WHERE clause.

```elixir
def filters do
  [
    # Filter by status enum/string on the base table
    status: Select.new(:status, "status", %{
      label: "Status",
      options: [
        %{label: "Active", value: "active"},
        %{label: "Draft", value: "draft"},
        %{label: "Archived", value: "archived"}
      ]
    }),

    # Filter by name on a joined table (not just ID)
    category: Select.new({:categories, :name}, "category_name", %{
      label: "Category Name",
      options_source: {YourApp.Catalog, :search_category_names, []}
    }),

    # Filter by any column on the base table
    priority: Select.new(:priority, "priority", %{
      label: "Priority",
      options: [
        %{label: "Low", value: "low"},
        %{label: "Medium", value: "medium"},
        %{label: "High", value: "high"}
      ]
    })
  ]
end
```

**How it works:**
- The `field` parameter (`:status`, `{:categories, :name}`, etc.) is used directly in the query's WHERE clause
- Integer IDs and string values are both supported
- URL params are automatically coerced (integer strings become integers, others stay as strings)

### Static Options

```elixir
def filters do
  [
    status: Select.new(:status, "status", %{
      label: "Order Status",
      options: [
        %{label: "Pending", value: ["pending"]},
        %{label: "Processing", value: ["processing"]},
        %{label: "Shipped", value: ["shipped"]},
        %{label: "Delivered", value: ["delivered"]}
      ]
    }),
    
    priority: Select.new(:priority, "priority", %{
      label: "Priority Level",
      options: [
        %{label: "Low", value: ["low"]},
        %{label: "Medium", value: ["medium"]},
        %{label: "High", value: ["high"]},
        %{label: "Critical", value: ["critical"]}
      ]
    })
  ]
end
```

### Dynamic Options

For options loaded from the database:

```elixir
def filters do
  [
    category: Select.new({:categories, :name}, "category", %{
      label: "Product Category",
      options_source: {YourApp.Catalog, :search_categories, []}
    }),
    
    supplier: Select.new({:suppliers, :name}, "supplier", %{
      label: "Supplier",
      placeholder: "Search suppliers...",
      options_source: {YourApp.Suppliers, :search_suppliers, []}
    })
  ]
end
```

The corresponding context functions must return tuples:

```elixir
# lib/your_app/catalog.ex
defmodule YourApp.Catalog do
  def search_categories(search_text \\ "") do
    Category
    |> where([c], ilike(c.name, ^"%#{search_text}%"))
    |> select([c], {c.name, [c.id, c.description]})
    |> Repo.all()
  end
end

# lib/your_app/suppliers.ex  
defmodule YourApp.Suppliers do
  def search_suppliers(search_text \\ "") do
    Supplier
    |> where([s], ilike(s.name, ^"%#{search_text}%"))
    |> select([s], {s.name, [s.id, s.contact_email]})
    |> Repo.all()
  end
end
```

### Custom Option Templates

```elixir
def filters do
  [
    supplier: Select.new({:suppliers, :name}, "supplier", %{
      label: "Supplier",
      options_source: {YourApp.Suppliers, :search_suppliers, []},
      option_template: &custom_supplier_template/1
    })
  ]
end

defp custom_supplier_template(option) do
  assigns = %{option: option}
  ~H"""
  <div class="flex flex-col">
    <span class="font-semibold text-sm"><%= @option.label %></span>
    <span class="text-xs text-gray-500">ID: <%= @option.value |> Enum.at(0) %></span>
    <span class="text-xs text-gray-400"><%= @option.value |> Enum.at(1) %></span>
  </div>
  """
end
```

### Select Options

```elixir
Select.new(field, key, %{
  label: "Select Label",                    # Required: Display text
  options: [],                             # Static options list
  options_source: {Module, :function, []}, # Dynamic options source
  option_template: &template_function/1,   # Custom option template
  placeholder: "Choose an option...",      # Placeholder text
  loading_text: "Loading...",              # Loading state text
  css_classes: "custom-wrapper",           # CSS classes
  label_classes: "custom-label",           # Label CSS classes
  select_classes: "custom-select"          # Select input CSS classes
})
```

## Real-World Examples

### E-commerce Product Filters

```elixir
def filters do
  [
    # Active products toggle
    active: Boolean.new(:active, "active", %{
      label: "Show Active Products Only",
      condition: dynamic([p], p.active == true)
    }),
    
    # Price range slider
    price_range: Range.new(:price, "price_range", %{
      type: :number,
      label: "Price Range",
      unit: "$",
      min: 0,
      max: 2000,
      step: 25,
      default_min: 0,
      default_max: 500
    }),
    
    # Category dropdown with search
    category: Select.new({:categories, :name}, "category", %{
      label: "Category",
      placeholder: "Search categories...",
      options_source: {Shop.Catalog, :search_categories, []}
    }),
    
    # Stock level toggle
    low_stock: Boolean.new(:stock_quantity, "low_stock", %{
      label: "Low Stock Alert (< 10 items)",
      condition: dynamic([p], p.stock_quantity < 10 and p.stock_quantity > 0)
    }),
    
    # Recently added toggle
    new_arrivals: Boolean.new(:inserted_at, "new_arrivals", %{
      label: "New Arrivals (Last 30 Days)",
      condition: dynamic([p], p.inserted_at >= ago(30, "day"))
    })
  ]
end
```

### User Management Filters

```elixir
def filters do
  [
    # Active users
    active_users: Boolean.new(:active, "active", %{
      label: "Active Users Only",
      condition: dynamic([u], u.active == true)
    }),
    
    # Registration date range
    signup_date: Range.new(:inserted_at, "signup_range", %{
      type: :date,
      label: "Registration Date",
      min: ~D[2020-01-01],
      max: Date.utc_today()
    }),
    
    # Role selection
    role: Select.new(:role, "role", %{
      label: "User Role",
      options: [
        %{label: "Admin", value: ["admin"]},
        %{label: "Manager", value: ["manager"]},
        %{label: "User", value: ["user"]},
        %{label: "Guest", value: ["guest"]}
      ]
    }),
    
    # Email verified toggle
    verified: Boolean.new(:email_verified_at, "verified", %{
      label: "Email Verified",
      condition: dynamic([u], not is_nil(u.email_verified_at))
    })
  ]
end
```

### Order Analytics Filters

```elixir
def filters do
  [
    # Order status
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
    
    # Order value range
    order_total: Range.new(:total_amount, "total_range", %{
      type: :number,
      label: "Order Total",
      unit: "$",
      min: 0,
      max: 10000,
      step: 100
    }),
    
    # Date range for order placement
    order_date: Range.new(:inserted_at, "order_date_range", %{
      type: :date,
      label: "Order Date",
      min: Date.add(Date.utc_today(), -365),
      max: Date.utc_today()
    }),
    
    # High priority orders
    priority_orders: Boolean.new(:priority, "priority", %{
      label: "Priority Orders Only",
      condition: dynamic([o], o.priority in ["high", "urgent"])
    }),
    
    # Customer type (for custom queries with joins)
    customer_type: Select.new({:customers, :type}, "customer_type", %{
      label: "Customer Type",
      options: [
        %{label: "Individual", value: ["individual"]},
        %{label: "Business", value: ["business"]},
        %{label: "Enterprise", value: ["enterprise"]}
      ]
    })
  ]
end
```

## Filter Persistence

Filters automatically persist their state in URL parameters, allowing users to:

- **Bookmark filtered views**
- **Share filtered URLs**
- **Navigate back/forward** with filter state intact
- **Refresh the page** without losing filters

The `key` parameter in each filter constructor determines the URL parameter name:

```elixir
# Creates URL parameter: ?active=true
active: Boolean.new(:active, "active", %{...})

# Creates URL parameter: ?price_range[min]=100&price_range[max]=500  
price_range: Range.new(:price, "price_range", %{...})

# Creates URL parameter: ?category[]=electronics&category[]=books
category: Select.new(:category, "category", %{...})
```

## Performance Tips

### Optimize Filter Queries

```elixir
# ✅ Good: Simple field conditions
condition: dynamic([p], p.active == true)
condition: dynamic([p], p.price > 100)

# ⚠️ Be careful: Complex subqueries
condition: dynamic([p], fragment("(SELECT COUNT(*) FROM orders WHERE product_id = ?) > 5", p.id))

# ✅ Better: Use database views or computed fields for complex logic
```

### Index Filtered Fields

Make sure frequently filtered fields have database indexes:

```sql
-- Add indexes for better filter performance
CREATE INDEX idx_products_active ON products(active);
CREATE INDEX idx_products_price ON products(price);
CREATE INDEX idx_products_category_id ON products(category_id);
CREATE INDEX idx_orders_status ON orders(status);
CREATE INDEX idx_orders_inserted_at ON orders(inserted_at);
```

## Troubleshooting

### Filter Not Appearing
- Check that the filter is included in your `filters/0` function
- Verify the filter syntax and required options
- Ensure Boolean/Range/Select are properly imported

### Filter Not Working
- For simple queries: ensure field exists in your schema
- For custom queries: ensure field/alias exists in your query
- Check dynamic query syntax in Boolean filter conditions
- Verify options_source functions return correct tuple format for Select filters

### Options Not Loading (Select Filters)
- Check that your context function is accessible
- Verify the function returns `{label, [value1, value2]}` tuples
- Ensure the module/function exists and is properly imported
- Check for any errors in your context function

### URL Parameters Not Persisting
- Verify each filter has a unique `key` parameter
- Check that keys don't conflict with other URL parameters
- Ensure LiveView handle_params is properly set up