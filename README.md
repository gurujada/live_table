# LiveTable

A Phoenix LiveView component library for building dynamic, interactive data tables with real-time updates.

[![Hex.pm](https://img.shields.io/hexpm/v/live_table.svg)](https://hex.pm/packages/live_table)
[![Documentation](https://img.shields.io/badge/docs-hexdocs-blue.svg)](https://hexdocs.pm/live_table)

## Features

- **Advanced Filtering** - Text search, range filters, select dropdowns, boolean toggles, and transformers
- **Smart Sorting** - Multi-column sorting with shift-click support
- **Flexible Pagination** - Standard pagination or infinite scroll
- **Export Capabilities** - CSV and PDF exports with background processing
- **Real-time Updates** - Built for Phoenix LiveView with instant feedback
- **Multiple View Modes** - Table and card layouts with custom components
- **Complex Queries** - Full support for joins, aggregations, and computed fields

![LiveTable Demo](https://github.com/gurujada/live_table/blob/master/demo.gif?raw=true)

[Live Demo (1M+ records)](https://livetable.gurujada.com) | [Advanced Demo](https://josaa.gurujada.com) | [Advanced Demo Source](https://github.com/ChivukulaVirinchi/college-app)

## Quick Start

**1. Add dependency:**

```elixir
# mix.exs
{:live_table, "~> 0.3.1"}
```

**2. Install:**

```bash
mix deps.get && mix live_table.install
```

**3. Create a table:**

```elixir
# lib/my_app_web/live/product_live/index.ex
defmodule MyAppWeb.ProductLive.Index do
  use MyAppWeb, :live_view
  use LiveTable.LiveResource, schema: MyApp.Product

  def fields do
    [
      id: %{label: "ID", sortable: true},
      name: %{label: "Name", sortable: true, searchable: true},
      price: %{label: "Price", sortable: true}
    ]
  end

  def filters do
    [
      in_stock: Boolean.new(:quantity, "in_stock", %{
        label: "In Stock",
        condition: dynamic([p], p.quantity > 0)
      })
    ]
  end
end
```

**4. Render it:**

```heex
<%# lib/my_app_web/live/product_live/index.html.heex %>
<.live_table fields={fields()} filters={filters()} options={@options} streams={@streams} />
```

## Documentation

**[Full Documentation on HexDocs](https://hexdocs.pm/live_table)**

- [Installation Guide](https://hexdocs.pm/live_table/installation.html)
- [Quick Start Tutorial](https://hexdocs.pm/live_table/quick-start.html)
- [API Reference](https://hexdocs.pm/live_table/api-reference.html)
- [Transformers Guide](https://hexdocs.pm/live_table/transformers.html) - LiveTable's most powerful feature

## AI/LLM Integration

LiveTable includes [usage rules](https://hexdocs.pm/live_table/usage_rules.html) for AI assistants to provide accurate code suggestions.

## License

MIT License. See [LICENSE](LICENSE) for details.

## Contributing

1. Fork the repository
2. Create your feature branch
3. Open a Pull Request

## Support

- [GitHub Issues](https://github.com/gurujada/live_table/issues)
- [GitHub Discussions](https://github.com/gurujada/live_table/discussions)
