defmodule LiveTable.MixProject do
  use Mix.Project

  @version "0.3.1"
  @source_url "https://github.com/gurujada/live_table"

  def project do
    [
      app: :live_table,
      version: @version,
      elixir: "~> 1.17",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      description:
        "A powerful LiveView component for creating dynamic, interactive tables with features like sorting, filtering, pagination, and export capabilities.",
      docs: docs()
    ]
  end

  def application do
    [
      mod: {LiveTable.TestApplication, []},
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:phoenix_live_view, "~> 1.1"},
      {:phoenix_html, "~> 4.3"},
      {:ecto, "~> 3.13"},
      {:jason, "~> 1.4"},
      {:nimble_csv, "~> 1.3"},
      {:oban, "~> 2.20"},
      {:oban_web, "~> 2.11"},
      {:postgrex, ">= 0.0.0"},
      {:igniter, "~> 0.7.0"},
      {:ex_doc, "~> 0.39", only: :dev, runtime: false},
      {:ecto_sql, "~> 3.13"},
      {:esbuild, "~> 0.10", runtime: Mix.env() == :dev},
      {:sutra_ui, path: "../phx_ui"}
    ]
  end

  defp package do
    [
      maintainers: ["Chivukula Virinchi"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "Docs" => "https://hexdocs.pm/live_table"
      },
      files: ~w(lib .formatter.exs mix.exs README.md LICENSE priv/static/)
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp docs do
    [
      main: "readme",
      name: "LiveTable",
      source_url: @source_url,
      homepage_url: @source_url,
      source_ref: "v#{@version}",
      extras: [
        "README.md",
        "LICENSE",
        "usage_rules.md",
        # Getting Started
        "docs/overview.md",
        "docs/installation.md",
        "docs/quick-start.md",
        # Configuration
        "docs/configuration.md",
        # API Reference
        "docs/api/fields.md",
        "docs/api/filters.md",
        "docs/api/transformers.md",
        "docs/api/exports.md",
        "docs/api/table-options.md",
        # Generators
        "docs/generators/live_table.install.md",
        "docs/generators/live_table.gen.live.md",
        # Examples
        "docs/examples/simple-table.md",
        "docs/examples/complex-queries.md",
        # Support
        "docs/troubleshooting.md",
        # Cheatsheets
        "cheatsheets/live-table.cheatmd",
        "cheatsheets/filters.cheatmd"
      ],
      groups_for_extras: [
        "Getting Started": [
          "docs/overview.md",
          "docs/installation.md",
          "docs/quick-start.md"
        ],
        Configuration: [
          "docs/configuration.md"
        ],
        "API Reference": [
          "docs/api/fields.md",
          "docs/api/filters.md",
          "docs/api/transformers.md",
          "docs/api/exports.md",
          "docs/api/table-options.md"
        ],
        Generators: [
          "docs/generators/live_table.install.md",
          "docs/generators/live_table.gen.live.md"
        ],
        Examples: [
          "docs/examples/simple-table.md",
          "docs/examples/complex-queries.md"
        ],
        Support: [
          "docs/troubleshooting.md",
          "usage_rules.md"
        ],
        Cheatsheets: [
          "cheatsheets/live-table.cheatmd",
          "cheatsheets/filters.cheatmd"
        ]
      ],
      groups_for_modules: [
        "Filter Types": [
          LiveTable.Boolean,
          LiveTable.Range,
          LiveTable.Select,
          LiveTable.Transformer
        ],
        "UI Components": [
          LiveTable.Components
        ]
      ],
      before_closing_head_tag: &docs_before_closing_head_tag/1,
      before_closing_body_tag: &docs_before_closing_body_tag/1
    ]
  end

  defp docs_before_closing_head_tag(:html) do
    """
    <meta name="description" content="LiveTable - A powerful Phoenix LiveView component library for building dynamic, interactive data tables with real-time updates.">
    <meta name="keywords" content="phoenix, liveview, elixir, table, datatable, pagination, filtering, sorting">
    <style>
      .logo { max-height: 60px; }
      .sidebar-search { margin-bottom: 1rem; }
    </style>
    """
  end

  defp docs_before_closing_head_tag(_), do: ""

  defp docs_before_closing_body_tag(:html) do
    """
    <script>
      // Add copy-to-clipboard functionality for code blocks
      document.addEventListener('DOMContentLoaded', function() {
        const codeBlocks = document.querySelectorAll('pre code');
        codeBlocks.forEach(function(block) {
          const button = document.createElement('button');
          button.className = 'copy-button';
          button.textContent = 'Copy';
          button.onclick = function() {
            navigator.clipboard.writeText(block.textContent);
            button.textContent = 'Copied!';
            setTimeout(() => button.textContent = 'Copy', 2000);
          };
          block.parentNode.insertBefore(button, block);
        });
      });
    </script>
    """
  end

  defp docs_before_closing_body_tag(_), do: ""
end
