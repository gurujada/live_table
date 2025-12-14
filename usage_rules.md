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
{:live_table, "~> 0.3.1"}
# Add {:oban, "~> 2.19"} only if using export functionality
```

## Required Setup Checklist

When implementing with LiveTable, ALWAYS ensure:

### 1. Dependencies
```elixir
# In mix.exs deps function
{:live_table, "~> 0.3.1"}
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

4. **Is the template structure correct?**
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
- `{:live_table, "~> 0.3.1"}` (always required)
- `{:oban, "~> 2.19"}` (only if using exports)

### Must-Have Config
- LiveTable repo and pubsub config (always required)
- Oban queue configuration (only if using exports)

> **Note**: LiveTable uses runtime hooks, so no JavaScript configuration is required. Hooks are automatically registered when your LiveView renders.

## Transformer Usage

Transformers are LiveTable's most powerful feature for complex query modifications.

### When to Use Transformers
- Complex filtering that can't be expressed with simple conditions
- Joins with aggregations (GROUP BY, HAVING)
- Dynamic query modifications based on multiple parameters
- Role-based data access

### Transformer Pattern
```elixir
def filters do
  [
    advanced_filter: Transformer.new("advanced", %{
      query_transformer: &apply_advanced_filter/2
    })
  ]
end

defp apply_advanced_filter(query, filter_data) do
  case filter_data do
    %{"min_sales" => min} when min != "" ->
      from p in query,
        join: s in Sale, on: s.product_id == p.id,
        group_by: p.id,
        having: sum(s.amount) >= ^String.to_integer(min)
    _ ->
      query
  end
end
```

### Transformer Rules
- Always return a query (even if unchanged)
- Function receives `(query, filter_data)` where `filter_data` is a map
- Can use `{Module, :function}` tuple syntax for reusable transformers
- Transformers are applied after standard filters

## Debug Mode

Debug mode helps developers understand query building.

### Enabling Debug
```elixir
def table_options do
  %{
    debug: :query  # or :trace or :off (default)
  }
end
```

### Debug Modes
- `:off` - No debug output (default, production)
- `:query` - Prints compiled query to terminal
- `:trace` - Uses `dbg()` for step-by-step tracing

**Note**: Debug only works in `:dev` environment.

## Pagination Modes

### Standard Pagination (Default)
```elixir
pagination: %{
  enabled: true,
  mode: :buttons,
  sizes: [10, 25, 50],
  default_size: 25
}
```

### Infinite Scroll (Card Mode Only)
```elixir
# Infinite scroll only works with card mode
def table_options do
  %{
    mode: :card,
    card_component: &my_card/1,
    pagination: %{
      enabled: true,
      mode: :infinite_scroll,
      default_size: 20,
      loading_component: &custom_loader/1  # Optional
    }
  }
end
```

## Actions Configuration

Actions provide row-level operations separate from fields.

### Simple Actions List
```elixir
def actions do
  [
    edit: &edit_action/1,
    delete: &delete_action/1
  ]
end
```

### Actions with Label
```elixir
def actions do
  %{
    label: "Actions",
    items: [
      edit: &edit_action/1,
      delete: &delete_action/1
    ]
  }
end
```

### Action Component
```elixir
defp edit_action(assigns) do
  ~H"""
  <.link navigate={~p"/items/#{@record.id}/edit"}>Edit</.link>
  """
end
```

### Template with Actions
```heex
<.live_table
  fields={fields()}
  filters={filters()}
  options={@options}
  streams={@streams}
  actions={actions()}
/>
```

## Additional Table Options

### Streams Control
```elixir
use_streams: true   # Default - efficient DOM updates
use_streams: false  # Regular assigns
```

### Fixed Header
```elixir
fixed_header: true  # Sticky header on scroll
```

### Empty State
```elixir
empty_state: &custom_empty_state/1

defp custom_empty_state(assigns) do
  ~H"""
  <div class="text-center py-8">No records found</div>
  """
end
```

### Card Mode
```elixir
mode: :card,
card_component: &product_card/1

defp product_card(assigns) do
  ~H"""
  <div class="p-4 border rounded">
    <h3><%= @record.name %></h3>
  </div>
  """
end
```

## Field Options Reference

### Component vs Renderer
```elixir
# renderer - receives value directly (or value, record)
price: %{renderer: &format_price/1}

# component - receives assigns with @value and @record
status: %{component: &status_badge/1}

defp status_badge(assigns) do
  ~H"<span><%= @value %></span>"  # Access via @value, @record
end
```

### Empty Text
```elixir
price: %{
  label: "Price",
  empty_text: "N/A"  # Shown when value is nil
}
```

## Generator Usage

### Install Generator
```bash
mix live_table.install
mix live_table.install --oban  # With Oban for exports
```

### LiveView Generator
```bash
mix live_table.gen.live Products Product products name:string price:decimal
```

This document ensures LLMs provide accurate, complete LiveTable implementations every time.