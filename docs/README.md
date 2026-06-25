# LiveTable Documentation

> **A powerful Phoenix LiveView component library for building dynamic, interactive data tables with real-time updates.**

Welcome to the complete LiveTable documentation. This guide will help you build sophisticated data interfaces for admin panels, dashboards, e-commerce catalogs, and any application requiring advanced data presentation.

## 📚 Documentation Structure

### 🚀 Getting Started
Perfect for new users who want to get up and running quickly.

- **[Installation Guide](installation.md)** - Complete setup instructions with all dependencies
- **[Quick Start](quick-start.md)** - Build your first table in 5 minutes with working examples
- **[Overview](overview.md)** - Architecture, features, and when to use LiveTable

### ⚙️ Configuration & Setup
Essential guides for configuring LiveTable in your application.

- **[Configuration Guide](configuration.md)** - Streams vs assigns, custom components, application-wide defaults
- **[Table Options](api/table-options.md)** - Pagination, sorting, exports, and display modes

### 📖 API Reference
Complete reference documentation for all LiveTable features.

- **[Fields API](api/fields.md)** - Configure data display, sorting, searching, and custom renderers
- **[Filters API](api/filters.md)** - Boolean, Range, and Select filters with advanced examples
- **[Transformers API](api/transformers.md)** - Ultimate filtering power with custom, stateful filters
- **[Exports API](api/exports.md)** - CSV and PDF generation with background processing

### 💡 Examples & Patterns
Real-world examples showing LiveTable in action.

- **[Simple Tables](examples/simple-table.md)** - Basic patterns for single-schema tables
- **[Complex Queries](examples/complex-queries.md)** - Joins, computed fields, and advanced use cases

### 🔧 Troubleshooting & Support
Help when things don't work as expected.

- **[Troubleshooting Guide](troubleshooting.md)** - Common issues, error messages, and solutions

## 🎯 Choose Your Path

### I'm New to LiveTable
Start here to understand what LiveTable is and how it works:

1. **[Overview](overview.md)** - Understand LiveTable's capabilities and architecture
2. **[Installation](installation.md)** - Get LiveTable running in your Phoenix app
3. **[Quick Start](quick-start.md)** - Build your first working table
4. **[Simple Examples](examples/simple-table.md)** - Learn basic patterns

### I Want to Build a Basic Table
For simple data display with minimal configuration:

1. **[Quick Start](quick-start.md)** - 5-minute setup guide
2. **[Fields API](api/fields.md)** - Configure columns and data display
3. **[Simple Examples](examples/simple-table.md)** - Copy-paste ready examples

### I Need Advanced Features
For complex queries, custom filters, and sophisticated interfaces:

1. **[Complex Queries](examples/complex-queries.md)** - Joins and computed fields
2. **[Transformers API](api/transformers.md)** - Most powerful filtering capabilities
3. **[Configuration Guide](configuration.md)** - Custom components and advanced setup

### I'm Having Issues
When something isn't working correctly:

1. **[Troubleshooting Guide](troubleshooting.md)** - Common problems and solutions
2. **[Configuration Guide](configuration.md)** - Verify your setup
3. **[API Reference](api/)** - Check correct usage patterns

## 🏗️ Architecture Overview

LiveTable uses a three-tier architecture that separates concerns and maximizes flexibility:

### Data Layer
- **Simple Tables**: Use `schema: YourApp.Model` for single-table queries
- **Complex Tables**: Assign `:data_provider` for custom queries with joins

### Configuration Layer
- **Fields**: Define what data to display and how (`fields/0` function)
- **Filters**: Configure interactive filtering (`filters/0` function)
- **Options**: Control behavior and appearance (`table_options/0` function)

### Presentation Layer
- **Table Mode**: Traditional row/column layout
- **Card Mode**: Custom card components for rich displays
- **Custom Components**: Override any part of the UI

## 🔥 Key Features

### Advanced Filtering
- **Boolean Filters** - Toggle states with custom dynamic queries
- **Range Filters** - Numeric ranges with sliders
- **Select Filters** - Static options or dynamic database queries
- **Transformers** - Ultimate power for complex, stateful filtering
- **Full-text Search** - Search across multiple fields simultaneously

### Smart Data Handling
- **Schema Integration** - Direct Ecto schema support for simple cases
- **Custom Queries** - Full control with joins, aggregates, and computed fields
- **Real-time Updates** - Built for Phoenix LiveView with automatic refresh
- **Performance Optimization** - Efficient pagination and query strategies

### Professional Features
- **Export System** - CSV and PDF generation with background processing
- **Multiple View Modes** - Table and card layouts with complete customization
- **URL Persistence** - Shareable and bookmarkable filtered views
- **Responsive Design** - Works on desktop, tablet, and mobile devices

## 📋 Common Use Cases

### E-commerce Product Catalogs
```elixir
# Rich product listings with category filtering, price ranges, 
# stock status, and bulk actions
```

### Admin Dashboards
```elixir
# User management, order processing, and content moderation
# with advanced filtering and export capabilities
```

### Analytics Platforms
```elixir
# Customer analytics, sales reports, and KPI dashboards
# with complex queries and real-time updates
```

### Inventory Management
```elixir
# Stock monitoring, reorder alerts, and supplier tracking
# with automated actions and reporting
```

## 📖 Quick Reference

### Essential Patterns

**Simple Table Setup:**
```elixir
use LiveTable.LiveResource, schema: YourApp.Product
```

**Custom Query Setup:**
```elixir
assign(socket, :data_provider, {YourApp.Products, :complex_query, []})
```

**Field Configuration:**
```elixir
def fields do
  [
    name: %{label: "Name", sortable: true, searchable: true},
    price: %{label: "Price", sortable: true, renderer: &currency/1}
  ]
end
```

**Filter Configuration:**
```elixir
def filters do
  [
    active: Boolean.new(:active, "active", %{
      condition: dynamic([p], p.active == true)
    })
  ]
end
```

### Important Notes

- **Field Keys**: Must match schema fields (simple tables) or select clause keys (custom queries)
- **Filter Imports**: Boolean, Range, and Select are aliased - use directly
- **Renderer Signatures**: `&function/1` (value only) or `&function/2` (value + record)
- **Assoc Option**: Only needed for sorting joined fields in custom queries

## 🆘 Getting Help

### Documentation Issues
If something in the documentation is unclear or incorrect:

1. Check the [Troubleshooting Guide](troubleshooting.md) for common issues
2. Search [GitHub Issues](https://github.com/gurujada/live_table/issues) for similar problems
3. Open a new issue with specific details about what's unclear

### Code Issues
For bugs, feature requests, or implementation questions:

1. Review the relevant API documentation section
2. Check the [Examples](examples/) for similar patterns
3. Open a [GitHub Issue](https://github.com/gurujada/live_table/issues) with a minimal reproduction case

### Community Support
- **GitHub Discussions** - General questions and community tips
- **Phoenix Forum** - LiveView and Phoenix-specific questions
- **Elixir Slack** - Real-time help from the community

## 🔄 Documentation Updates

This documentation is actively maintained and updated. Key features covered:

- ✅ **Complete API Reference** - All options and features documented
- ✅ **Real-world Examples** - Production-ready patterns and code  
- ✅ **Advanced Transformers** - Complex filtering with stateful query transformations
- ✅ **Custom UI Components** - Complete customization including headers, cards, and layouts
- ✅ **Performance Guidance** - Optimization tips and best practices
- ✅ **Troubleshooting** - Common issues and step-by-step solutions
- ✅ **Module Documentation** - Comprehensive docs for Boolean, Range, and Select filters

### Documentation Status: Complete ✅

This documentation suite is comprehensive and production-ready, covering:

**Core Features:**
- Installation and setup with all dependencies
- Simple and complex table configurations
- All filter types with extensive examples
- Export system (CSV/PDF) with background processing
- Real-time updates and LiveView integration

**Advanced Features:**
- **Transformers** - Most powerful filtering with custom query transformations
- **Custom Components** - Complete UI control for headers, content, and cards
- **Complex Queries** - Joins, aggregations, and computed fields
- **Performance Optimization** - Database indexing and query strategies

**Production Support:**
- **Error Handling** - Comprehensive troubleshooting guide
- **State Management** - URL persistence and filter state
- **Debugging Tools** - Query inspection and state debugging
- **Real-world Examples** - College counseling, e-commerce, analytics

The documentation includes examples from actual production applications, including a sophisticated college counseling platform with complex rank-based filtering, multiple transformers, and custom UI components working together seamlessly.

---

**Ready to build amazing data interfaces?** Start with the [Quick Start Guide](quick-start.md) and have a working table in minutes!
