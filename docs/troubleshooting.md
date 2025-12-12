# Troubleshooting Guide

This guide covers common issues, error messages, and solutions when working with LiveTable.

## Common Setup Issues

### LiveTable Components Not Rendering

**Problem:** Table doesn't appear or shows blank content.

**Symptoms:**
- Empty div where table should be
- No error messages in logs
- LiveView mounts successfully but no table content

**Solutions:**

1. **Check LiveResource Setup**
```elixir
# ✅ Correct setup
defmodule YourAppWeb.ProductLive.Index do
  use YourAppWeb, :live_view
  use LiveTable.LiveResource, schema: YourApp.Product
  
  def fields do
    [name: %{label: "Name"}]
  end
end

# ❌ Missing LiveResource
defmodule YourAppWeb.ProductLive.Index do
  use YourAppWeb, :live_view
  # Missing: use LiveTable.LiveResource
end
```

2. **Verify Template Usage**
```elixir
# ✅ Correct template
~H"""
<.live_table
  fields={fields()}
  filters={filters()}
  options={@options}
  streams={@streams}
/>
"""

# ❌ Missing required assigns
~H"""
<.live_table fields={fields()} />
"""
```

## Query and Data Issues

### Empty Table Despite Having Data

**Problem:** Table shows "No records found" but database has data.

**Debugging Steps:**

1. **Check Schema Configuration**
```elixir
# Verify your schema is correct
use LiveTable.LiveResource, schema: YourApp.Product

# Check if schema exists and has data
iex> YourApp.Repo.all(YourApp.Product) |> length()
```

2. **Test Custom Data Provider**
```elixir
# If using custom query, test it directly
def mount(_params, _session, socket) do
  socket = assign(socket, :data_provider, {YourApp.Products, :list_products, []})
  {:ok, socket}
end

# Test the function
iex> YourApp.Products.list_products() |> YourApp.Repo.all()
```

3. **Debug Field Configuration**
```elixir
# Verify fields exist in your schema/query
def fields do
  [
    id: %{label: "ID"},
    name: %{label: "Name"},  # Ensure this field exists
    nonexistent_field: %{label: "Bad"}  # This will cause issues
  ]
end
```

### Sorting Not Working

**Problem:** Clicking column headers doesn't sort the table.

**Solutions:**

1. **Enable Sortable Fields**
```elixir
def fields do
  [
    name: %{label: "Name", sortable: true},  # ✅ Sortable
    description: %{label: "Description"}    # ❌ Not sortable
  ]
end
```

2. **Check Field References for Custom Queries**
```elixir
# For joined fields, use assoc option
def fields do
  [
    category_name: %{
      label: "Category",
      sortable: true,
      assoc: {:categories, :name}  # Must match query alias
    }
  ]
end

# Ensure your query has the right alias
def custom_query do
  from p in Product,
    join: c in Category, on: p.category_id == c.id, as: :categories  # Must match assoc
end
```

3. **Verify Table Options**
```elixir
def table_options do
  %{
    sorting: %{
      enabled: true  # Ensure sorting is enabled
    }
  }
end
```

### Filters Not Applying

**Problem:** Filter widgets appear but don't filter data.

**Common Causes & Solutions:**

1. **Boolean Filter Dynamic Query Issues**
```elixir
# ❌ Incorrect dynamic syntax
condition: dynamic([p], p.active = true)  # Wrong: single =

# ✅ Correct dynamic syntax
condition: dynamic([p], p.active == true)  # Right: double ==
```

2. **Select Filter Value Format**
```elixir
# ✅ Correct option format
options: [
  %{label: "Active", value: ["active"]},    # Value must be array
  %{label: "Inactive", value: ["inactive"]} # Even for single values
]

# ❌ Incorrect format
options: [
  %{label: "Active", value: "active"}       # String won't work
]
```

3. **Range Filter Type Mismatch**
```elixir
# ✅ Match field type
price_range: Range.new(:price, "price_range", %{
  type: :number,  # Field is numeric
  min: 0,
  max: 1000
})

# ❌ Wrong type for field
created_range: Range.new(:inserted_at, "created_range", %{
  type: :number,  # Wrong: inserted_at is datetime
  min: 0,
  max: 100
})
```

## Performance Issues

### Slow Table Loading

**Problem:** Table takes a long time to load or times out.

**Diagnostic Steps:**

1. **Check Query Performance**
```elixir
# Add query logging to see what's being executed
config :logger, level: :debug

# Or inspect queries directly
iex> query = YourApp.Products.list_products()
iex> IO.inspect(Ecto.Adapters.SQL.to_sql(:all, YourApp.Repo, query))
```

2. **Profile Large Datasets**
```elixir
# Check record count
iex> YourApp.Repo.aggregate(YourApp.Product, :count)

# Test with smaller page sizes
def table_options do
  %{
    pagination: %{
      enabled: true,
      sizes: [10, 25],        # Smaller pages
      default_size: 10
    }
  }
end
```

3. **Optimize Queries**
```sql
-- Add indexes for sorted/filtered columns
CREATE INDEX idx_products_name ON products(name);
CREATE INDEX idx_products_active ON products(active);
CREATE INDEX idx_products_price ON products(price);

-- For joined queries
CREATE INDEX idx_products_category_id ON products(category_id);
```

4. **Limit Eager Loading**
```elixir
# ❌ Loading too much associated data
from p in Product,
  preload: [:category, :supplier, :reviews, :orders]  # Too much

# ✅ Load only what you need
from p in Product,
  join: c in Category, on: p.category_id == c.id,
  select: %{id: p.id, name: p.name, category_name: c.name}
```

### Memory Issues with Large Exports

**Problem:** Export jobs fail or consume too much memory.

**Solutions:**

1. **Configure Oban Limits**
```elixir
config :your_app, Oban,
  queues: [
    exports: [limit: 2, paused: false],  # Limit concurrent exports
    default: 5
  ]
```

2. **Increase Timeout**
```elixir
config :live_table,
  export_timeout: 600_000  # 10 minutes
```

3. **Monitor Export File Sizes**
```bash
# Check export directory size
du -sh priv/static/exports/

# Clean up old exports
find priv/static/exports/ -name "*.csv" -mtime +7 -delete
```

## Runtime Errors

### "Schema not found" Errors

**Error:** `ArgumentError: schema YourApp.Product is not an Ecto schema`

**Solutions:**

1. **Verify Schema Definition**
```elixir
# Ensure your schema is properly defined
defmodule YourApp.Product do
  use Ecto.Schema
  
  schema "products" do
    field :name, :string
    # ... other fields
  end
end
```

2. **Check Module Compilation**
```bash
# Recompile the schema module
mix compile --force
```

3. **Verify Import/Alias**
```elixir
# Make sure schema is accessible
defmodule YourAppWeb.ProductLive.Index do
  use YourAppWeb, :live_view
  use LiveTable.LiveResource, schema: YourApp.Product  # Full module name
end
```

### "Function not exported" Errors

**Error:** `UndefinedFunctionError: function YourApp.Products.list_products/0 is undefined`

**Solutions:**

1. **Verify Data Provider Function**
```elixir
# Ensure function exists and is exported
defmodule YourApp.Products do
  def list_products do  # Make sure it's public
    # Your query here
  end
  
  # If it needs to accept parameters
  def list_products(_params \\ []) do
    # Your query here
  end
end
```

2. **Check Function Arity**
```elixir
# Data provider should match expected signature
assign(socket, :data_provider, {YourApp.Products, :list_products, []})

# Function should accept right number of arguments
def list_products(params \\ []), do: query
```

### Dynamic Query Errors

**Error:** `Ecto.Query.CompileError: unbound variable`

**Common Issues:**

1. **Binding Mismatch**
```elixir
# ❌ Incorrect binding
condition: dynamic([product], product.active == true)  # Wrong variable name

# ✅ Correct binding  
condition: dynamic([p], p.active == true)  # Matches query binding
```

2. **Missing Join References**
```elixir
# ❌ Referencing non-existent join
condition: dynamic([p, category: c], c.active == true)  # No category join

# ✅ Ensure join exists in query
def custom_query do
  from p in Product,
    join: c in Category, on: p.category_id == c.id, as: :category
end
```

## Export Issues

### PDF Generation Failing

**Error:** `Export failed: Typst not found`

**Solutions:**

1. **Install Typst**
```bash
# macOS
brew install typst

# Ubuntu/Debian
wget https://github.com/typst/typst/releases/latest/download/typst-x86_64-unknown-linux-musl.tar.xz
tar -xf typst-x86_64-unknown-linux-musl.tar.xz
sudo mv typst-x86_64-unknown-linux-musl/typst /usr/local/bin/

# Verify installation
typst --version
```

2. **Check System PATH**
```bash
# Ensure Typst is in PATH
which typst
echo $PATH
```

3. **Verify File Permissions**
```bash
# Check export directory permissions
ls -la priv/static/exports/
chmod 755 priv/static/exports/
```

### CSV Export Character Encoding Issues

**Problem:** Special characters appear corrupted in exported CSV.

**Solutions:**

1. **Configure UTF-8 Encoding**
```elixir
def table_options do
  %{
    exports: %{
      enabled: true,
      formats: [:csv],
      csv: %{
        encoding: :utf8,      # Explicit UTF-8
        delimiter: ","
      }
    }
  }
end
```

2. **Test with Different Applications**
```bash
# Test CSV in terminal
file exports/products_2024-01-01.csv
cat exports/products_2024-01-01.csv | head -5
```

## LiveView Integration Issues

### Handle Params Not Working

**Problem:** URL parameters not updating table state.

**Solutions:**

1. **Implement handle_params**
```elixir
def handle_params(params, _url, socket) do
  # LiveTable needs this to handle URL parameters
  {:noreply, apply_action(socket, socket.assigns.live_action, params)}
end

def apply_action(socket, :index, _params) do
  socket
  |> assign(:page_title, "Products")
end
```

2. **Check Router Configuration**
```elixir
# Ensure live route is properly configured
live "/products", ProductLive.Index, :index
```

### Event Handling Conflicts

**Problem:** Custom LiveView events conflict with LiveTable.

**Solutions:**

1. **Use Unique Event Names**
```elixir
# ❌ Generic event names that might conflict
def handle_event("update", params, socket)

# ✅ Specific event names
def handle_event("update_product", params, socket)
def handle_event("toggle_featured", params, socket)
```

2. **Check Event Propagation**
```elixir
# Use phx-click-away or stop propagation if needed
~H"""
<button phx-click="custom_action" phx-value-id={@record.id}>
  Action
</button>
"""
```

## Debugging Techniques

### Enable Debug Logging

```elixir
# config/dev.exs
config :logger, :console,
  level: :debug,
  format: "[$level] $message\n"

# See LiveTable internal operations
config :live_table,
  debug: true
```

### Inspect Socket State

```elixir
def handle_params(params, _url, socket) do
  IO.inspect(socket.assigns, label: "Socket Assigns")
  IO.inspect(params, label: "URL Params")
  {:noreply, socket}
end
```

### Test Queries in IEx

```elixir
# Test your queries directly
iex> alias YourApp.{Repo, Product}
iex> query = from p in Product, where: p.active == true
iex> Repo.all(query) |> length()

# Test custom data providers
iex> YourApp.Products.list_products() |> Repo.all()
```

### Check Component State

```elixir
# Add temporary debug output to templates
~H"""
<div style="display: none;">
  Debug: <%= inspect(@streams) %>
</div>
<.live_table ... />
"""
```

### Monitor Background Jobs

```elixir
# Check Oban job status
iex> Oban.Job |> YourApp.Repo.all()

# Check specific export jobs
iex> 
Oban.Job 
|> where([j], j.queue == "exports") 
|> order_by([j], desc: j.inserted_at)
|> limit(10)
|> YourApp.Repo.all()
```

## Getting Help

### Check Documentation
- Review API documentation for specific modules
- Look at example implementations
- Check configuration options

### Common Debug Commands

```bash
# Check LiveTable version
mix deps | grep live_table

# Recompile everything
mix deps.clean live_table
mix deps.get
mix compile

# Check for compilation errors
mix compile --warnings-as-errors

# Run tests to verify setup
mix test
```

### Community Resources

- Check GitHub issues for similar problems
- Look at LiveTable examples in the repository
- Search for error messages in issue tracker

### Performance Profiling

```elixir
# Profile memory usage
:observer.start()

# Profile specific operations
:fprof.apply(YourApp.Products, :list_products, [])
:fprof.profile()
:fprof.analyse()
```

Remember: Most LiveTable issues stem from incorrect configuration, missing dependencies, or query problems. Always verify your basic setup before investigating complex issues.