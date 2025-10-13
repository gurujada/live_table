# LiveTable Generator

The `mix live_table.gen.live` task generates Phoenix LiveView files with LiveTable integration, providing a quick way to scaffold CRUD interfaces with advanced table features.

## Overview

This generator wraps `mix phx.gen.live` and enhances the generated index LiveView with:

1. **LiveTable.LiveResource** - Adds the `use LiveTable.LiveResource` declaration
2. **fields/0 function** - Auto-generates field definitions based on schema fields
3. **filters/0 function** - Auto-generates filters based on field types
4. **Template replacement** - Replaces `<.table>` with `<.live_table>` component

## Usage

```bash
mix live_table.gen.live Context Schema table_name field:type field:type ...
```

### Example

```bash
mix live_table.gen.live Accounts User users name:string email:string age:integer active:boolean
```

This generates:

- All standard `phx.gen.live` files (context, schema, migrations, LiveViews, templates)
- Enhanced index LiveView with LiveTable integration
- Automatic field definitions with appropriate options
- Smart filters based on field types

## Generated Fields

The generator analyzes field types and creates appropriate field configurations:

### String Fields
```elixir
name: %{label: "Name", sortable: true, searchable: true}
```
- **sortable**: Enables column sorting
- **searchable**: Enables text search

### Text Fields
```elixir
description: %{label: "Description", searchable: true}
```
- **searchable**: Enables text search (no sorting due to length)

### Numeric Fields (integer, float, decimal)
```elixir
age: %{label: "Age", sortable: true}
```
- **sortable**: Enables column sorting

### Boolean Fields
```elixir
active: %{label: "Active"}
```
- Basic field without sorting/searching

### ID Fields
```elixir
id: %{label: "ID", sortable: true}
```
- **sortable**: Enables column sorting

## Generated Filters

The generator creates appropriate filters based on field types:

### Boolean Filters
For boolean fields like `active:boolean`:

```elixir
active_filter: Boolean.new(:active, "active_filter", %{
  label: "Active",
  condition: dynamic([r], r.active == true)
})
```

### Range Filters
For numeric fields like `age:integer`, `price:decimal`:

```elixir
age_range: Range.new(:age, "age_range", %{
  type: :number,
  label: "Age Range",
  min: 0,
  max: 1000
})
```

### Excluded Fields
The following fields are automatically excluded from filters:
- `id`
- `inserted_at`
- `updated_at`

### Empty Filters
If no filterable fields are present, an empty filters function is generated with a comment:

```elixir
def filters do
  [
    # Add custom filters here
  ]
end
```

## Generated Index LiveView

### Before (phx.gen.live)
```elixir
defmodule MyAppWeb.UserLive.Index do
  use MyAppWeb, :live_view

  alias MyApp.Accounts
  alias MyApp.Accounts.User

  # ... mount, handle_params, etc.
end
```

### After (live_table.gen.live)
```elixir
defmodule MyAppWeb.UserLive.Index do
  use MyAppWeb, :live_view
  use LiveTable.LiveResource, schema: MyApp.Accounts.User

  @impl LiveTable.LiveResource
  def fields do
    [
      name: %{label: "Name", sortable: true, searchable: true},
      email: %{label: "Email", sortable: true, searchable: true},
      age: %{label: "Age", sortable: true},
      active: %{label: "Active"}
    ]
  end

  @impl LiveTable.LiveResource
  def filters do
    [
      age_range: Range.new(:age, "age_range", %{
        type: :number,
        label: "Age Range",
        min: 0,
        max: 1000
      }),
      active_filter: Boolean.new(:active, "active_filter", %{
        label: "Active",
        condition: dynamic([r], r.active == true)
      })
    ]
  end

  alias MyApp.Accounts
  alias MyApp.Accounts.User

  # ... mount, handle_params, etc.
end
```

## Generated Template

### Before (phx.gen.live)
```heex
<.table
  id="users"
  rows={@streams.users}
  row_click={fn {_id, user} -> JS.navigate(~p"/users/#{user}") end}
>
  <:col :let={{_id, user}} label="Name">{user.name}</:col>
  <:col :let={{_id, user}} label="Email">{user.email}</:col>
  <:action :let={{_id, user}}>
    <.link navigate={~p"/users/#{user}"}>Show</.link>
  </:action>
</.table>
```

### After (live_table.gen.live)
```heex
<.live_table
  fields={fields()}
  filters={filters()}
  options={@options}
  streams={@streams}
/>
```

## Features

### Automatic Field Inference
- Analyzes field types from command arguments
- Sets appropriate options (sortable, searchable)
- Humanizes field names for labels

### Smart Filter Generation
- Creates boolean filters for boolean fields
- Creates range filters for numeric fields
- Skips timestamp and ID fields
- Handles cases with no filterable fields

### Template Enhancement
- Replaces standard table with LiveTable component
- Removes column definitions (handled by fields/0)
- Removes action slots (handled by LiveTable)
- Maintains streams-based rendering

### Non-Destructive
- Only modifies the index LiveView and template
- Leaves show, form, and other files untouched
- Preserves all phx.gen.live functionality

## Advanced Customization

After generation, you can customize:

### Field Options
```elixir
def fields do
  [
    name: %{
      label: "Full Name",
      sortable: true,
      searchable: true,
      render: fn user -> 
        "#{user.first_name} #{user.last_name}"
      end
    }
  ]
end
```

### Filter Options
```elixir
def filters do
  [
    price_range: Range.new(:price, "price_range", %{
      type: :number,
      label: "Price Range",
      min: 0,
      max: 10000,  # Adjust max value
      step: 100     # Add step value
    }),
    
    # Add custom filters
    status: Select.new(:status, "status", %{
      label: "Status",
      options: [
        %{label: "Active", value: ["active"]},
        %{label: "Inactive", value: ["inactive"]}
      ]
    })
  ]
end
```

### Table Options
```elixir
def table_options do
  %{
    page_size: 20,
    export_enabled: true,
    view_mode: :table
  }
end
```

## Testing

The generator is fully tested with comprehensive test coverage:

- Field generation for all types
- Filter generation for boolean and numeric types
- Template replacement
- Error handling
- File preservation

## Limitations

1. **Single Schema Only**: Works with single-schema queries. For complex queries with joins, use manual LiveTable setup.

2. **Basic Filters**: Generated filters use default settings. Customize min/max values and other options as needed.

3. **No Custom Queries**: Generated code uses the schema directly. For custom queries, you'll need to manually set up a data provider.

## Next Steps

After running the generator:

1. **Run migrations**:
   ```bash
   mix ecto.migrate
   ```

2. **Customize fields and filters** as needed

3. **Add table options** if you want exports, custom page sizes, etc.

4. **Test your LiveTable** by starting the server and navigating to the generated routes

## See Also

- [LiveTable Quick Start](../quick-start.md)
- [Field Configuration](../api/fields.md)
- [Filter Configuration](../api/filters.md)
- [Table Options](../configuration.md)