defmodule LiveTable.FilterHelpersTest do
  @moduledoc """
  Tests for LiveTable.FilterHelpers - URL encoding/decoding for filter state.

  FilterHelpers is a macro module that injects filter handling functions into
  modules that `use` it. This enables filter state to be persisted in URLs
  and restored when navigating back to a page.

  ## What This Tests

    * `get_filter/1` - Retrieving filters by string or atom key
    * `update_filter_params/2` - Processing incoming filter parameters
    * `encode_filters/1` - Encoding filter state for URL params

  ## Usage in LiveResource

  When a module uses `LiveTable.FilterHelpers`, it gains these functions:

      def get_filter("price_range"), do: %LiveTable.Range{...}
      def get_filter(:price_range), do: %LiveTable.Range{...}

      # Called when processing URL params or form submissions
      defp update_filter_params(map, %{"price_range" => %{"min" => "10", "max" => "100"}})

      # Called when generating URLs with filter state
      def encode_filters(filters)
  """

  use LiveTable.DataCase, async: true
  use LiveTable.FilterHelpers

  alias LiveTable.{Boolean, Range, Select, Transformer}

  import Ecto.Query

  # Required callback for FilterHelpers - defines available filters
  def filters do
    [
      under_100:
        Boolean.new(:price, "under-100", %{
          label: "Under $100",
          condition: dynamic([p], p.price < 100)
        }),
      price_range:
        Range.new(:price, "price_range", %{
          label: "Price Range",
          min: 0,
          max: 1000,
          step: 10,
          current_min: 50,
          current_max: 200
        }),
      category:
        Select.new({:category, :id}, "category", %{
          label: "Category",
          selected: [1, 2]
        }),
      high_value:
        Transformer.new("high_value", %{
          query_transformer: fn q, _data -> q end,
          applied_data: %{"min_value" => "500"}
        })
    ]
  end

  describe "get_filter/1 with string key" do
    test "retrieves filter by string key" do
      filter = get_filter("under_100")

      assert %Boolean{} = filter
      assert filter.key == "under-100"
    end

    test "retrieves Range filter by string key" do
      filter = get_filter("price_range")

      assert %Range{} = filter
      assert filter.field == :price
    end

    test "retrieves Select filter by string key" do
      filter = get_filter("category")

      assert %Select{} = filter
      assert filter.field == {:category, :id}
    end

    test "retrieves Transformer by string key" do
      filter = get_filter("high_value")

      assert %Transformer{} = filter
      assert filter.key == "high_value"
    end

    test "returns nil for non-existent string key" do
      filter = get_filter("nonexistent")

      assert filter == nil
    end
  end

  describe "get_filter/1 with atom key" do
    test "retrieves filter by atom key" do
      filter = get_filter(:under_100)

      assert %Boolean{} = filter
      assert filter.key == "under-100"
    end

    test "retrieves Range filter by atom key" do
      filter = get_filter(:price_range)

      assert %Range{} = filter
      assert filter.options.min == 0
      assert filter.options.max == 1000
    end

    test "returns nil for non-existent atom key" do
      filter = get_filter(:nonexistent)

      assert filter == nil
    end
  end

  describe "update_filter_params/2 with nil params" do
    test "returns map unchanged when params is nil" do
      initial_map = %{"page" => "1", "filters" => %{"existing" => "value"}}

      result = update_filter_params(initial_map, nil)

      assert result == initial_map
    end
  end

  describe "update_filter_params/2 with boolean filter params" do
    test "adds boolean filter when value is 'true'" do
      initial_map = %{}

      result = update_filter_params(initial_map, %{"under_100" => "true"})

      assert result["filters"]["under_100"] == "under-100"
    end

    test "removes boolean filter when value is 'false'" do
      initial_map = %{"filters" => %{"under_100" => "under-100"}}

      result = update_filter_params(initial_map, %{"under_100" => "false"})

      refute Map.has_key?(result["filters"], "under_100")
    end

    test "preserves existing filters when adding new boolean" do
      initial_map = %{"filters" => %{"existing" => "value"}}

      result = update_filter_params(initial_map, %{"under_100" => "true"})

      assert result["filters"]["existing"] == "value"
      assert result["filters"]["under_100"] == "under-100"
    end
  end

  describe "update_filter_params/2 with range filter params" do
    test "adds range filter with min and max" do
      initial_map = %{}

      result =
        update_filter_params(initial_map, %{"price_range" => %{"min" => "10", "max" => "100"}})

      assert result["filters"]["price_range"] == [min: "10", max: "100"]
    end

    test "updates existing range filter" do
      initial_map = %{"filters" => %{"price_range" => [min: "0", max: "50"]}}

      result =
        update_filter_params(initial_map, %{"price_range" => %{"min" => "20", "max" => "200"}})

      assert result["filters"]["price_range"] == [min: "20", max: "200"]
    end
  end

  describe "update_filter_params/2 with select filter params (SutraUI.LiveSelect JSON format)" do
    test "handles single selection JSON with value array" do
      # SutraUI.LiveSelect sends: {"label": "Category 1", "value": [1, "desc"]}
      json = ~s({"label": "Category 1", "value": [1, "desc"]})
      initial_map = %{}

      result = update_filter_params(initial_map, %{"category" => json})

      assert result["filters"]["category"] == %{id: [1]}
    end

    test "handles single selection JSON with simple value" do
      # Sometimes value is just the id: {"label": "Category 1", "value": 1}
      json = ~s({"label": "Category 1", "value": 1})
      initial_map = %{}

      result = update_filter_params(initial_map, %{"category" => json})

      assert result["filters"]["category"] == %{id: [1]}
    end

    test "handles multiple selections (tags mode) with JSON list" do
      # List of JSON strings for multi-select
      json_list = [
        ~s({"label": "Cat 1", "value": [1, "desc"]}),
        ~s({"label": "Cat 2", "value": [2, "desc"]})
      ]

      initial_map = %{}

      result = update_filter_params(initial_map, %{"category" => json_list})

      assert result["filters"]["category"] == %{id: [1, 2]}
    end

    test "handles legacy live_select format with array strings" do
      # Legacy format: ["[1, \"desc\"]", "[2, \"desc\"]"]
      legacy_list = [~s([1, "desc"]), ~s([2, "desc"])]
      initial_map = %{}

      result = update_filter_params(initial_map, %{"category" => legacy_list})

      assert result["filters"]["category"] == %{id: [1, 2]}
    end

    test "removes select filter when list is empty strings" do
      # Cleared selection sends empty strings
      initial_map = %{"filters" => %{"category" => %{id: [1, 2]}}}

      result = update_filter_params(initial_map, %{"category" => ["", ""]})

      refute Map.has_key?(result["filters"], "category")
    end

    test "removes select filter when list is empty" do
      initial_map = %{"filters" => %{"category" => %{id: [1, 2]}}}

      result = update_filter_params(initial_map, %{"category" => []})

      refute Map.has_key?(result["filters"], "category")
    end
  end

  describe "update_filter_params/2 with transformer params" do
    test "adds transformer with custom data map" do
      initial_map = %{}
      custom_data = %{"min_value" => "500", "include_archived" => "true"}

      result = update_filter_params(initial_map, %{"high_value" => custom_data})

      assert result["filters"]["high_value"] == custom_data
    end

    test "updates existing transformer data" do
      initial_map = %{"filters" => %{"high_value" => %{"min_value" => "100"}}}
      new_data = %{"min_value" => "1000"}

      result = update_filter_params(initial_map, %{"high_value" => new_data})

      assert result["filters"]["high_value"] == new_data
    end
  end

  describe "update_filter_params/2 with non-filter params" do
    test "ignores params that don't match any filter" do
      initial_map = %{}

      result = update_filter_params(initial_map, %{"unknown_filter" => "value"})

      # Should have filters key but be empty or only contain valid filters
      assert result["filters"] == %{}
    end

    test "preserves non-filter params in the map" do
      initial_map = %{"page" => "2", "per_page" => "25"}

      result = update_filter_params(initial_map, %{"under_100" => "true"})

      assert result["page"] == "2"
      assert result["per_page"] == "25"
      assert result["filters"]["under_100"] == "under-100"
    end
  end

  describe "encode_filters/1" do
    test "encodes Boolean filter to URL params" do
      filter =
        Boolean.new(:price, "under-100", %{
          label: "Under $100",
          condition: dynamic([p], p.price < 100)
        })

      encoded = encode_filters(%{under_100: filter})

      assert encoded == %{"under_100" => "under-100"}
    end

    test "encodes Range filter with current min/max to URL params" do
      filter =
        Range.new(:price, "price_range", %{
          label: "Price Range",
          min: 0,
          max: 1000,
          current_min: 50,
          current_max: 200
        })

      encoded = encode_filters(%{price_range: filter})

      assert encoded == %{"price_range" => [min: 50, max: 200]}
    end

    test "encodes Select filter with selected ids to URL params" do
      filter =
        Select.new({:category, :id}, "category", %{
          label: "Category",
          selected: [1, 2, 3]
        })

      encoded = encode_filters(%{category: filter})

      assert encoded == %{"category" => %{id: [1, 2, 3]}}
    end

    test "encodes Transformer with applied_data to URL params" do
      filter =
        Transformer.new("high_value", %{
          query_transformer: fn q, _data -> q end,
          applied_data: %{"min_value" => "500", "type" => "premium"}
        })

      encoded = encode_filters(%{high_value: filter})

      assert encoded == %{"high_value" => %{"min_value" => "500", "type" => "premium"}}
    end

    test "skips Transformer with empty applied_data" do
      filter =
        Transformer.new("high_value", %{
          query_transformer: fn q, _data -> q end,
          applied_data: %{}
        })

      encoded = encode_filters(%{high_value: filter})

      # Empty applied_data should not be encoded
      assert encoded == %{}
    end

    test "encodes multiple mixed filter types" do
      filters = %{
        bool_filter:
          Boolean.new(:active, "is-active", %{
            label: "Active",
            condition: dynamic([p], p.active == true)
          }),
        range_filter:
          Range.new(:quantity, "qty_range", %{
            label: "Quantity",
            min: 0,
            max: 100,
            current_min: 10,
            current_max: 50
          }),
        select_filter:
          Select.new({:status, :id}, "status", %{
            label: "Status",
            selected: [1]
          })
      }

      encoded = encode_filters(filters)

      assert encoded["bool_filter"] == "is-active"
      assert encoded["range_filter"] == [min: 10, max: 50]
      assert encoded["select_filter"] == %{id: [1]}
    end

    test "handles empty filters map" do
      encoded = encode_filters(%{})

      assert encoded == %{}
    end

    test "skips filters without encodable state" do
      # Range without current_min/current_max won't encode properly
      # but this tests the fallback behavior
      filter =
        Transformer.new("empty", %{
          query_transformer: fn q, _data -> q end
          # No applied_data
        })

      encoded = encode_filters(%{empty: filter})

      # Should handle gracefully (transformer without applied_data is skipped)
      assert encoded == %{}
    end
  end

  describe "encode_filters/1 with string vs atom keys" do
    test "converts atom keys to string keys in output" do
      filter =
        Boolean.new(:price, "under-100", %{
          label: "Under $100",
          condition: dynamic([p], p.price < 100)
        })

      encoded = encode_filters(%{under_100: filter})

      # Keys should be strings for URL encoding
      assert Map.has_key?(encoded, "under_100")
      refute Map.has_key?(encoded, :under_100)
    end
  end
end
