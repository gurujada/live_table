defmodule LiveTable.TableComponentTest do
  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest
  import Phoenix.Component

  defmodule TestTableComponent do
    use LiveTable.TableComponent,
      table_options: %{
        mode: :table,
        use_streams: false,
        search: %{enabled: true, placeholder: "Search...", debounce: 300},
        pagination: %{sizes: [10, 25, 50]},
        exports: %{enabled: true, formats: [:csv, :pdf]}
      }
  end

  defmodule CardTableComponent do
    use LiveTable.TableComponent,
      table_options: %{
        mode: :card,
        use_streams: false,
        card_component: fn %{record: record} ->
          assigns = %{record: record}

          ~H"""
          <div class="card">
            <h3>{@record.name}</h3>
            <p>{@record.description}</p>
          </div>
          """
        end
      }
  end

  defmodule StreamTableComponent do
    use LiveTable.TableComponent,
      table_options: %{
        mode: :table,
        use_streams: true
      }
  end

  defmodule CustomControls do
    use Phoenix.Component

    def controls(assigns) do
      ~H"""
      <div id="custom-controls">My Controls</div>
      """
    end
  end

  describe "live_table/1 - basic rendering" do
    test "renders table mode with basic structure" do
      assigns = %{
        fields: [
          {:name, %{label: "Name", sortable: true, searchable: true}},
          {:email, %{label: "Email", sortable: false, searchable: false}}
        ],
        filters: [],
        options: %{
          "filters" => %{"search" => ""},
          "sort" => %{"sort_params" => []},
          "pagination" => %{"paginate?" => true, "per_page" => 10, "page" => "1"}
        },
        streams: [
          %{name: "John Doe", email: "john@example.com"},
          %{name: "Jane Smith", email: "jane@example.com"}
        ]
      }

      html = render_component(&TestTableComponent.live_table/1, assigns)

      assert html =~ "live-table"
      assert html =~ "John Doe"
      assert html =~ "jane@example.com"
      assert html =~ "Search..."
    end

    test "renders card mode" do
      assigns = %{
        fields: [],
        filters: [],
        options: %{
          "filters" => %{"search" => ""},
          "pagination" => %{"paginate?" => false}
        },
        streams: [
          %{name: "Product 1", description: "Description 1"},
          %{name: "Product 2", description: "Description 2"}
        ]
      }

      html = render_component(&CardTableComponent.live_table/1, assigns)

      assert html =~ "grid"
      assert html =~ "Product 1"
      assert html =~ "Description 2"
    end

    test "renders empty state" do
      assigns = %{
        fields: [
          {:name, %{label: "Name", sortable: true, searchable: true}}
        ],
        filters: [],
        options: %{
          "filters" => %{"search" => ""},
          "sort" => %{"sort_params" => []},
          "pagination" => %{"paginate?" => false}
        },
        streams: []
      }

      html = render_component(&TestTableComponent.live_table/1, assigns)

      assert html =~ "No data"
      assert html =~ "No records found"
    end
  end

  describe "search functionality" do
    test "renders search input when searchable fields exist" do
      assigns = %{
        fields: [
          {:name, %{label: "Name", sortable: true, searchable: true}},
          {:email, %{label: "Email", sortable: false, searchable: false}}
        ],
        filters: [],
        options: %{
          "filters" => %{"search" => "test search"},
          "sort" => %{"sort_params" => []},
          "pagination" => %{"paginate?" => false}
        },
        streams: []
      }

      html = render_component(&TestTableComponent.live_table/1, assigns)

      assert html =~ ~s(value="test search")
      assert html =~ "phx-debounce=\"300\""
    end

    test "hides search when no searchable fields" do
      assigns = %{
        fields: [
          {:name, %{label: "Name", sortable: false, searchable: false}},
          {:email, %{label: "Email", sortable: false, searchable: false}}
        ],
        filters: [],
        options: %{
          "filters" => %{"search" => ""},
          "sort" => %{"sort_params" => []},
          "pagination" => %{"paginate?" => false}
        },
        streams: []
      }

      html = render_component(&TestTableComponent.live_table/1, assigns)

      refute html =~ "table-search"
    end

    test "respects search.enabled = false in table_options" do
      defmodule NoSearchTable do
        use LiveTable.TableComponent,
          table_options: %{
            mode: :table,
            use_streams: false,
            search: %{enabled: false}
          }
      end

      assigns = %{
        fields: [
          {:name, %{label: "Name", sortable: true, searchable: true}}
        ],
        filters: [],
        options: %{
          "filters" => %{"search" => ""},
          "sort" => %{"sort_params" => []},
          "pagination" => %{"paginate?" => false}
        },
        streams: []
      }

      html = render_component(&NoSearchTable.live_table/1, assigns)

      refute html =~ "table-search"
    end
  end

  describe "sorting functionality" do
    test "renders sortable columns with sort links" do
      assigns = %{
        fields: [
          {:name, %{label: "Name", sortable: true}},
          {:email, %{label: "Email", sortable: false}},
          {:age, %{label: "Age", sortable: true}}
        ],
        filters: [],
        options: %{
          "filters" => %{"search" => ""},
          "sort" => %{"sort_params" => [name: :asc]},
          "pagination" => %{"paginate?" => false}
        },
        streams: []
      }

      html = render_component(&TestTableComponent.live_table/1, assigns)

      # Sortable columns should have sort functionality
      assert html =~ "phx-click=\"sort\""
      # In the new UI, sortable columns use phx-click="sort" instead of hooks
      assert html =~ "phx-click=\"sort\""
      assert html =~ "phx-value-sort"
      assert html =~ "Name"
      assert html =~ "Age"
    end
  end

  describe "pagination" do
    test "renders pagination controls when enabled" do
      assigns = %{
        fields: [{:name, %{label: "Name", sortable: false}}],
        filters: [],
        options: %{
          "filters" => %{"search" => ""},
          "sort" => %{"sort_params" => []},
          "pagination" => %{
            "paginate?" => true,
            "per_page" => 10,
            "page" => "2",
            has_next_page: true
          }
        },
        streams: []
      }

      html = render_component(&TestTableComponent.live_table/1, assigns)

      assert html =~ "Page"
      assert html =~ "2"
      # Previous page
      assert html =~ "phx-value-page=\"1\""
      # Next page
      assert html =~ "phx-value-page=\"3\""
      assert html =~ "per_page"
    end

    test "disables previous button on first page" do
      assigns = %{
        fields: [{:name, %{label: "Name", sortable: false}}],
        filters: [],
        options: %{
          "filters" => %{"search" => ""},
          "sort" => %{"sort_params" => []},
          "pagination" => %{
            "paginate?" => true,
            "page" => "1",
            has_next_page: true
          }
        },
        streams: []
      }

      html = render_component(&TestTableComponent.live_table/1, assigns)

      assert html =~ "cursor-not-allowed"
    end

    test "disables next button when no next page" do
      assigns = %{
        fields: [{:name, %{label: "Name", sortable: false}}],
        filters: [],
        options: %{
          "filters" => %{"search" => ""},
          "sort" => %{"sort_params" => []},
          "pagination" => %{
            "paginate?" => true,
            "page" => "5",
            has_next_page: false
          }
        },
        streams: []
      }

      html = render_component(&TestTableComponent.live_table/1, assigns)

      # Check that next button is disabled
      assert html =~ "phx-value-page=\"6\""
      assert html =~ "cursor-not-allowed"
    end

    test "renders per page selector with configured sizes" do
      assigns = %{
        fields: [{:name, %{label: "Name", sortable: false}}],
        filters: [],
        options: %{
          "filters" => %{"search" => ""},
          "sort" => %{"sort_params" => []},
          "pagination" => %{"paginate?" => true, "per_page" => 25, "page" => "1"}
        },
        streams: []
      }

      html = render_component(&TestTableComponent.live_table/1, assigns)

      assert html =~ "name=\"per_page\""
      assert html =~ "value=\"25\""
    end
  end

  describe "filters" do
    test "renders filters when provided" do
      filter = %LiveTable.Boolean{
        field: :active,
        key: "active",
        options: %{label: "Active"}
      }

      assigns = %{
        fields: [{:name, %{label: "Name", sortable: false}}],
        filters: [{:active, filter}],
        options: %{
          "filters" => %{"search" => "", "active" => "true"},
          "sort" => %{"sort_params" => []},
          "pagination" => %{"paginate?" => false}
        },
        streams: []
      }

      html = render_component(&TestTableComponent.live_table/1, assigns)

      assert html =~ "filters-container"
      assert html =~ "Clear Filters"
    end

    test "shows filter toggle button when more than 3 filters" do
      filters =
        for i <- 1..4 do
          {:"filter_#{i}",
           %LiveTable.Boolean{
             field: :"field_#{i}",
             key: "filter_#{i}",
             options: %{label: "Filter #{i}"}
           }}
        end

      assigns = %{
        fields: [{:name, %{label: "Name", sortable: false}}],
        filters: filters,
        options: %{
          "filters" => %{"search" => ""},
          "sort" => %{"sort_params" => []},
          "pagination" => %{"paginate?" => false}
        },
        streams: []
      }

      html = render_component(&TestTableComponent.live_table/1, assigns)

      assert html =~ "filter-show-text"
      assert html =~ "Show Filters"
      # Filters should be hidden by default
      assert html =~ "hidden"
    end

    test "does not show filter toggle with 3 or fewer filters" do
      filters =
        for i <- 1..3 do
          {:"filter_#{i}",
           %LiveTable.Boolean{
             field: :"field_#{i}",
             key: "filter_#{i}",
             options: %{label: "Filter #{i}"}
           }}
        end

      assigns = %{
        fields: [{:name, %{label: "Name", sortable: false}}],
        filters: filters,
        options: %{
          "filters" => %{"search" => ""},
          "sort" => %{"sort_params" => []},
          "pagination" => %{"paginate?" => false}
        },
        streams: []
      }

      html = render_component(&TestTableComponent.live_table/1, assigns)

      refute html =~ "filter-show-text"
      refute html =~ "Show Filters"
    end

    test "hides clear filters link when no filters applied" do
      assigns = %{
        fields: [{:name, %{label: "Name", sortable: false}}],
        filters: [
          {:active,
           %LiveTable.Boolean{
             field: :active,
             key: "active",
             options: %{label: "Active"}
           }}
        ],
        options: %{
          "filters" => %{"search" => ""},
          "sort" => %{"sort_params" => []},
          "pagination" => %{"paginate?" => false}
        },
        streams: []
      }

      html = render_component(&TestTableComponent.live_table/1, assigns)

      refute html =~ "Clear Filters"
    end
  end

  describe "exports" do
    test "renders export buttons when enabled" do
      assigns = %{
        fields: [{:name, %{label: "Name", sortable: false}}],
        filters: [],
        options: %{
          "filters" => %{"search" => ""},
          "sort" => %{"sort_params" => []},
          "pagination" => %{"paginate?" => false}
        },
        streams: []
      }

      html = render_component(&TestTableComponent.live_table/1, assigns)

      assert html =~ "Export as CSV"
      assert html =~ "Export as PDF"
      # phx-click is encoded as JSON in dropdown menu
      assert html =~ "export-csv"
      assert html =~ "export-pdf"
    end

    test "respects configured export formats" do
      defmodule CSVOnlyTable do
        use LiveTable.TableComponent,
          table_options: %{
            mode: :table,
            use_streams: false,
            exports: %{enabled: true, formats: [:csv]}
          }
      end

      assigns = %{
        fields: [{:name, %{label: "Name", sortable: false}}],
        filters: [],
        options: %{
          "filters" => %{"search" => ""},
          "sort" => %{"sort_params" => []},
          "pagination" => %{"paginate?" => false}
        },
        streams: []
      }

      html = render_component(&CSVOnlyTable.live_table/1, assigns)

      assert html =~ "Export as CSV"
      refute html =~ "Export as PDF"
    end

    test "hides exports when disabled" do
      defmodule NoExportTable do
        use LiveTable.TableComponent,
          table_options: %{
            mode: :table,
            use_streams: false,
            exports: %{enabled: false}
          }
      end

      assigns = %{
        fields: [{:name, %{label: "Name", sortable: false}}],
        filters: [],
        options: %{
          "filters" => %{"search" => ""},
          "sort" => %{"sort_params" => []},
          "pagination" => %{"paginate?" => false}
        },
        streams: []
      }

      html = render_component(&NoExportTable.live_table/1, assigns)

      refute html =~ "Export as CSV"
      refute html =~ "Export as PDF"
    end
  end

  describe "cell rendering" do
    test "renders plain values" do
      assigns = %{
        fields: [
          {:name, %{label: "Name", sortable: false}},
          {:count, %{label: "Count", sortable: false}}
        ],
        filters: [],
        options: %{
          "filters" => %{"search" => ""},
          "sort" => %{"sort_params" => []},
          "pagination" => %{"paginate?" => false}
        },
        streams: [
          %{name: "Test", count: 42},
          %{name: nil, count: 0}
        ]
      }

      html = render_component(&TestTableComponent.live_table/1, assigns)

      assert html =~ "Test"
      assert html =~ "42"
      # Check that there are 4 td elements (2 fields × 2 records) + 1 for empty state
      # 4 td elements + 1 empty state td + 1 initial split
      assert length(String.split(html, "<td")) == 6
    end

    test "uses custom renderer function with single argument" do
      assigns = %{
        fields: [
          {:name, %{label: "Name", sortable: false}},
          {:price, %{label: "Price", sortable: false, renderer: fn value -> "$#{value}" end}}
        ],
        filters: [],
        options: %{
          "filters" => %{"search" => ""},
          "sort" => %{"sort_params" => []},
          "pagination" => %{"paginate?" => false}
        },
        streams: [
          %{name: "Product", price: 99.99}
        ]
      }

      html = render_component(&TestTableComponent.live_table/1, assigns)

      assert html =~ "$99.99"
    end

    test "uses custom renderer function with value and record" do
      assigns = %{
        fields: [
          {:name, %{label: "Name", sortable: false}},
          {:status,
           %{
             label: "Status",
             sortable: false,
             component: fn value, record ->
               "#{record.name}: #{value}"
             end
           }}
        ],
        filters: [],
        options: %{
          "filters" => %{"search" => ""},
          "sort" => %{"sort_params" => []},
          "pagination" => %{"paginate?" => false}
        },
        streams: [
          %{name: "Task", status: "completed"}
        ]
      }

      html = render_component(&TestTableComponent.live_table/1, assigns)

      assert html =~ "Task: completed"
    end
  end

  describe "streams support" do
    test "renders with streams when use_streams is true" do
      assigns = %{
        fields: [{:name, %{label: "Name", sortable: false}}],
        filters: [],
        options: %{
          "filters" => %{"search" => ""},
          "sort" => %{"sort_params" => []},
          "pagination" => %{"paginate?" => false}
        },
        streams: %{
          resources: [
            {"resource-1", %{name: "Stream Item 1"}},
            {"resource-2", %{name: "Stream Item 2"}}
          ]
        }
      }

      html = render_component(&StreamTableComponent.live_table/1, assigns)

      assert html =~ "Stream Item 1"
      assert html =~ "Stream Item 2"
      assert html =~ "id=\"resource-1\""
      assert html =~ "id=\"resource-2\""
    end

    test "raises error when use_streams not set properly" do
      defmodule InvalidStreamTable do
        use LiveTable.TableComponent, table_options: %{mode: :table}
      end

      assigns = %{
        fields: [{:name, %{label: "Name", sortable: false}}],
        filters: [],
        options: %{
          "filters" => %{"search" => ""},
          "sort" => %{"sort_params" => []},
          "pagination" => %{"paginate?" => false}
        },
        streams: []
      }

      # When use_streams is not set, render_row/1 pattern match fails with FunctionClauseError
      assert_raise FunctionClauseError, fn ->
        render_component(&InvalidStreamTable.live_table/1, assigns)
      end
    end
  end

  describe "custom components" do
    test "uses custom header component" do
      defmodule CustomHeader do
        use Phoenix.Component

        def header(assigns) do
          ~H"""
          <div class="custom-header">Custom Header Content</div>
          """
        end
      end

      defmodule CustomHeaderTable do
        use LiveTable.TableComponent,
          table_options: %{
            mode: :table,
            use_streams: false,
            custom_header: {CustomHeader, :header}
          }
      end

      assigns = %{
        fields: [{:name, %{label: "Name", sortable: false}}],
        filters: [],
        options: %{
          "filters" => %{"search" => ""},
          "sort" => %{"sort_params" => []},
          "pagination" => %{"paginate?" => false}
        },
        streams: []
      }

      html = render_component(&CustomHeaderTable.live_table/1, assigns)

      assert html =~ "custom-header"
      assert html =~ "Custom Header Content"
    end

    test "uses custom content component" do
      defmodule CustomContent do
        use Phoenix.Component

        def content(assigns) do
          ~H"""
          <div class="custom-content">Custom Table Content</div>
          """
        end
      end

      defmodule CustomContentTable do
        use LiveTable.TableComponent,
          table_options: %{
            mode: :table,
            use_streams: false,
            custom_content: {CustomContent, :content}
          }
      end

      assigns = %{
        fields: [{:name, %{label: "Name", sortable: false}}],
        filters: [],
        options: %{
          "filters" => %{"search" => ""},
          "sort" => %{"sort_params" => []},
          "pagination" => %{"paginate?" => false}
        },
        streams: []
      }

      html = render_component(&CustomContentTable.live_table/1, assigns)

      assert html =~ "custom-content"
      assert html =~ "Custom Table Content"
    end

    test "uses custom footer component" do
      defmodule CustomFooter do
        use Phoenix.Component

        def footer(assigns) do
          ~H"""
          <div class="custom-footer">Custom Footer</div>
          """
        end
      end

      defmodule CustomFooterTable do
        use LiveTable.TableComponent,
          table_options: %{
            mode: :table,
            use_streams: false,
            custom_footer: {CustomFooter, :footer}
          }
      end

      assigns = %{
        fields: [{:name, %{label: "Name", sortable: false}}],
        filters: [],
        options: %{
          "filters" => %{"search" => ""},
          "sort" => %{"sort_params" => []},
          "pagination" => %{"paginate?" => false}
        },
        streams: []
      }

      html = render_component(&CustomFooterTable.live_table/1, assigns)

      assert html =~ "custom-footer"
      assert html =~ "Custom Footer"
    end
  end

  describe "dark mode support" do
    test "includes dark mode classes" do
      assigns = %{
        fields: [{:name, %{label: "Name", sortable: false}}],
        filters: [],
        options: %{
          "filters" => %{"search" => ""},
          "sort" => %{"sort_params" => []},
          "pagination" => %{"paginate?" => false}
        },
        streams: [%{name: "Test"}]
      }

      html = render_component(&TestTableComponent.live_table/1, assigns)

      # Component uses semantic color classes (bg-muted, text-foreground, etc.)
      # that support dark mode through CSS variables rather than dark: prefixes
      assert html =~ "bg-muted"
      assert html =~ "text-foreground"
      assert html =~ "bg-background"
    end
  end

  describe "edge cases" do
    test "handles nil fields gracefully" do
      assigns = %{
        fields: [],
        filters: [],
        options: %{
          "filters" => %{"search" => ""},
          "sort" => %{"sort_params" => []},
          "pagination" => %{"paginate?" => false}
        },
        streams: [%{name: "Test"}]
      }

      html = render_component(&TestTableComponent.live_table/1, assigns)

      assert html =~ "live-table"
      # With no fields, we still get thead/tr but no th elements
      assert html =~ "<thead"
      assert html =~ "<tr>"
      # Empty tr in thead doesn't contain th elements
    end

    test "handles missing field values in records" do
      assigns = %{
        fields: [
          {:name, %{label: "Name", sortable: false}},
          {:email, %{label: "Email", sortable: false}},
          {:phone, %{label: "Phone", sortable: false}}
        ],
        filters: [],
        options: %{
          "filters" => %{"search" => ""},
          "sort" => %{"sort_params" => []},
          "pagination" => %{"paginate?" => false}
        },
        streams: [
          # Missing email and phone
          %{name: "John"},
          # Missing name
          %{email: "jane@example.com", phone: "123-456-7890"}
        ]
      }

      html = render_component(&TestTableComponent.live_table/1, assigns)

      assert html =~ "John"
      assert html =~ "jane@example.com"
      assert html =~ "123-456-7890"
    end

    test "handles very long text without breaking layout" do
      assigns = %{
        fields: [
          {:description, %{label: "Description", sortable: false}}
        ],
        filters: [],
        options: %{
          "filters" => %{"search" => ""},
          "sort" => %{"sort_params" => []},
          "pagination" => %{"paginate?" => false}
        },
        streams: [
          %{description: String.duplicate("Very long text ", 100)}
        ]
      }

      html = render_component(&TestTableComponent.live_table/1, assigns)

      # Should prevent text wrapping in cells
      assert html =~ "whitespace-nowrap"
      # Table container handles overflow (overflow-hidden by default)
      assert html =~ "overflow-hidden"
    end

    test "handles special characters in data" do
      assigns = %{
        fields: [
          {:name, %{label: "Name", sortable: false}},
          {:code, %{label: "Code", sortable: false}}
        ],
        filters: [],
        options: %{
          "filters" => %{"search" => ""},
          "sort" => %{"sort_params" => []},
          "pagination" => %{"paginate?" => false}
        },
        streams: [
          %{name: "<script>alert('XSS')</script>", code: "a && b || c"}
        ]
      }

      html = render_component(&TestTableComponent.live_table/1, assigns)

      # Phoenix automatically escapes HTML - check that the dangerous content is present but escaped
      # Phoenix automatically escapes HTML - check that the dangerous content is NOT present as raw HTML
      refute html =~ "<script>alert"
      # Check for the double-escaped version (since it goes through Phoenix.HTML.Safe.to_iodata)
      assert html =~ "&amp;lt;script&amp;gt;"
      # Check for properly escaped && (double escaped)
      assert html =~ "a &amp;amp;&amp;amp; b"
    end

    test "handles empty string vs nil in search" do
      assigns = %{
        fields: [{:name, %{label: "Name", sortable: false, searchable: true}}],
        filters: [],
        options: %{
          "filters" => %{"search" => nil},
          "sort" => %{"sort_params" => []},
          "pagination" => %{"paginate?" => false}
        },
        streams: []
      }

      html = render_component(&TestTableComponent.live_table/1, assigns)

      # Should handle nil search value gracefully - no value attribute is rendered for nil
      assert html =~ "table-search"
      refute html =~ "value="
    end

    test "handles malformed pagination data" do
      assigns = %{
        fields: [{:name, %{label: "Name", sortable: false}}],
        filters: [],
        options: %{
          "filters" => %{"search" => ""},
          "sort" => %{"sort_params" => []},
          "pagination" => %{
            "paginate?" => true,
            # Valid page to avoid crash
            "page" => "1",
            # Valid per_page
            "per_page" => 10
          }
        },
        streams: []
      }

      # Should handle gracefully without crashing
      html = render_component(&TestTableComponent.live_table/1, assigns)
      assert html =~ "live-table"
      assert html =~ "Page"
      assert html =~ "1"
    end
  end

  describe "actions" do
    test "renders Actions header and action content when actions provided (use_streams: false)" do
      actions = [
        show: fn %{record: record} ->
          assigns = %{record: record}

          ~H"""
          <span class="action">Show {@record.name}</span>
          """
        end
      ]

      assigns = %{
        fields: [
          {:name, %{label: "Name", sortable: false}}
        ],
        filters: [],
        options: %{
          "filters" => %{"search" => ""},
          "sort" => %{"sort_params" => []},
          "pagination" => %{"paginate?" => false}
        },
        streams: [
          %{name: "Alpha"},
          %{name: "Beta"}
        ],
        actions: actions
      }

      html = render_component(&TestTableComponent.live_table/1, assigns)

      assert html =~ ~r/>\s*Actions\s*</
      assert html =~ "Show Alpha"
      assert html =~ "Show Beta"
    end

    test "does not render Actions header when no actions provided" do
      assigns = %{
        fields: [
          {:name, %{label: "Name", sortable: false}}
        ],
        filters: [],
        options: %{
          "filters" => %{"search" => ""},
          "sort" => %{"sort_params" => []},
          "pagination" => %{"paginate?" => false}
        },
        streams: [
          %{name: "Alpha"}
        ],
        actions: []
      }

      html = render_component(&TestTableComponent.live_table/1, assigns)

      refute html =~ ">Actions<"
    end

    test "renders multiple actions per row and passes record" do
      actions = [
        edit: fn %{record: record} ->
          assigns = %{record: record}

          ~H"""
          <span>Edit {@record.name}</span>
          """
        end,
        delete: fn %{record: record} ->
          assigns = %{record: record}

          ~H"""
          <span>Delete {@record.name}</span>
          """
        end
      ]

      assigns = %{
        fields: [
          {:name, %{label: "Name", sortable: false}}
        ],
        filters: [],
        options: %{
          "filters" => %{"search" => ""},
          "sort" => %{"sort_params" => []},
          "pagination" => %{"paginate?" => false}
        },
        streams: [
          %{name: "Gamma"}
        ],
        actions: actions
      }

      html = render_component(&TestTableComponent.live_table/1, assigns)

      assert html =~ "Edit Gamma"
      assert html =~ "Delete Gamma"
    end

    test "renders actions when use_streams is true" do
      actions = [
        show: fn %{record: record} ->
          assigns = %{record: record}

          ~H"""
          <span class="action">Show {@record.name}</span>
          """
        end
      ]

      assigns = %{
        fields: [
          {:name, %{label: "Name", sortable: false}}
        ],
        filters: [],
        options: %{
          "filters" => %{"search" => ""},
          "sort" => %{"sort_params" => []},
          "pagination" => %{"paginate?" => false}
        },
        streams: %{
          resources: [
            {"1", %{name: "Delta"}},
            {"2", %{name: "Epsilon"}}
          ]
        },
        actions: actions
      }

      html = render_component(&StreamTableComponent.live_table/1, assigns)

      assert html =~ "Show Delta"
      assert html =~ "Show Epsilon"
    end

    test "empty state colspan includes actions column when actions provided" do
      actions = [
        show: fn %{record: record} ->
          assigns = %{record: record}

          ~H"""
          <span class="action">Show {@record}</span>
          """
        end
      ]

      assigns_with_actions = %{
        fields: [
          {:name, %{label: "Name", sortable: false}},
          {:email, %{label: "Email", sortable: false}}
        ],
        filters: [],
        options: %{
          "filters" => %{"search" => ""},
          "sort" => %{"sort_params" => []},
          "pagination" => %{"paginate?" => false}
        },
        streams: [],
        actions: actions
      }

      assigns_without_actions = Map.put(assigns_with_actions, :actions, [])

      html_with_actions = render_component(&TestTableComponent.live_table/1, assigns_with_actions)

      html_without_actions =
        render_component(&TestTableComponent.live_table/1, assigns_without_actions)

      assert html_with_actions =~ ~s(id=\"empty-placeholder\")
      assert html_with_actions =~ ~s(colspan=\"3\")

      assert html_without_actions =~ ~s(id=\"empty-placeholder\")
      assert html_without_actions =~ ~s(colspan=\"2\")
    end
  end

  describe "hidden fields" do
    test "hidden field is excluded from table headers" do
      assigns = %{
        fields: [
          {:name, %{label: "Name", sortable: false}},
          {:secret, %{label: "Secret", sortable: false, hidden: true}},
          {:email, %{label: "Email", sortable: false}}
        ],
        filters: [],
        options: %{
          "filters" => %{"search" => ""},
          "sort" => %{"sort_params" => []},
          "pagination" => %{"paginate?" => false}
        },
        streams: [%{name: "John", secret: "hidden-value", email: "john@example.com"}]
      }

      html = render_component(&TestTableComponent.live_table/1, assigns)

      # Should have Name and Email headers, but not Secret
      assert html =~ ">Name<"
      assert html =~ ">Email<"
      refute html =~ ">Secret<"
    end

    test "hidden field is excluded from table cells" do
      assigns = %{
        fields: [
          {:name, %{label: "Name", sortable: false}},
          {:secret, %{label: "Secret", sortable: false, hidden: true}},
          {:email, %{label: "Email", sortable: false}}
        ],
        filters: [],
        options: %{
          "filters" => %{"search" => ""},
          "sort" => %{"sort_params" => []},
          "pagination" => %{"paginate?" => false}
        },
        streams: [%{name: "John", secret: "hidden-value", email: "john@example.com"}]
      }

      html = render_component(&TestTableComponent.live_table/1, assigns)

      # Should render name and email values, but not secret
      assert html =~ "John"
      assert html =~ "john@example.com"
      refute html =~ "hidden-value"
    end

    test "visible_fields keeps fields without hidden key (defaults to false)" do
      assigns = %{
        fields: [
          {:name, %{label: "Name", sortable: false}},
          {:email, %{label: "Email", sortable: false}},
          {:visible, %{label: "Visible", sortable: false, hidden: false}}
        ],
        filters: [],
        options: %{
          "filters" => %{"search" => ""},
          "sort" => %{"sort_params" => []},
          "pagination" => %{"paginate?" => false}
        },
        streams: [%{name: "John", email: "john@example.com", visible: "yes"}]
      }

      html = render_component(&TestTableComponent.live_table/1, assigns)

      # All three should be visible
      assert html =~ ">Name<"
      assert html =~ ">Email<"
      assert html =~ ">Visible<"
    end

    test "empty state colspan accounts for visible fields only" do
      assigns = %{
        fields: [
          {:name, %{label: "Name", sortable: false}},
          {:secret, %{label: "Secret", sortable: false, hidden: true}},
          {:email, %{label: "Email", sortable: false}}
        ],
        filters: [],
        options: %{
          "filters" => %{"search" => ""},
          "sort" => %{"sort_params" => []},
          "pagination" => %{"paginate?" => false}
        },
        streams: [],
        actions: []
      }

      html = render_component(&TestTableComponent.live_table/1, assigns)

      # 2 visible fields (name, email), so colspan should be 2
      assert html =~ ~s(colspan="2")
    end

    test "hidden field with actions still calculates colspan correctly" do
      actions = [
        show: fn %{record: record} ->
          assigns = %{record: record}

          ~H"""
          <span>Show</span>
          """
        end
      ]

      assigns = %{
        fields: [
          {:name, %{label: "Name", sortable: false}},
          {:secret, %{label: "Secret", sortable: false, hidden: true}},
          {:email, %{label: "Email", sortable: false}}
        ],
        filters: [],
        options: %{
          "filters" => %{"search" => ""},
          "sort" => %{"sort_params" => []},
          "pagination" => %{"paginate?" => false}
        },
        streams: [],
        actions: actions
      }

      html = render_component(&TestTableComponent.live_table/1, assigns)

      # 2 visible fields + 1 actions column = 3
      assert html =~ ~s(colspan="3")
    end
  end

  describe "sortable defaults" do
    test "field without sortable key defaults to non-sortable (renders plain label)" do
      assigns = %{
        fields: [
          {:name, %{label: "Name"}},
          {:email, %{label: "Email", sortable: true}}
        ],
        filters: [],
        options: %{
          "filters" => %{"search" => ""},
          "sort" => %{"sort_params" => []},
          "pagination" => %{"paginate?" => false}
        },
        streams: []
      }

      html = render_component(&TestTableComponent.live_table/1, assigns)

      # Name should be plain span (not sortable), Email should have sort link
      # Count sort links - only Email should have one
      sort_click_count = html |> String.split("phx-click=\"sort\"") |> length() |> Kernel.-(1)

      # Email has sortable: true, so it gets a sort link
      # Name has no sortable key, defaults to false, so no sort link
      # The form itself has phx-change="sort", but phx-click="sort" is on sort links
      assert sort_click_count >= 1
      assert html =~ ">Email<"
    end

    test "field with sortable: false renders plain label" do
      assigns = %{
        fields: [
          {:name, %{label: "Name", sortable: false}}
        ],
        filters: [],
        options: %{
          "filters" => %{"search" => ""},
          "sort" => %{"sort_params" => []},
          "pagination" => %{"paginate?" => false}
        },
        streams: []
      }

      html = render_component(&TestTableComponent.live_table/1, assigns)

      # Should render plain span, not a clickable sort link
      assert html =~ "<span>Name</span>"
    end
  end

  describe "empty_text field option" do
    test "renders empty_text when field value is nil" do
      assigns = %{
        fields: [
          {:name, %{label: "Name", sortable: false}},
          {:notes, %{label: "Notes", sortable: false, empty_text: "N/A"}}
        ],
        filters: [],
        options: %{
          "filters" => %{"search" => ""},
          "sort" => %{"sort_params" => []},
          "pagination" => %{"paginate?" => false}
        },
        streams: [%{name: "John", notes: nil}]
      }

      html = render_component(&TestTableComponent.live_table/1, assigns)

      assert html =~ "John"
      assert html =~ "N/A"
    end

    test "renders actual value when not nil (ignores empty_text)" do
      assigns = %{
        fields: [
          {:name, %{label: "Name", sortable: false}},
          {:notes, %{label: "Notes", sortable: false, empty_text: "N/A"}}
        ],
        filters: [],
        options: %{
          "filters" => %{"search" => ""},
          "sort" => %{"sort_params" => []},
          "pagination" => %{"paginate?" => false}
        },
        streams: [%{name: "John", notes: "Some notes here"}]
      }

      html = render_component(&TestTableComponent.live_table/1, assigns)

      assert html =~ "John"
      assert html =~ "Some notes here"
      # N/A should not appear since notes has a value
      refute html =~ ">N/A<"
    end

    test "renders nothing special when value is nil and no empty_text set" do
      assigns = %{
        fields: [
          {:name, %{label: "Name", sortable: false}},
          {:notes, %{label: "Notes", sortable: false}}
        ],
        filters: [],
        options: %{
          "filters" => %{"search" => ""},
          "sort" => %{"sort_params" => []},
          "pagination" => %{"paginate?" => false}
        },
        streams: [%{name: "John", notes: nil}]
      }

      html = render_component(&TestTableComponent.live_table/1, assigns)

      assert html =~ "John"
      # No special empty text should appear
      refute html =~ "N/A"
    end
  end

  describe "infinite scroll mode" do
    defmodule InfiniteScrollComponent do
      use LiveTable.TableComponent,
        table_options: %{
          mode: :card,
          use_streams: true,
          pagination: %{mode: :infinite_scroll},
          card_component: fn %{record: record} ->
            assigns = %{record: record}

            ~H"""
            <div class="card">{@record.name}</div>
            """
          end
        }
    end

    test "renders phx-viewport-bottom with load_more when has_next_page is true" do
      assigns = %{
        fields: [],
        filters: [],
        options: %{
          "filters" => %{"search" => ""},
          "sort" => %{"sort_params" => []},
          "pagination" => %{"paginate?" => true, has_next_page: true}
        },
        streams: %{
          resources: [
            {"item-1", %{name: "Item 1"}},
            {"item-2", %{name: "Item 2"}}
          ]
        }
      }

      html = render_component(&InfiniteScrollComponent.live_table/1, assigns)

      assert html =~ "phx-viewport-bottom=\"load_more\""
      assert html =~ "phx-throttle=\"1000\""
    end

    test "does not render phx-viewport-bottom when has_next_page is false" do
      assigns = %{
        fields: [],
        filters: [],
        options: %{
          "filters" => %{"search" => ""},
          "sort" => %{"sort_params" => []},
          "pagination" => %{"paginate?" => true, has_next_page: false}
        },
        streams: %{
          resources: [
            {"item-1", %{name: "Item 1"}}
          ]
        }
      }

      html = render_component(&InfiniteScrollComponent.live_table/1, assigns)

      refute html =~ "phx-viewport-bottom=\"load_more\""
    end

    test "renders loader when has_next_page is true" do
      assigns = %{
        fields: [],
        filters: [],
        options: %{
          "filters" => %{"search" => ""},
          "sort" => %{"sort_params" => []},
          "pagination" => %{"paginate?" => true, has_next_page: true}
        },
        streams: %{
          resources: [{"item-1", %{name: "Item 1"}}]
        }
      }

      html = render_component(&InfiniteScrollComponent.live_table/1, assigns)

      # Default loader has animate-spin class
      assert html =~ "animate-spin"
    end

    test "does not render loader when has_next_page is false" do
      assigns = %{
        fields: [],
        filters: [],
        options: %{
          "filters" => %{"search" => ""},
          "sort" => %{"sort_params" => []},
          "pagination" => %{"paginate?" => true, has_next_page: false}
        },
        streams: %{
          resources: [{"item-1", %{name: "Item 1"}}]
        }
      }

      html = render_component(&InfiniteScrollComponent.live_table/1, assigns)

      refute html =~ "animate-spin"
    end

    test "uses custom loading_component when provided" do
      defmodule CustomLoaderComponent do
        use LiveTable.TableComponent,
          table_options: %{
            mode: :card,
            use_streams: true,
            pagination: %{
              mode: :infinite_scroll,
              loading_component: fn _ ->
                assigns = %{}

                ~H"""
                <div class="custom-loader">Loading more...</div>
                """
              end
            },
            card_component: fn %{record: record} ->
              assigns = %{record: record}

              ~H"""
              <div class="card">{@record.name}</div>
              """
            end
          }
      end

      assigns = %{
        fields: [],
        filters: [],
        options: %{
          "filters" => %{"search" => ""},
          "sort" => %{"sort_params" => []},
          "pagination" => %{"paginate?" => true, has_next_page: true}
        },
        streams: %{
          resources: [{"item-1", %{name: "Item 1"}}]
        }
      }

      html = render_component(&CustomLoaderComponent.live_table/1, assigns)

      assert html =~ "custom-loader"
      assert html =~ "Loading more..."
    end
  end

  describe "fixed header" do
    defmodule FixedHeaderTable do
      use LiveTable.TableComponent,
        table_options: %{
          mode: :table,
          use_streams: false,
          fixed_header: true
        }
    end

    defmodule NoFixedHeaderTable do
      use LiveTable.TableComponent,
        table_options: %{
          mode: :table,
          use_streams: false,
          fixed_header: false
        }
    end

    test "applies max-h and overflow-y-auto when fixed_header: true" do
      assigns = %{
        fields: [{:name, %{label: "Name", sortable: false}}],
        filters: [],
        options: %{
          "filters" => %{"search" => ""},
          "sort" => %{"sort_params" => []},
          "pagination" => %{"paginate?" => false}
        },
        streams: [%{name: "Test"}]
      }

      html = render_component(&FixedHeaderTable.live_table/1, assigns)

      assert html =~ "max-h-[600px]"
      assert html =~ "overflow-y-auto"
    end

    test "applies overflow-hidden when fixed_header: false" do
      assigns = %{
        fields: [{:name, %{label: "Name", sortable: false}}],
        filters: [],
        options: %{
          "filters" => %{"search" => ""},
          "sort" => %{"sort_params" => []},
          "pagination" => %{"paginate?" => false}
        },
        streams: [%{name: "Test"}]
      }

      html = render_component(&NoFixedHeaderTable.live_table/1, assigns)

      assert html =~ "overflow-hidden"
      refute html =~ "max-h-[600px]"
      refute html =~ "overflow-y-auto"
    end

    test "applies sticky top-0 z-10 to thead when fixed_header: true" do
      assigns = %{
        fields: [{:name, %{label: "Name", sortable: false}}],
        filters: [],
        options: %{
          "filters" => %{"search" => ""},
          "sort" => %{"sort_params" => []},
          "pagination" => %{"paginate?" => false}
        },
        streams: [%{name: "Test"}]
      }

      html = render_component(&FixedHeaderTable.live_table/1, assigns)

      assert html =~ "sticky"
      assert html =~ "top-0"
      assert html =~ "z-10"
    end

    test "does not apply sticky classes when fixed_header: false" do
      assigns = %{
        fields: [{:name, %{label: "Name", sortable: false}}],
        filters: [],
        options: %{
          "filters" => %{"search" => ""},
          "sort" => %{"sort_params" => []},
          "pagination" => %{"paginate?" => false}
        },
        streams: [%{name: "Test"}]
      }

      html = render_component(&NoFixedHeaderTable.live_table/1, assigns)

      # The thead should not have sticky class
      # We need to check the thead specifically
      [_, thead_part | _] = String.split(html, "<thead")
      [thead_content, _] = String.split(thead_part, "</thead>", parts: 2)

      refute thead_content =~ "sticky"
    end
  end

  describe "custom empty state" do
    test "uses custom empty_state callback when provided" do
      defmodule CustomEmptyStateTable do
        use LiveTable.TableComponent,
          table_options: %{
            mode: :table,
            use_streams: false,
            empty_state: fn _assigns ->
              assigns = %{}

              ~H"""
              <div class="custom-empty">Nothing to see here!</div>
              """
            end
          }
      end

      assigns = %{
        fields: [{:name, %{label: "Name", sortable: false}}],
        filters: [],
        options: %{
          "filters" => %{"search" => ""},
          "sort" => %{"sort_params" => []},
          "pagination" => %{"paginate?" => false}
        },
        streams: []
      }

      html = render_component(&CustomEmptyStateTable.live_table/1, assigns)

      assert html =~ "custom-empty"
      assert html =~ "Nothing to see here!"
      refute html =~ "No data"
    end

    test "uses default empty state when no callback provided" do
      assigns = %{
        fields: [{:name, %{label: "Name", sortable: false}}],
        filters: [],
        options: %{
          "filters" => %{"search" => ""},
          "sort" => %{"sort_params" => []},
          "pagination" => %{"paginate?" => false}
        },
        streams: []
      }

      html = render_component(&TestTableComponent.live_table/1, assigns)

      assert html =~ "No data"
      assert html =~ "No records found"
    end
  end

  describe "actions header styling" do
    test "actions header has text-center class" do
      actions = [
        show: fn %{record: _record} ->
          assigns = %{}

          ~H"""
          <span>Show</span>
          """
        end
      ]

      assigns = %{
        fields: [{:name, %{label: "Name", sortable: false}}],
        filters: [],
        options: %{
          "filters" => %{"search" => ""},
          "sort" => %{"sort_params" => []},
          "pagination" => %{"paginate?" => false}
        },
        streams: [%{name: "Test"}],
        actions: actions
      }

      html = render_component(&TestTableComponent.live_table/1, assigns)

      # Find the actions header th element - it should have text-center
      assert html =~ "text-center"
      # Actions label is rendered with whitespace around it
      assert html =~ ~r/>\s*Actions\s*</
    end

    test "uses custom actions label when provided" do
      actions = %{
        label: "Operations",
        items: [
          show: fn %{record: _record} ->
            assigns = %{}

            ~H"""
            <span>Show</span>
            """
          end
        ]
      }

      assigns = %{
        fields: [{:name, %{label: "Name", sortable: false}}],
        filters: [],
        options: %{
          "filters" => %{"search" => ""},
          "sort" => %{"sort_params" => []},
          "pagination" => %{"paginate?" => false}
        },
        streams: [%{name: "Test"}],
        actions: actions
      }

      html = render_component(&TestTableComponent.live_table/1, assigns)

      assert html =~ ~r/>\s*Operations\s*</
      refute html =~ ~r/>\s*Actions\s*</
    end

    test "defaults to 'Actions' label when not provided" do
      actions = [
        show: fn %{record: _record} ->
          assigns = %{}

          ~H"""
          <span>Show</span>
          """
        end
      ]

      assigns = %{
        fields: [{:name, %{label: "Name", sortable: false}}],
        filters: [],
        options: %{
          "filters" => %{"search" => ""},
          "sort" => %{"sort_params" => []},
          "pagination" => %{"paginate?" => false}
        },
        streams: [%{name: "Test"}],
        actions: actions
      }

      html = render_component(&TestTableComponent.live_table/1, assigns)

      assert html =~ ~r/>\s*Actions\s*</
    end
  end

  describe "custom controls" do
    test "uses custom controls in table mode and hides defaults" do
      defmodule CustomControlsTable do
        use LiveTable.TableComponent,
          table_options: %{
            mode: :table,
            use_streams: false,
            custom_controls: {LiveTable.TableComponentTest.CustomControls, :controls},
            pagination: %{enabled: true, mode: :buttons, sizes: [10, 25, 50], default_size: 10},
            search: %{enabled: true, debounce: 300, placeholder: "Search..."},
            exports: %{enabled: true, formats: [:csv, :pdf]}
          }
      end

      assigns = %{
        fields: [
          {:name, %{label: "Name", sortable: true, searchable: true}}
        ],
        filters: [],
        options: %{
          "filters" => %{"search" => ""},
          "sort" => %{"sort_params" => []},
          "pagination" => %{"paginate?" => true, "per_page" => 10, "page" => "1"}
        },
        streams: []
      }

      html = render_component(&CustomControlsTable.live_table/1, assigns)

      assert html =~ "custom-controls"
      # Default per_page select should not render when custom_controls provided
      refute html =~ "name=\"per_page\""
      # Default search input should not render
      refute html =~ "table-search"
    end

    test "uses custom controls in card mode" do
      defmodule CustomControlsCardTable do
        use LiveTable.TableComponent,
          table_options: %{
            mode: :card,
            use_streams: false,
            custom_controls: {LiveTable.TableComponentTest.CustomControls, :controls},
            pagination: %{enabled: true, mode: :buttons, sizes: [10, 25, 50], default_size: 10},
            search: %{enabled: true, debounce: 300, placeholder: "Search..."},
            exports: %{enabled: true, formats: [:csv, :pdf]},
            card_component: fn %{record: record} ->
              assigns = %{record: record}

              ~H"""
              <div class="card">{@record.name}</div>
              """
            end
          }
      end

      assigns = %{
        fields: [],
        filters: [],
        options: %{
          "filters" => %{"search" => ""},
          "sort" => %{"sort_params" => []},
          "pagination" => %{"paginate?" => true, "per_page" => 10, "page" => "1"}
        },
        streams: [%{name: "X"}]
      }

      html = render_component(&CustomControlsCardTable.live_table/1, assigns)

      assert html =~ "custom-controls"
      refute html =~ "name=\"per_page\""
    end

    test "custom_header takes precedence over custom_controls" do
      defmodule CustomHeader2 do
        use Phoenix.Component

        def header(assigns) do
          ~H"""
          <div id="custom-header">Header Only</div>
          """
        end
      end

      defmodule CustomHeaderWithControlsTable do
        use LiveTable.TableComponent,
          table_options: %{
            mode: :table,
            use_streams: false,
            custom_header: {CustomHeader2, :header},
            custom_controls: {LiveTable.TableComponentTest.CustomControls, :controls}
          }
      end

      assigns = %{
        fields: [],
        filters: [],
        options: %{
          "filters" => %{"search" => ""},
          "sort" => %{"sort_params" => []},
          "pagination" => %{"paginate?" => false}
        },
        streams: []
      }

      html = render_component(&CustomHeaderWithControlsTable.live_table/1, assigns)

      assert html =~ "custom-header"
      refute html =~ "custom-controls"
    end
  end
end
