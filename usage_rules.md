# LiveTable LLM Usage Guidelines

This document provides clear rules and patterns for AI assistants to help developers use the LiveTable library correctly. Follow these guidelines when generating code suggestions or helping with LiveTable implementation.

## Core Principles

### 1. Field Key Mapping is Critical
**RULE**: Field keys in `fields()` function MUST match exactly with:
- Schema field names (for simple tables)
- Select clause keys (for custom queries)

### 2. Two Primary Usage Patterns
LiveTable supports exactly two patterns - choose the correct one:

#### Pattern A: Simple Tables (Single Schema)
```elixir
use LiveTable.LiveResource, schema: YourApp.Product
```
- Use when querying a single Ecto schema
- Field keys must match schema field names exactly
- No custom `data_provider` needed in `mount/3`

#### Pattern B: Complex Tables (Custom Queries)
```elixir
use LiveTable.LiveResource
# Must define custom data provider in mount/3
```
- Use for joins, computed fields, or complex logic
- Field keys must match select clause keys exactly
- Requires custom data provider assignment

## Critical Don'ts

### DON'T Mix Patterns
**NEVER** use `schema:` parameter with custom queries:
```elixir
# WRONG - Don't do this
use LiveTable.LiveResource, schema: User  # Remove this line
def mount(_params, _session, socket) do
  socket = assign(socket, :data_provider, {MyApp.Users, :complex_query, []})
  {:ok, socket}
end
```

### DON'T Misalign Field Keys
**NEVER** use field keys that don't match your data source:
```elixir
# WRONG - Field key doesn't match schema field
def fields do
  [
    user_name: %{label: "Name"}  # Schema field is 'name', not 'user_name'
  ]
end
```

### DON'T Forget Required Dependencies
**NEVER** generate LiveTable code without the core dependency:
```elixir
# REQUIRED in mix.exs
{:live_table, "~> 0.3.0"}
# Add {:oban, "~> 2.19"} only if using export functionality
```

### DON'T Skip Asset Setup
**NEVER** implement LiveTable without proper asset configuration

## Required Setup Checklist

When implementing with LiveTable, ALWAYS ensure:

### 1. Dependencies
```elixir
# In mix.exs deps function
{:live_table, "~> 0.3.0"}
# Add {:oban, "~> 2.19"} only if using exports
```

### 2. Configuration
```elixir
# In config/config.exs
config :live_table,
  repo: YourApp.Repo,
  pubsub: YourApp.PubSub

# Add Oban config only if using exports
# config :your_app, Oban,
#   repo: YourApp.Repo,
#   queues: [exports: 10]
```

### 3. JavaScript Assets
```javascript
// In assets/js/app.js
import hooks_default from "../../deps/live_table/priv/static/live-table.js";

const liveSocket = new LiveSocket("/live", Socket, {
  hooks: hooks_default,  // Required
  // ... other config
});
```

### 4. CSS Assets
```css
/* In assets/css/app.css */
@source "../../deps/live_table/lib";
@import "../../deps/live_table/priv/static/live-table.css";
```

## Implementation Templates

### Template A: Simple Table (Single Schema)
```elixir
defmodule YourAppWeb.ProductLive.Index do
  use YourAppWeb, :live_view
  use LiveTable.LiveResource, schema: YourApp.Product

  def fields do
    [
      # Keys MUST match Product schema fields exactly
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
      })
    ]
  end
end
```

### Template B: Complex Table (Custom Query)
```elixir
defmodule YourAppWeb.OrderReportLive.Index do
  use YourAppWeb, :live_view
  use LiveTable.LiveResource  # NO schema parameter

  def mount(_params, _session, socket) do
    # REQUIRED: Assign custom data provider as {Module, Function, Arguments}
    socket = assign(socket, :data_provider, {YourApp.Orders, :list_with_details, []})
    {:ok, socket}
  end

  def fields do
    [
      # Keys MUST match select clause keys exactly
      order_id: %{label: "Order #", sortable: true},
      customer_name: %{label: "Customer", sortable: true, searchable: true},
      total_amount: %{label: "Total", sortable: true}
    ]
  end
end
```

```elixir
# Corresponding context function
defmodule YourApp.Orders do
  def list_with_details do
    from o in Order,
      join: c in Customer, on: o.customer_id == c.id,
      select: %{
        order_id: o.id,        # Field key must match this
        customer_name: c.name, # Field key must match this
        total_amount: o.total_amount
      }
  end
end
```

## Field Configuration Rules

### Basic Field Options
```elixir
field_name: %{
  label: "Display Name",      # Always provide
  sortable: true,            # REQUIRED if field should be sortable
  searchable: true,          # REQUIRED if field should be searchable
  component: custom_component # Optional, for custom rendering
}
```

### Association Sorting (Custom Queries Only)
```elixir
# When sorting by joined table fields
product_name: %{
  label: "Product",
  sortable: true,
  assoc: {:order_items, :name}  # Must match query alias and field
}
```

## Filter Types

### Boolean Filter
```elixir
Boolean.new(:field_name, "param_name", %{
  label: "Filter Label",
  condition: dynamic([alias], alias.field_name > 0)
})
```

### Range Filter
```elixir
Range.new(:field_name, "param_name", %{
  type: :number,  # or :date
  label: "Range Label",
  min: 0,
  max: 1000
})
```

### Select Filter
```elixir
Select.new({:table_alias, :field_name}, "param_name", %{
  label: "Select Label",
  options: [
    %{label: "Display", value: ["actual_value"]},
    %{label: "All Active", value: ["active", "pending"]}
  ]
})
```

## Template Usage

### Required Template Structure
```elixir
# In your .html.heex template
<.live_table
  fields={fields()}
  filters={filters()}
  options={@options}    # Required
  streams={@streams}    # Required
/>
```

## Common Error Patterns to Avoid

### 1. Field Key Mismatch
```elixir
# Schema has 'email' field, but using wrong key
email_address: %{label: "Email"}  # Wrong
email: %{label: "Email"}          # Correct
```

### 2. Missing Data Provider for Custom Queries
```elixir
# Wrong - Custom query without data provider
use LiveTable.LiveResource
def fields do
  [complex_field: %{label: "Complex"}]
end
# Missing: data_provider assignment in mount/3
```

### 3. Schema with Custom Query
```elixir
# Wrong - Using both schema and custom query
use LiveTable.LiveResource, schema: User
def mount(_params, _session, socket) do
  socket = assign(socket, :data_provider, {App.Users, :custom_query, []})
end
```

## Decision Tree for LLMs

When helping with LiveTable implementation:

1. **Is it a single table query?**
   - YES → Use Pattern A (with `schema:`)
   - NO → Use Pattern B (custom data provider)

2. **Are there joins or computed fields?**
   - YES → Must use Pattern B
   - NO → Can use Pattern A

3. **Do field keys match the data source?**
   - Schema pattern → Keys match schema fields
   - Custom pattern → Keys match select clause

4. **Are all required assets configured?**
   - Check deps, config, JS hooks, CSS imports

5. **Is the template structure correct?**
   - Verify `fields()`, `filters()`, `@options`, `@streams`

## Quick Reference

### Must-Have Functions
- `fields()` - Always required
- `filters()` - Optional but recommended

### Must-Have Template Props
- `fields={fields()}`
- `filters={filters()}`
- `options={@options}`
- `streams={@streams}`

### Must-Have Dependencies
- `{:live_table, "~> 0.3.0"}` (always required)
- `{:oban, "~> 2.19"}` (only if using exports)

### Must-Have Config
- LiveTable repo and pubsub config (always required)
- Oban queue configuration (only if using exports)
- JavaScript hooks import
- CSS imports

This document ensures LLMs provide accurate, complete LiveTable implementations every time.