# LiveTable Overview

LiveTable is a powerful Phoenix LiveView component library that transforms data presentation in your web applications. It provides everything you need to build sophisticated, interactive data tables with minimal code.

## What is LiveTable?

LiveTable is designed for developers who need to present complex data in an intuitive, interactive way. Whether you're building admin dashboards, e-commerce catalogs, or analytics platforms, LiveTable provides the tools to create rich data experiences without the complexity.

### Key Benefits

- **Developer-Friendly** - Minimal boilerplate, maximum functionality
- **Performance-First** - Optimized for large datasets with streaming and pagination
- **Highly Customizable** - Adapt to any design system or use case
- **Real-time Ready** - Built for Phoenix LiveView's real-time capabilities
- **Production-Tested** - Handles millions of records efficiently

## Core Features

### 🔍 Smart Filtering
Create powerful filter interfaces with minimal configuration:
- **Boolean filters** for toggle states (active/inactive, featured/regular)
- **Range filters** for numeric values, dates, and times
- **Select filters** with static options or dynamic database queries
- **Transformers** for complex custom filters that can modify entire queries
- **Full-text search** across multiple fields
- **URL persistence** so users can bookmark and share filtered views

### 📊 Advanced Sorting
Flexible sorting options that scale:
- **Single-column sorting** with visual indicators
- **Multi-column sorting** with shift+click
- **Custom sort logic** for computed fields
- **Database-optimized** queries for performance

### 📄 Intelligent Pagination
Handle datasets of any size:
- **Configurable page sizes** (10, 25, 50, 100+)
- **Efficient querying** with LIMIT/OFFSET optimization
- **User preferences** maintained across sessions
- **Performance monitoring** for large datasets

### 📤 Professional Exports
Generate reports without blocking your UI:
- **CSV exports** for spreadsheet analysis
- **PDF reports** with professional formatting using Typst
- **Background processing** via Oban for large datasets
- **Custom formatting** and filtering in exports

### 🎨 Flexible Display Modes
Present data the way your users need it:
- **Table mode** for traditional row/column layouts
- **Card mode** for rich, visual presentations
- **Custom components** for specialized displays
- **Complete UI customization** with custom headers, content, and footers
- **Responsive design** that works on all devices

### ⚡ Real-time Updates
Built for modern web applications:
- **LiveView integration** with automatic updates
- **Streams or assigns support** for flexible data handling
- **Event handling** for user interactions
- **State management** with URL synchronization

## Architecture Overview

LiveTable uses a three-tier architecture that separates concerns and maximizes flexibility:

### 1. Data Layer
- **Schema Integration** - Direct Ecto schema support for simple tables
- **Custom Queries** - Full control with complex joins and computed fields
- **Data Providers** - Flexible functions that return queryable data

### 2. Configuration Layer
- **Fields** - Define what data to display and how
- **Filters** - Configure filtering options and behavior
- **Options** - Control pagination, sorting, exports, and display modes

### 3. Presentation Layer
- **Components** - Customizable UI components for every element
- **Templates** - Override default layouts with your own
- **Styling** - Full Tailwind CSS integration with custom themes

## Usage Patterns

### Simple Tables
Perfect for basic CRUD operations and data browsing:

```elixir
defmodule YourAppWeb.ProductLive.Index do
  use YourAppWeb, :live_view
  use LiveTable.LiveResource, schema: YourApp.Product

  def fields do
    [
      name: %{label: "Product Name", sortable: true, searchable: true},
      price: %{label: "Price", sortable: true},
      stock: %{label: "Stock", sortable: true}
    ]
  end
end
```

### Complex Analytics
For advanced reporting and data analysis:

```elixir
defmodule YourAppWeb.SalesReportLive.Index do
  use YourAppWeb, :live_view
  use LiveTable.LiveResource

  def mount(_params, _session, socket) do
    socket = assign(socket, :data_provider, {Reports, :sales_summary, []})
    {:ok, socket}
  end

  def fields do
    [
      product_name: %{label: "Product", sortable: true, searchable: true},
      revenue: %{label: "Revenue", sortable: true, renderer: &format_currency/1},
      units_sold: %{label: "Units", sortable: true},
      avg_price: %{label: "Avg Price", sortable: true, renderer: &format_currency/1}
    ]
  end
end
```

## When to Use LiveTable

### ✅ Perfect For
- **Admin interfaces** with user, order, and product management
- **E-commerce catalogs** with filtering and search
- **Analytics dashboards** with large datasets and custom metrics
- **CRM systems** with customer and lead tracking
- **Inventory management** with stock monitoring
- **Financial reports** with complex calculations and transformations
- **Any data-heavy application** requiring advanced filtering and customization

### ⚠️ Consider Alternatives For
- **Simple lists** without sorting or filtering needs
- **Static data** that doesn't change frequently
- **Non-tabular data** better suited for other presentations
- **Real-time streaming** data that updates continuously

## Performance Characteristics

LiveTable is designed to handle real-world application demands:

### Scalability
- **Large datasets** - Tested with 1M+ records
- **Complex queries** - Efficient handling of joins and aggregations
- **Concurrent users** - Optimized for multi-user environments
- **Memory efficiency** - Streaming exports for large files

### Optimization Strategies
- **Query optimization** - Automatic LIMIT/OFFSET for pagination
- **Index-aware** - Designed to work with database indexes
- **Lazy loading** - Components render only when needed
- **Background processing** - Exports don't block the UI

## Styling and Themes

- Daisy semantics: Uses DaisyUI class names like `btn`, `select`, `input`, `dropdown`, and `menu` for consistent UI.
- Tailwind-only support: LiveTable ships a small Tailwind-based shim in `live-table.css` so everything looks good even without DaisyUI installed.
- DaisyUI integration: If your app includes DaisyUI, the components automatically adopt your active Daisy theme without extra configuration.
- Dark mode: Respects Tailwind `dark:` classes and DaisyUI theme tokens. In shim-only mode, it follows your Tailwind dark strategy (e.g., class or media).
- How to enable: Import `../../deps/live_table/priv/static/live-table.css` in your app CSS. With DaisyUI present, its styles cleanly override the shim.
- Theming: Switch Daisy themes via the `data-theme` attribute on `html`/`body` or via your Daisy configuration. LiveTable doesn’t set a theme.

## Integration Requirements

### Dependencies
- **Phoenix LiveView 1.0+** - Core framework dependency
- **Ecto 3.10+** - Database query interface
- **Oban 2.19+** - Background job processing for exports
- **Tailwind CSS** - Styling framework

### Optional Dependencies
- **Typst** - PDF generation engine for reports
- **Phoenix PubSub** - Real-time updates across users
- **Custom CSS frameworks** - Alternative to Tailwind

## Learning Path

### 1. Start Here
- [Installation Guide](installation.md) - Get LiveTable running
- [Quick Start](quick-start.md) - Build your first table in 5 minutes
- [Simple Examples](examples/simple-table.md) - Basic patterns and usage

### 2. Core Concepts
- [Fields API](api/fields.md) - Configure data display
- [Filters API](api/filters.md) - Add filtering capabilities
- [Table Options](api/table-options.md) - Control behavior and appearance

### 3. Advanced Features
- [Complex Queries](examples/complex-queries.md) - Joins and computed fields
- [Transformers API](api/transformers.md) - Ultimate filtering power
- [Exports API](api/exports.md) - PDF and CSV generation
- [Custom Components](configuration.md#custom-components) - Complete UI control

### 4. Production Ready
- [Performance Guide](troubleshooting.md#performance-issues) - Optimize for scale
- [Troubleshooting](troubleshooting.md) - Solve common issues
- [Configuration Reference](configuration.md) - Complete options guide

## Real-World Examples

### E-commerce Product Catalog
```elixir
# Feature-rich product listing with category filtering,
# price ranges, and stock status
def fields do
  [
    image: %{label: "Image", renderer: &product_image/1},
    name: %{label: "Product", sortable: true, searchable: true},
    category: %{label: "Category", sortable: true},
    price: %{label: "Price", sortable: true, renderer: &currency/1},
    stock: %{label: "Stock", sortable: true, renderer: &stock_status/2},
    actions: %{label: "Actions", renderer: &product_actions/2}
  ]
end
```

Actions are configured as an optional component assign rather than a field:

```elixir
<.live_table ... actions={%{label: "Actions", items: [view: &view_action/1]}} />
```

See Quick Start for details on accepted shapes and examples.

### Customer Analytics Dashboard
```elixir
# Customer lifetime value analysis with cohort filtering,
# revenue tracking, and churn prediction
def fields do
  [
    customer_name: %{label: "Customer", sortable: true, searchable: true},
    total_orders: %{label: "Orders", sortable: true},
    lifetime_value: %{label: "LTV", sortable: true, renderer: &currency/1},
    last_order: %{label: "Last Order", sortable: true, renderer: &date/1},
    churn_risk: %{label: "Churn Risk", sortable: true, renderer: &risk_score/1}
  ]
end
```

### Inventory Management System
```elixir
# Stock monitoring with reorder alerts, supplier tracking,
# and automated inventory actions
def fields do
  [
    sku: %{label: "SKU", sortable: true, searchable: true},
    product_name: %{label: "Product", sortable: true, searchable: true},
    current_stock: %{label: "Stock", sortable: true, renderer: &stock_level/2},
    reorder_point: %{label: "Reorder At", sortable: true},
    supplier: %{label: "Supplier", sortable: true, searchable: true},
    last_restock: %{label: "Last Restock", sortable: true, renderer: &date/1}
  ]
end
```

### Community and Support

### Getting Help
- **Documentation** - Comprehensive guides and API reference
- **GitHub Issues** - Bug reports and feature requests
- **GitHub Discussions** - Community Q&A and tips
- **Examples Repository** - Real-world implementation patterns

### Key Documentation
- **[Transformers API](api/transformers.md)** - Most powerful filtering feature
- **[Configuration Guide](configuration.md)** - Streams vs assigns, custom components
- **[Field & Filter APIs](api/fields.md)** - Complete reference for all filter types

### Contributing
LiveTable is open source and welcomes contributions:
- **Bug fixes** and performance improvements
- **Feature development** for new capabilities
- **Documentation** improvements and examples
- **Testing** across different environments

### Roadmap
- **Enhanced filtering** with date ranges and custom operators
- **Advanced exports** with custom templates and scheduling
- **Real-time collaboration** features
- **Mobile-optimized** responsive layouts
- **Accessibility improvements** for better WCAG compliance

---

LiveTable empowers Phoenix developers to build sophisticated data interfaces without sacrificing simplicity or performance. Whether you're creating admin panels, customer dashboards, or analytics platforms, LiveTable provides the foundation for exceptional user experiences.

Ready to get started? Check out the [Installation Guide](installation.md) and build your first table in minutes.
