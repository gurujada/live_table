# Configuration

LiveTable provides flexible configuration options that can be set at three different levels, with each level taking precedence over the previous one.

## Configuration Hierarchy

1. **LiveTable Defaults** - Built-in sensible defaults
2. **Application-wide Configuration** - Set in your `config.exs`
3. **Per-table Configuration** - Override specific tables via `table_options/0`

## Application-wide Configuration

Configure LiveTable globally in your `config/config.exs`:

```elixir
config :live_table,
  repo: YourApp.Repo,
  pubsub: YourApp.PubSub,
  defaults: %{
    pagination: %{
      enabled: true,
      sizes: [10, 25, 50]
    },
    sorting: %{
      enabled: true,
      default_sort: [id: :asc]
    },
    exports: %{
      enabled: true,
      formats: [:csv, :pdf]
    },
    search: %{
      enabled: true,
      debounce: 300,
      placeholder: "Search...",
      mode: :auto
    },
    mode: :table,
    use_streams: true
  }
```

### Required Configuration

- **`repo`** - Your application's Ecto repository
- **`pubsub`** - Your application's PubSub module for real-time updates

### Optional Configuration

- **`defaults`** - Override default table options

## Per-table Configuration

Override settings for specific tables by implementing `table_options/0`:

```elixir
defmodule YourAppWeb.ProductLive.Index do
  use LiveTable.LiveResource, schema: Product

  def table_options do
    %{
      pagination: %{
        enabled: true,
        sizes: [5, 15, 30]
      },
      sorting: %{
        default_sort: [name: :asc]
      },
      exports: %{
        enabled: false  # Disable exports for this table
      },
      mode: :table
    }
  end
end
```

## Configuration Options

### Pagination Options

Control how pagination behaves in your tables:

```elixir
pagination: %{
  enabled: true,           # Enable/disable pagination
  sizes: [10, 25, 50],     # Available page size options
  default_size: 10,        # Default page size
  max_per_page: 50         # Maximum allowed records per page
}
```

**Options:**
- `enabled` (boolean) - Enable or disable pagination entirely
- `sizes` (list) - Available page size options
- `default_size` (integer) - Default number of records per page
- `max_per_page` (integer) - Maximum allowed records per page (caps user requests)

**Examples:**

```elixir
# Disable pagination (show all records)
pagination: %{enabled: false}

# Custom page sizes with max limit
pagination: %{
  enabled: true,
  sizes: [5, 15, 30],
  max_per_page: 30
}
```

### Sorting Options

Configure sorting behavior and defaults:

```elixir
sorting: %{
  enabled: true,                    # Enable/disable sorting
  default_sort: [id: :asc]         # Default sort order
}
```

**Options:**
- `enabled` (boolean) - Enable or disable sorting
- `default_sort` (keyword list) - Default sort columns and directions

**Examples:**

```elixir
# Default sort order
sorting: %{
  default_sort: [name: :asc]
}

# Disable sorting entirely
sorting: %{
  enabled: false
}
```

### Export Options

Control export functionality:

```elixir
exports: %{
  enabled: true,                        # Enable/disable exports
  formats: [:csv, :pdf]                # Available export formats
}
```

**Options:**
- `enabled` (boolean) - Enable or disable exports
- `formats` (list) - Available formats (`:csv`, `:pdf`, or both)

**Examples:**

```elixir
# CSV only
exports: %{
  enabled: true,
  formats: [:csv]
}

# Disable exports
exports: %{
  enabled: false
}
```

### Search Options

Configure the global search behavior:

```elixir
search: %{
  enabled: true,                   # Enable/disable search
  debounce: 300,                  # Debounce time in milliseconds
  placeholder: "Search...",       # Search input placeholder text
  mode: :auto,                    # :auto, :ilike, :like, :like_lower
  # db: :postgres                 # Optional: :postgres, :sqlite, :mysql, :mssql, etc.
  # adapter: Ecto.Adapters.SQLite3 # Optional: explicit adapter override
}
```

**Options:**
- `enabled` (boolean) - Enable or disable global search
- `debounce` (integer) - Delay before search executes (milliseconds)
- `placeholder` (string) - Search input placeholder text
- `mode` (atom) - Search mode (`:auto` uses adapter defaults, `:ilike` Postgres, `:like` case-sensitive, `:like_lower` case-insensitive via `lower(field) LIKE`)
- `db` (atom|string) - Optional database hint used when `mode: :auto`
- `adapter` (module) - Optional adapter override used when `mode: :auto`

### View Mode Options

Configure table display modes:

```elixir
mode: :table  # or :card
```

**Table Mode:**

```elixir
mode: :table
```

**Card Mode:**

```elixir
mode: :card,
card_component: &product_card/1
```

### Streams vs Assigns

LiveTable supports two data handling modes controlled by `use_streams`:

```elixir
# Default: Use Phoenix LiveView streams (recommended)
use_streams: true   # Default

# Alternative: Use traditional assigns
use_streams: false
```

**When `use_streams: true` (default):**
- Uses Phoenix LiveView streams for efficient DOM updates
- Pass `streams={@streams}` to the live_table component
- Better performance with large datasets and real-time updates

**When `use_streams: false`:**
- Uses traditional assigns for data
- Pass `streams={@resources}` to the live_table component
- Simpler for small datasets or when streams aren't needed

**Template usage:**

```elixir
# With streams (default)
<.live_table
  fields={fields()}
  filters={filters()}
  options={@options}
  streams={@streams}
/>

# With assigns
<.live_table
  fields={fields()}
  filters={filters()}
  options={@options}
  streams={@resources}
/>
```

### Actions Assign

Row actions are configured as an optional component assign, not a field. Accepted shapes:

- `[]` (default): No actions.
- Keyword list of 1-arity function components: `[edit: &edit_action/1, delete: &delete_action/1]`.
- Map with label and items: `%{label: "Actions", items: [edit: &edit_action/1, delete: &delete_action/1]}`.

Each action must be a 1-arity function component that receives assigns with `:record` corresponding to the current row.

Example action components and usage:

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

# 1-arity function components receive assigns with :record

defp edit_action(assigns) do
  ~H"""
  <.link navigate={~p"/products/#{@record.id}"} class="text-blue-600 hover:text-blue-800 text-sm">
  Show
  </.link>
  """
end

defp delete_action(assigns) do
  ~H"""
  <button phx-click="delete" phx-value-id={@record.id} class="text-red-600 hover:text-red-800 text-sm">
    Delete
  </button>
  """
end
```

Pass the actions assign to the component:

```elixir
<.live_table
  fields={fields()}
  filters={filters()}
  options={@options}
  streams={@streams}
  actions={actions()}
/>
```

Notes:
- Use the `actions` assign for row-level actions (view/edit/delete). For per-cell interactive elements, prefer a field renderer with `&function/2`.
- When using the keyword list form, a default label is applied in the UI; use the map form to customize the visible label.

### Custom Components

LiveTable allows complete UI customization through custom components. You can replace any section of the table interface with your own implementation while still benefiting from LiveTable's data handling, filtering, and state management.

```elixir
# Override entire sections
def table_options do
  %{
    custom_header: {MyApp.CustomComponents, :header},
    custom_controls: {MyApp.CustomComponents, :controls},
    custom_content: {MyApp.CustomComponents, :content},
    custom_footer: {MyApp.CustomComponents, :footer}
  }
end
```

**Available customizations:**
- `custom_header` - Replace the entire header section (search, filters, controls)
- `custom_controls` - Replace only the header controls bar (search, per-page, filter toggle)
- `custom_content` - Replace the table/card content area
- `custom_footer` - Replace the footer section (pagination, exports)

Note: When `custom_header` is provided, it replaces the full header. In that case `custom_controls` is ignored.

### Real-World Example: College Counselling Interface

This example shows a sophisticated custom header that integrates transformers with a beautiful UI:

```elixir
# table_options with custom header
def table_options do
  %{
    mode: :card,
    card_component: &CounsellingWeb.CollegeComponent.college_component/1,
    custom_header: {CounsellingWeb.CollegeLive.CustomHeader, :custom_header}
  }
end

# Custom header component
defmodule CounsellingWeb.CollegeLive.CustomHeader do
  use Phoenix.Component

  def custom_header(assigns) do
    ~H"""
    <section class="relative mb-6 -mt-4 sm:mb-8 sm:-mt-8 lg:mb-12 lg:-mt-12">
      <div class="bg-white dark:bg-gray-800 shadow-2xl border border-gray-100 dark:border-gray-700 rounded-xl sm:rounded-2xl">
        <div class="p-4 sm:p-6 lg:p-8">
          <!-- Hero section with transformer input -->
          <div class="mb-6 p-4 bg-gradient-to-r from-violet-50 to-purple-50 dark:from-violet-900/20 dark:to-purple-900/20 border border-violet-200 dark:border-violet-800 rounded-xl sm:p-6">
            <div class="flex items-center mb-3 sm:mb-4">
              <div class="w-1 h-6 mr-3 bg-gradient-to-b from-violet-500 to-purple-600 rounded-full sm:h-8 sm:mr-4"></div>
              <h3 class="text-lg font-bold text-violet-900 dark:text-violet-100 sm:text-xl">
                Find Colleges for Your Rank
              </h3>
            </div>

            <div class="grid gap-3 sm:grid-cols-2 lg:grid-cols-3 sm:gap-4">
              <!-- Transformer input for rank filtering -->
              <div>
                <.form for={%{}} phx-debounce={get_in(@table_options, [:search, :debounce])} phx-change="sort">
                  <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                    Your JEE Rank <span class="text-xs text-gray-500">(Saved automatically)</span>
                  </label>
                  <input
                    type="number"
                    placeholder="e.g., 15000"
                    name="filters[rank][value]"
                    value={
                      Map.get(@options["filters"], :rank) &&
                        Map.get(@options["filters"], :rank).options.applied_data["value"]
                    }
                    class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-violet-500"
                  />
                </.form>
              </div>

              <!-- Category selector -->
              <div>
                <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                  Category
                </label>
                <select class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-violet-500">
                  <option>General</option>
                  <option>OBC-NCL</option>
                  <option>SC</option>
                  <option>ST</option>
                  <option>EWS</option>
                </select>
              </div>
            </div>
          </div>

          <!-- Advanced filters with transformers -->
          <div class="grid gap-4 sm:grid-cols-2 lg:grid-cols-4 mb-6">
            <!-- Search -->
            <div>
              <.form for={%{}} phx-change="sort">
                <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                  Search Colleges
                </label>
                <div class="relative">
                  <input
                    type="text"
                    name="search"
                    value={@options["filters"]["search"]}
                    placeholder="Search by name or location..."
                    class="w-full pl-10 pr-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-violet-500"
                  />
                  <svg class="absolute left-3 top-2.5 w-4 h-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"></path>
                  </svg>
                </div>
              </.form>
            </div>

            <!-- NIRF Ranking transformer -->
            <div>
              <.form for={%{}} phx-change="sort">
                <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                  NIRF Ranking
                </label>
                <select name="filters[limit_results][nirf]" class="w-full px-3 py-2 border border-gray-300 rounded-lg">
                  <option selected={
                    Map.get(@options["filters"], :limit_results) &&
                      Map.get(@options["filters"], :limit_results).options.applied_data["nirf"] == "All Rankings"
                  }>All Rankings</option>
                  <option selected={
                    Map.get(@options["filters"], :limit_results) &&
                      Map.get(@options["filters"], :limit_results).options.applied_data["nirf"] == "Top 10"
                  }>Top 10</option>
                  <option selected={
                    Map.get(@options["filters"], :limit_results) &&
                      Map.get(@options["filters"], :limit_results).options.applied_data["nirf"] == "Top 25"
                  }>Top 25</option>
                </select>
              </.form>
            </div>

            <!-- Sort transformer -->
            <div>
              <.form for={%{}} phx-change="sort">
                <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                  Sort By
                </label>
                <select name="filters[sort_mode][sort_by]" class="w-full px-3 py-2 border border-gray-300 rounded-lg">
                  <option>NIRF Ranking</option>
                  <option>Name (A-Z)</option>
                  <option>Name (Z-A)</option>
                </select>
              </.form>
            </div>
          </div>

          <!-- Boolean filters for institution types -->
          <div class="mb-4">
            <.form for={%{}} phx-change="sort">
              <span class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-3">
                Institution Type
              </span>
              <div class="flex flex-wrap gap-x-6">
                <.input
                  :for={{id, %Boolean{field: :class, options: %{label: label}}} <- @filters}
                  type="checkbox"
                  name={"filters[#{id}]"}
                  label={label}
                  checked={Map.has_key?(@options["filters"], id)}
                />
              </div>
            </.form>
          </div>

          <!-- Clear filters -->
          <div class="flex items-center justify-end pt-4 border-t border-gray-200">
            <.link
              :if={@options["filters"] != %{"search" => ""}}
              phx-click="sort"
              phx-value-clear_filters="true"
              class="text-sm text-gray-500 hover:text-gray-700 transition-colors"
            >
              Clear All Filters
            </.link>
          </div>
        </div>
      </div>
    </section>
    """
  end
end
```

### Complete UI Control

With custom components, you have complete control over:

- **Layout and styling** - Use any CSS framework or design system
- **User interactions** - Implement custom form controls and behaviors
- **Data presentation** - Create sophisticated filtering interfaces
- **Integration** - Combine LiveTable data with your own UI components
- **Responsive design** - Build mobile-optimized interfaces

**Key Benefits:**
- Keep LiveTable's powerful data handling and state management
- Replace only the UI parts you want to customize
- Maintain URL persistence and real-time updates
- Integrate seamlessly with your existing design system

The college counselling example shows how you can create a completely custom interface that still benefits from LiveTable's transformer system, URL persistence, and efficient data handling.

## Environment-specific Configuration

Configure different settings per environment:

```elixir
# config/dev.exs
config :live_table,
  defaults: %{
    pagination: %{sizes: [5, 10]},  # Smaller pages in development
    exports: %{enabled: false}       # Disable exports in dev
  }

# config/prod.exs
config :live_table,
  defaults: %{
    pagination: %{sizes: [25, 50, 100]},
    exports: %{enabled: true}
  }
```

## Oban Configuration

LiveTable uses Oban to process CSV/PDF export jobs in the background.

Installer behavior:
- When you run mix live_table.install, you will be prompted: "Configure Oban for exports now?"
- If you choose Yes:
  - Adds {:oban, "~> 2.19"} to your mix.exs
  - Fetches and compiles dependencies
  - Adds a minimal Oban configuration to config/config.exs (repo, plugins, queues: [exports: 10])
  - Prints a next step showing how to start Oban in your supervision tree
- If you choose No:
  - You can add Oban later manually using the configuration shown below.

Configure background job processing for exports:

```elixir
# config/config.exs
config :your_app, Oban,
  repo: YourApp.Repo,
  engine: Oban.Engines.Basic,
  notifier: Oban.Notifiers.Postgres,
  plugins: [
    Oban.Plugins.Pruner,
    {Oban.Plugins.Cron,
     crontab: [
       # Clean up old export files daily at 2 AM
       {"0 2 * * *", YourApp.Workers.CleanupExports}
     ]}
  ],
  queues: [
    exports: 10,        # Export processing queue
    default: 5          # Other background jobs
  ]
```

### Oban Web (Optional)

Monitor export jobs with Oban Web:

```elixir
# lib/your_app_web/router.ex
import Oban.Web.Router

scope "/admin" do
  pipe_through [:browser, :admin_required]
  oban_dashboard "/oban"
end
```

## Complete Example

Here's a comprehensive configuration example:

```elixir
# config/config.exs
config :live_table,
  repo: YourApp.Repo,
  pubsub: YourApp.PubSub,
  defaults: %{
    pagination: %{
      enabled: true,
      sizes: [10, 25, 50]
    },
    sorting: %{
      enabled: true,
      default_sort: [id: :asc]
    },
    exports: %{
      enabled: true,
      formats: [:csv, :pdf]
    },
    search: %{
      enabled: true,
      debounce: 300,
      placeholder: "Search..."
    },
    mode: :table,
    use_streams: true
  }

# Per-table override
defmodule YourAppWeb.ProductLive.Index do
  def table_options do
    %{
      pagination: %{sizes: [5, 15, 30]},
      sorting: %{default_sort: [name: :asc]},
      exports: %{formats: [:csv]},
      mode: :card,
      card_component: &product_card/1
    }
  end
end
```

## Complete Configuration Reference

Based on the actual table configuration, here are all available options:

```elixir
# All available configuration options
config :live_table,
  defaults: %{
    pagination: %{
      enabled: true,
      sizes: [10, 25, 50],
      default_size: 10,
      max_per_page: 50
    },
    sorting: %{
      enabled: true,
      default_sort: [id: :asc]
    },
    exports: %{
      enabled: true,
      formats: [:csv, :pdf]
    },
    search: %{
      enabled: true,
      debounce: 300,
      placeholder: "Search..."
    },
    mode: :table,
    use_streams: true
  }
```


### Required Configuration

- **`repo`** - Your application's Ecto repository
- **`pubsub`** - Your application's PubSub module for real-time updates

### Optional Configuration

- **`defaults`** - Override default table options

## Per-table Configuration

Override settings for specific tables by implementing `table_options/0`:

```elixir
defmodule YourAppWeb.ProductLive.Index do
  use LiveTable.LiveResource, schema: Product

  def table_options do
    %{
      pagination: %{
        enabled: true,
        sizes: [5, 15, 30]
      },
      sorting: %{
        default_sort: [name: :asc]
      },
      exports: %{
        enabled: false  # Disable exports for this table
      },
      mode: :table
    }
  end
end
```

## Configuration Options

### Pagination Options

Control how pagination behaves in your tables:

```elixir
pagination: %{
  enabled: true,           # Enable/disable pagination
  sizes: [10, 25, 50]     # Available page size options
}
```

**Options:**
- `enabled` (boolean) - Enable or disable pagination entirely
- `sizes` (list) - Available page size options

**Examples:**

```elixir
# Disable pagination (show all records)
pagination: %{enabled: false}

# Custom page sizes
pagination: %{
  enabled: true,
  sizes: [5, 15, 30]
}
```

### Sorting Options

Configure sorting behavior and defaults:

```elixir
sorting: %{
  enabled: true,                    # Enable/disable sorting
  default_sort: [id: :asc]         # Default sort order
}
```

**Options:**
- `enabled` (boolean) - Enable or disable sorting
- `default_sort` (keyword list) - Default sort columns and directions

**Examples:**

```elixir
# Default sort order
sorting: %{
  default_sort: [name: :asc]
}

# Disable sorting entirely
sorting: %{
  enabled: false
}
```

### Export Options

Control export functionality:

```elixir
exports: %{
  enabled: true,                        # Enable/disable exports
  formats: [:csv, :pdf]                # Available export formats
}
```

**Options:**
- `enabled` (boolean) - Enable or disable exports
- `formats` (list) - Available formats (`:csv`, `:pdf`, or both)

**Examples:**

```elixir
# CSV only
exports: %{
  enabled: true,
  formats: [:csv]
}

# Disable exports
exports: %{
  enabled: false
}
```

### Search Options

Configure the global search behavior:

```elixir
search: %{
  enabled: true,                   # Enable/disable search
  debounce: 300,                  # Debounce time in milliseconds
  placeholder: "Search...",       # Search input placeholder text
  mode: :auto,                    # :auto, :ilike, :like, :like_lower
  # db: :postgres                 # Optional: :postgres, :sqlite, :mysql, :mssql, etc.
  # adapter: Ecto.Adapters.SQLite3 # Optional: explicit adapter override
}
```

**Options:**
- `enabled` (boolean) - Enable or disable global search
- `debounce` (integer) - Delay before search executes (milliseconds)
- `placeholder` (string) - Search input placeholder text
- `mode` (atom) - Search mode (`:auto` uses adapter defaults, `:ilike` Postgres, `:like` case-sensitive, `:like_lower` case-insensitive via `lower(field) LIKE`)
- `db` (atom|string) - Optional database hint used when `mode: :auto`
- `adapter` (module) - Optional adapter override used when `mode: :auto`

### View Mode Options

Configure table display modes:

```elixir
mode: :table  # or :card
```

**Table Mode:**
```elixir
mode: :table
```

**Card Mode:**
```elixir
mode: :card,
card_component: &product_card/1
```

### Streams vs Assigns

LiveTable supports two data handling modes controlled by `use_streams`:

```elixir
# Default: Use Phoenix LiveView streams (recommended)
use_streams: true   # Default

# Alternative: Use traditional assigns
use_streams: false
```

**When `use_streams: true` (default):**
- Uses Phoenix LiveView streams for efficient DOM updates
- Pass `streams={@streams}` to the live_table component
- Better performance with large datasets and real-time updates

**When `use_streams: false`:**
- Uses traditional assigns for data
- Pass `streams={@resources}` to the live_table component
- Simpler for small datasets or when streams aren't needed

**Template usage:**
```elixir
# With streams (default)
<.live_table
  fields={fields()}
  filters={filters()}
  options={@options}
  streams={@streams}
/>

# With assigns
<.live_table
  fields={fields()}
  filters={filters()}
  options={@options}
  streams={@resources}
/>
```

### Custom Components

LiveTable allows complete UI customization through custom components. You can replace any section of the table interface with your own implementation while still benefiting from LiveTable's data handling, filtering, and state management.

```elixir
# Override entire sections
def table_options do
  %{
    custom_header: {MyApp.CustomComponents, :header},
    custom_controls: {MyApp.CustomComponents, :controls},
    custom_content: {MyApp.CustomComponents, :content},
    custom_footer: {MyApp.CustomComponents, :footer}
  }
end
```

**Available customizations:**
- `custom_header` - Replace the entire header section (search, filters, controls)
- `custom_controls` - Replace only the header controls bar (search, per-page, filter toggle)
- `custom_content` - Replace the table/card content area
- `custom_footer` - Replace the footer section (pagination, exports)

Note: When `custom_header` is provided, it replaces the full header. In that case `custom_controls` is ignored.

### Real-World Example: College Counselling Interface

This example shows a sophisticated custom header that integrates transformers with a beautiful UI:

```elixir
# table_options with custom header
def table_options do
  %{
    mode: :card,
    card_component: &CounsellingWeb.CollegeComponent.college_component/1,
    custom_header: {CounsellingWeb.CollegeLive.CustomHeader, :custom_header}
  }
end

# Custom header component
defmodule CounsellingWeb.CollegeLive.CustomHeader do
  use Phoenix.Component

  def custom_header(assigns) do
    ~H"""
    <section class="relative mb-6 -mt-4 sm:mb-8 sm:-mt-8 lg:mb-12 lg:-mt-12">
      <div class="bg-white dark:bg-gray-800 shadow-2xl border border-gray-100 dark:border-gray-700 rounded-xl sm:rounded-2xl">
        <div class="p-4 sm:p-6 lg:p-8">
          <!-- Hero section with transformer input -->
          <div class="mb-6 p-4 bg-gradient-to-r from-violet-50 to-purple-50 dark:from-violet-900/20 dark:to-purple-900/20 border border-violet-200 dark:border-violet-800 rounded-xl sm:p-6">
            <div class="flex items-center mb-3 sm:mb-4">
              <div class="w-1 h-6 mr-3 bg-gradient-to-b from-violet-500 to-purple-600 rounded-full sm:h-8 sm:mr-4"></div>
              <h3 class="text-lg font-bold text-violet-900 dark:text-violet-100 sm:text-xl">
                Find Colleges for Your Rank
              </h3>
            </div>

            <div class="grid gap-3 sm:grid-cols-2 lg:grid-cols-3 sm:gap-4">
              <!-- Transformer input for rank filtering -->
              <div>
                <.form for={%{}} phx-debounce={get_in(@table_options, [:search, :debounce])} phx-change="sort">
                  <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                    Your JEE Rank <span class="text-xs text-gray-500">(Saved automatically)</span>
                  </label>
                  <input
                    type="number"
                    placeholder="e.g., 15000"
                    name="filters[rank][value]"
                    value={
                      Map.get(@options["filters"], :rank) &&
                        Map.get(@options["filters"], :rank).options.applied_data["value"]
                    }
                    class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-violet-500"
                  />
                </.form>
              </div>

              <!-- Category selector -->
              <div>
                <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                  Category
                </label>
                <select class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-violet-500">
                  <option>General</option>
                  <option>OBC-NCL</option>
                  <option>SC</option>
                  <option>ST</option>
                  <option>EWS</option>
                </select>
              </div>
            </div>
          </div>

          <!-- Advanced filters with transformers -->
          <div class="grid gap-4 sm:grid-cols-2 lg:grid-cols-4 mb-6">
            <!-- Search -->
            <div>
              <.form for={%{}} phx-change="sort">
                <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                  Search Colleges
                </label>
                <div class="relative">
                  <input
                    type="text"
                    name="search"
                    value={@options["filters"]["search"]}
                    placeholder="Search by name or location..."
                    class="w-full pl-10 pr-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-violet-500"
                  />
                  <svg class="absolute left-3 top-2.5 w-4 h-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"></path>
                  </svg>
                </div>
              </.form>
            </div>

            <!-- NIRF Ranking transformer -->
            <div>
              <.form for={%{}} phx-change="sort">
                <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                  NIRF Ranking
                </label>
                <select name="filters[limit_results][nirf]" class="w-full px-3 py-2 border border-gray-300 rounded-lg">
                  <option selected={
                    Map.get(@options["filters"], :limit_results) &&
                      Map.get(@options["filters"], :limit_results).options.applied_data["nirf"] == "All Rankings"
                  }>All Rankings</option>
                  <option selected={
                    Map.get(@options["filters"], :limit_results) &&
                      Map.get(@options["filters"], :limit_results).options.applied_data["nirf"] == "Top 10"
                  }>Top 10</option>
                  <option selected={
                    Map.get(@options["filters"], :limit_results) &&
                      Map.get(@options["filters"], :limit_results).options.applied_data["nirf"] == "Top 25"
                  }>Top 25</option>
                </select>
              </.form>
            </div>

            <!-- Sort transformer -->
            <div>
              <.form for={%{}} phx-change="sort">
                <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                  Sort By
                </label>
                <select name="filters[sort_mode][sort_by]" class="w-full px-3 py-2 border border-gray-300 rounded-lg">
                  <option>NIRF Ranking</option>
                  <option>Name (A-Z)</option>
                  <option>Name (Z-A)</option>
                </select>
              </.form>
            </div>
          </div>

          <!-- Boolean filters for institution types -->
          <div class="mb-4">
            <.form for={%{}} phx-change="sort">
              <span class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-3">
                Institution Type
              </span>
              <div class="flex flex-wrap gap-x-6">
                <.input
                  :for={{id, %Boolean{field: :class, options: %{label: label}}} <- @filters}
                  type="checkbox"
                  name={"filters[#{id}]"}
                  label={label}
                  checked={Map.has_key?(@options["filters"], id)}
                />
              </div>
            </.form>
          </div>

          <!-- Clear filters -->
          <div class="flex items-center justify-end pt-4 border-t border-gray-200">
            <.link
              :if={@options["filters"] != %{"search" => ""}}
              phx-click="sort"
              phx-value-clear_filters="true"
              class="text-sm text-gray-500 hover:text-gray-700 transition-colors"
            >
              Clear All Filters
            </.link>
          </div>
        </div>
      </div>
    </section>
    """
  end
end
```

### Complete UI Control

With custom components, you have complete control over:

- **Layout and styling** - Use any CSS framework or design system
- **User interactions** - Implement custom form controls and behaviors
- **Data presentation** - Create sophisticated filtering interfaces
- **Integration** - Combine LiveTable data with your own UI components
- **Responsive design** - Build mobile-optimized interfaces

**Key Benefits:**
- Keep LiveTable's powerful data handling and state management
- Replace only the UI parts you want to customize
- Maintain URL persistence and real-time updates
- Integrate seamlessly with your existing design system

The college counselling example shows how you can create a completely custom interface that still benefits from LiveTable's transformer system, URL persistence, and efficient data handling.

## Environment-specific Configuration

Configure different settings per environment:

```elixir
# config/dev.exs
config :live_table,
  defaults: %{
    pagination: %{sizes: [5, 10]},  # Smaller pages in development
    exports: %{enabled: false}       # Disable exports in dev
  }

# config/prod.exs
config :live_table,
  defaults: %{
    pagination: %{sizes: [25, 50, 100]},
    exports: %{enabled: true}
  }
```

## Oban Configuration

LiveTable uses Oban to process CSV/PDF export jobs in the background.

Installer behavior:
- When you run mix live_table.install, you will be prompted: "Configure Oban for exports now?"
- If you choose Yes:
  - Adds {:oban, "~> 2.19"} to your mix.exs
  - Fetches and compiles dependencies
  - Adds a minimal Oban configuration to config/config.exs (repo, plugins, queues: [exports: 10])
  - Prints a next step showing how to start Oban in your supervision tree
- If you choose No:
  - You can add Oban later manually using the configuration shown below.

Configure background job processing for exports:

```elixir
# config/config.exs
config :your_app, Oban,
  repo: YourApp.Repo,
  engine: Oban.Engines.Basic,
  notifier: Oban.Notifiers.Postgres,
  plugins: [
    Oban.Plugins.Pruner,
    {Oban.Plugins.Cron,
     crontab: [
       # Clean up old export files daily at 2 AM
       {"0 2 * * *", YourApp.Workers.CleanupExports}
     ]}
  ],
  queues: [
    exports: 10,        # Export processing queue
    default: 5          # Other background jobs
  ]
```

### Oban Web (Optional)

Monitor export jobs with Oban Web:

```elixir
# lib/your_app_web/router.ex
import Oban.Web.Router

scope "/admin" do
  pipe_through [:browser, :admin_required]
  oban_dashboard "/oban"
end
```

## Complete Example

Here's a comprehensive configuration example:

```elixir
# config/config.exs
config :live_table,
  repo: YourApp.Repo,
  pubsub: YourApp.PubSub,
  defaults: %{
    pagination: %{
      enabled: true,
      sizes: [10, 25, 50]
    },
    sorting: %{
      enabled: true,
      default_sort: [id: :asc]
    },
    exports: %{
      enabled: true,
      formats: [:csv, :pdf]
    },
    search: %{
      enabled: true,
      debounce: 300,
      placeholder: "Search..."
    },
    mode: :table,
    use_streams: true
  }

# Per-table override
defmodule YourAppWeb.ProductLive.Index do
  def table_options do
    %{
      pagination: %{sizes: [5, 15, 30]},
      sorting: %{default_sort: [name: :asc]},
      exports: %{formats: [:csv]},
      mode: :card,
      card_component: &product_card/1
    }
  end
end
```
