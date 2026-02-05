defmodule LiveTable.TableConfigTest do
  @moduledoc """
  Tests for LiveTable.TableConfig - configuration management.

  TableConfig handles merging of default options with app-level and
  user-level configurations. This is critical for ensuring the library
  behaves predictably across different configuration scenarios.

  ## What This Tests

    * Deep merging of nested maps
    * Default options are applied correctly
    * App-level defaults from Application config
    * User options override defaults
    * Edge cases with nil and empty values
  """

  use ExUnit.Case, async: true

  alias LiveTable.TableConfig

  describe "deep_merge/2" do
    test "merges flat maps" do
      left = %{a: 1, b: 2}
      right = %{b: 3, c: 4}

      result = TableConfig.deep_merge(left, right)

      assert result == %{a: 1, b: 3, c: 4}
    end

    test "deep merges nested maps" do
      left = %{
        outer: %{
          inner: %{value: 1},
          other: "left"
        }
      }

      right = %{
        outer: %{
          inner: %{value: 2, new: "added"}
        }
      }

      result = TableConfig.deep_merge(left, right)

      assert result == %{
               outer: %{
                 inner: %{value: 2, new: "added"},
                 other: "left"
               }
             }
    end

    test "right side wins on conflicts for non-map values" do
      left = %{key: "left_value"}
      right = %{key: "right_value"}

      result = TableConfig.deep_merge(left, right)

      assert result.key == "right_value"
    end

    test "right side non-map replaces left side map" do
      left = %{key: %{nested: "value"}}
      right = %{key: "simple"}

      result = TableConfig.deep_merge(left, right)

      assert result.key == "simple"
    end

    test "handles empty maps" do
      assert TableConfig.deep_merge(%{}, %{a: 1}) == %{a: 1}
      assert TableConfig.deep_merge(%{a: 1}, %{}) == %{a: 1}
      assert TableConfig.deep_merge(%{}, %{}) == %{}
    end

    test "deeply nested merge preserves unaffected branches" do
      left = %{
        level1: %{
          level2a: %{
            level3: "original"
          },
          level2b: %{
            untouched: "value"
          }
        }
      }

      right = %{
        level1: %{
          level2a: %{
            level3: "modified"
          }
        }
      }

      result = TableConfig.deep_merge(left, right)

      assert result.level1.level2a.level3 == "modified"
      assert result.level1.level2b.untouched == "value"
    end

    test "merges multiple levels deep" do
      left = %{
        a: %{
          b: %{
            c: %{
              d: 1
            }
          }
        }
      }

      right = %{
        a: %{
          b: %{
            c: %{
              d: 2,
              e: 3
            }
          }
        }
      }

      result = TableConfig.deep_merge(left, right)

      assert result.a.b.c.d == 2
      assert result.a.b.c.e == 3
    end
  end

  describe "get_table_options/1" do
    test "returns defaults when given empty map" do
      result = TableConfig.get_table_options(%{})

      # Check key default values
      assert result.pagination.enabled == true
      assert result.pagination.mode == :buttons
      assert result.pagination.sizes == [10, 25, 50]
      assert result.pagination.default_size == 10

      assert result.sorting.enabled == true
      assert result.sorting.default_sort == [id: :asc]

      assert result.exports.enabled == true
      assert result.exports.formats == [:csv, :pdf]

      assert result.search.enabled == true
      assert result.search.debounce == 300
      assert result.search.placeholder == "Search..."
      assert result.search.mode == :auto

      assert result.mode == :table
      assert result.use_streams == true
      assert result.fixed_header == false
      assert result.debug == :off
    end

    test "merges user options with defaults" do
      user_options = %{
        pagination: %{
          default_size: 25,
          sizes: [25, 50, 100]
        },
        debug: :query
      }

      result = TableConfig.get_table_options(user_options)

      # User options applied
      assert result.pagination.default_size == 25
      assert result.pagination.sizes == [25, 50, 100]
      assert result.debug == :query

      # Defaults preserved for unspecified options
      assert result.pagination.enabled == true
      assert result.pagination.mode == :buttons
      assert result.sorting.enabled == true
    end

    test "user options override nested defaults" do
      user_options = %{
        sorting: %{
          default_sort: [name: :desc]
        }
      }

      result = TableConfig.get_table_options(user_options)

      assert result.sorting.default_sort == [name: :desc]
      # Default preserved
      assert result.sorting.enabled == true
    end

    test "handles mode option" do
      table_result = TableConfig.get_table_options(%{mode: :table})
      card_result = TableConfig.get_table_options(%{mode: :card})

      assert table_result.mode == :table
      assert card_result.mode == :card
    end

    test "handles custom search options" do
      user_options = %{
        search: %{
          enabled: false,
          placeholder: "Find items..."
        }
      }

      result = TableConfig.get_table_options(user_options)

      assert result.search.enabled == false
      assert result.search.placeholder == "Find items..."
      # Default preserved
      assert result.search.debounce == 300
    end

    test "handles custom export options" do
      user_options = %{
        exports: %{
          enabled: true,
          # Only CSV, no PDF
          formats: [:csv]
        }
      }

      result = TableConfig.get_table_options(user_options)

      assert result.exports.formats == [:csv]
    end

    test "handles infinite scroll pagination mode" do
      user_options = %{
        pagination: %{
          mode: :infinite_scroll,
          enabled: true
        }
      }

      result = TableConfig.get_table_options(user_options)

      assert result.pagination.mode == :infinite_scroll
      assert result.pagination.enabled == true
    end

    test "handles fixed_header option" do
      result = TableConfig.get_table_options(%{fixed_header: true})

      assert result.fixed_header == true
    end

    test "handles use_streams option" do
      result = TableConfig.get_table_options(%{use_streams: false})

      assert result.use_streams == false
    end

    test "handles debug modes" do
      assert TableConfig.get_table_options(%{debug: :off}).debug == :off
      assert TableConfig.get_table_options(%{debug: :query}).debug == :query
      assert TableConfig.get_table_options(%{debug: :trace}).debug == :trace
    end

    test "handles custom_header option" do
      user_options = %{
        custom_header: {MyModule, :render_header}
      }

      result = TableConfig.get_table_options(user_options)

      assert result.custom_header == {MyModule, :render_header}
    end

    test "handles custom_content option" do
      user_options = %{
        custom_content: {MyModule, :render_content}
      }

      result = TableConfig.get_table_options(user_options)

      assert result.custom_content == {MyModule, :render_content}
    end

    test "handles custom_footer option" do
      user_options = %{
        custom_footer: {MyModule, :render_footer}
      }

      result = TableConfig.get_table_options(user_options)

      assert result.custom_footer == {MyModule, :render_footer}
    end

    test "handles card_component option" do
      card_fn = fn assigns -> assigns end

      user_options = %{
        mode: :card,
        card_component: card_fn
      }

      result = TableConfig.get_table_options(user_options)

      assert result.card_component == card_fn
    end

    test "handles empty_state option" do
      empty_fn = fn assigns -> assigns end

      user_options = %{
        empty_state: empty_fn
      }

      result = TableConfig.get_table_options(user_options)

      assert result.empty_state == empty_fn
    end

    test "preserves all pagination sizes" do
      user_options = %{
        pagination: %{
          sizes: [5, 10, 20, 50, 100]
        }
      }

      result = TableConfig.get_table_options(user_options)

      assert result.pagination.sizes == [5, 10, 20, 50, 100]
    end
  end

  describe "get_table_options/1 with app config" do
    # Note: These tests verify the function reads from Application config.
    # In a real test environment, you might need to set up the config.

    test "app defaults are overridden by user options" do
      # Even if app config has defaults, user options should win
      user_options = %{
        pagination: %{
          default_size: 50
        }
      }

      result = TableConfig.get_table_options(user_options)

      # User option wins
      assert result.pagination.default_size == 50
    end
  end

  describe "edge cases" do
    test "handles nil values in user options" do
      # nil values should not crash
      user_options = %{
        pagination: nil
      }

      # This might raise or handle gracefully depending on implementation
      # Testing current behavior
      result = TableConfig.get_table_options(user_options)

      # The nil replaces the default map for pagination
      assert result.pagination == nil
    end

    test "handles completely custom options" do
      user_options = %{
        custom_key: "custom_value",
        nested_custom: %{
          key: "value"
        }
      }

      result = TableConfig.get_table_options(user_options)

      assert result.custom_key == "custom_value"
      assert result.nested_custom.key == "value"
    end

    test "real-world configuration example" do
      # Simulates a typical user configuration
      user_options = %{
        pagination: %{
          enabled: true,
          default_size: 20,
          sizes: [10, 20, 50]
        },
        sorting: %{
          default_sort: [inserted_at: :desc]
        },
        search: %{
          placeholder: "Search users..."
        },
        exports: %{
          formats: [:csv]
        },
        debug: :off
      }

      result = TableConfig.get_table_options(user_options)

      # Verify all user options applied
      assert result.pagination.default_size == 20
      assert result.pagination.sizes == [10, 20, 50]
      assert result.sorting.default_sort == [inserted_at: :desc]
      assert result.search.placeholder == "Search users..."
      assert result.exports.formats == [:csv]

      # Verify defaults preserved
      assert result.pagination.mode == :buttons
      assert result.sorting.enabled == true
      assert result.search.debounce == 300
      assert result.mode == :table
    end
  end

  describe "get_search_mode/2" do
    test "defaults to adapter-based mode when set to auto" do
      assert TableConfig.get_search_mode(%{}, LiveTable.Repo) == :ilike
    end

    test "uses explicit mode from table options" do
      assert TableConfig.get_search_mode(%{search: %{mode: :like}}, LiveTable.Repo) == :like
    end

    test "uses db setting when mode is auto" do
      assert TableConfig.get_search_mode(%{search: %{mode: :auto, db: :sqlite}}, LiveTable.Repo) ==
               :like_lower
    end

    test "uses adapter setting when mode is auto" do
      assert TableConfig.get_search_mode(
               %{search: %{adapter: Ecto.Adapters.SQLite3}},
               LiveTable.Repo
             ) ==
               :like_lower
    end
  end
end
