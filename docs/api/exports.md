# Exports API Reference

LiveTable provides export capabilities for generating CSV and PDF files from your table data. Exports are processed in the background using Oban, ensuring your LiveView remains responsive.

## Overview

LiveTable supports two export formats:
- **CSV** - Comma-separated values for spreadsheet applications
- **PDF** - Formatted documents using Typst typesetting engine

`formats` accepts only formats LiveTable can actually produce. Any other entry raises an
`ArgumentError` listing the supported formats, rather than rendering a button that dispatches to
the wrong exporter.

Exports include all table data (not just the current page) and respect active filters. Files are generated asynchronously and served as downloadable links.

## Upgrade Notes

Custom export buttons should submit `phx-click="export"` with
`phx-value-format="csv"` or `phx-value-format="pdf"`. The previous `"export-csv"`
and `"export-pdf"` events are no longer handled.

Exports queued before this update must be re-run because the query payload format
has changed. CSV and PDF generators now accept Ecto queries rather than query
strings.

## Basic Setup

### 1. Enable Exports in Table Configuration

```elixir
defmodule YourAppWeb.ProductLive.Index do
  use YourAppWeb, :live_view
  use LiveTable.LiveResource, schema: YourApp.Product

  def table_options do
    %{
      exports: %{
        enabled: true,
        formats: [:csv, :pdf]  # Enable both formats
      }
    }
  end
end
```

### 2. Configure Static File Serving

Add exports to your static paths in `lib/your_app_web.ex`:

```elixir
def static_paths do
  ~w(assets fonts images favicon.ico robots.txt exports)
end
```

## Export Configuration Options

### Table-Level Configuration

```elixir
def table_options do
  %{
    exports: %{
      enabled: true,                    # Enable/disable exports
      formats: [:csv, :pdf]            # Available formats: :csv, :pdf
    }
  }
end
```

### Application-Wide Configuration

```elixir
# config/config.exs
config :live_table,
  defaults: %{
    exports: %{
      enabled: true,
      formats: [:csv, :pdf]
    }
  }
```

### Oban Configuration

```elixir
# config/config.exs
config :your_app, Oban,
  repo: YourApp.Repo,
  engine: Oban.Engines.Basic,
  notifier: Oban.Notifiers.Postgres,
  plugins: [Oban.Plugins.Pruner],
  queues: [
    exports: 10,        # Export processing queue
    default: 5          # Other background jobs
  ]
```

## CSV Exports

CSV exports use NimbleCSV for fast, memory-efficient processing.

### Features
- **Streaming processing** - Handles large datasets without memory issues
- **Custom headers** - Uses field labels from your configuration
- **Filter respect** - Only exports filtered/searched data
- **UTF-8 encoding** - Proper character encoding for international data

### Example CSV Output

```csv
ID,Product Name,Price,Stock,Category
1,iPhone 15 Pro,999.99,25,Electronics
2,MacBook Air,1199.99,8,Electronics
3,Wireless Mouse,45.99,50,Accessories
```

### CSV Configuration

```elixir
def table_options do
  %{
    exports: %{
      enabled: true,
      formats: [:csv]
    }
  }
end
```

## PDF Exports

PDF exports use Typst for professional document formatting.

### Prerequisites

Install Typst on your system:

**macOS:**
```bash
brew install typst
```

**Ubuntu/Debian:**
```bash
# Download latest release
wget https://github.com/typst/typst/releases/latest/download/typst-x86_64-unknown-linux-musl.tar.xz
tar -xf typst-x86_64-unknown-linux-musl.tar.xz
sudo mv typst-x86_64-unknown-linux-musl/typst /usr/local/bin/
```

**Windows:**
Download from [Typst Releases](https://github.com/typst/typst/releases) and add to PATH.

**Verify Installation:**
```bash
typst --version
```

### Features
- **Professional formatting** - Clean, readable table layouts
- **Large dataset support** - Efficient processing for thousands of records
- **Responsive tables** - Automatic column width adjustment

### PDF Configuration

```elixir
def table_options do
  %{
    exports: %{
      enabled: true,
      formats: [:pdf]
    }
  }
end
```

## Export Process Flow

### 1. User Initiates Export

When a user clicks an export button, LiveTable:
1. Captures current table state (filters, search, sort)
2. Queues a background job with this state
3. Shows a "Processing..." message
4. Returns immediately (non-blocking)

### 2. Background Processing

The Oban worker:
1. Recreates the exact query from captured state
2. Streams data in batches
3. Generates the export file
4. Saves it to the exports directory
5. Updates job status

### 3. Download Delivery

Once complete:
1. User receives a download link
2. File is served via static file handling
3. Files auto-expire after configured time

## Troubleshooting

### Common Issues

**Exports not generating:**
- Check Oban is running and exports queue is configured
- Verify static file directory exists and is writable
- Check for errors in Oban dashboard

**PDF generation failing:**
- Ensure Typst is installed and in PATH
- Check file permissions in export directory
- Verify system has enough disk space

**Download links not working:**
- Verify static file serving is configured
- Check exports directory is in static_paths
- Ensure web server can serve files from exports directory

### Debug Export Jobs

```elixir
# Check export job status
iex> Oban.Job |> where([j], j.queue == "exports") |> Repo.all()

# Check export files
iex> File.ls!(Path.join([:code.priv_dir(:your_app), "static", "exports"]))
```

## Examples

### E-commerce Product Export

```elixir
def table_options do
  %{
    exports: %{
      enabled: true,
      formats: [:csv, :pdf]
    }
  }
end
```

### Customer Data Export

```elixir
def table_options do
  %{
    exports: %{
      enabled: true,
      formats: [:csv]  # CSV only for customer data
    }
  }
end
```

### Financial Report Export

```elixir
def table_options do
  %{
    exports: %{
      enabled: true,
      formats: [:pdf]  # PDF only for financial reports
    }
  }
end
```