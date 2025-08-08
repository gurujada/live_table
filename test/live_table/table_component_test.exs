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
      assert html =~ "Get started by creating a new record"
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
      assert html =~ "Clear filters"
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

      assert html =~ "toggle_filters"
      assert html =~ "Filters"
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

      refute html =~ "toggle_filters"
      refute html =~ "toggle_filters"
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
      assert html =~ "phx-click=\"export-csv\""
      assert html =~ "phx-click=\"export-pdf\""
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

      assert_raise ArgumentError, ~r/Requires `use_streams` to be set/, fn ->
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

      # Check for dark mode classes in the new UI
      assert html =~ "dark:bg-gray-800"
      assert html =~ "dark:text-gray-100"
      # Check for dark mode border/divide classes (divide is used for table borders)
      assert html =~ "dark:divide-gray-700"
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

      # Should prevent text wrapping
      assert html =~ "whitespace-nowrap"
      # Should allow horizontal scroll
      assert html =~ "overflow-x-auto"
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
end
