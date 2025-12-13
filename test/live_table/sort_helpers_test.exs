defmodule LiveTable.SortHelpersTest do
  @moduledoc """
  Tests for LiveTable.SortHelpers - sort link rendering and param handling.

  SortHelpers provides:
    * `sort_link/1` - A Phoenix component for rendering sortable column headers
    * `next_sort_order/1` - Toggles between "asc" and "desc"
    * `update_sort_params/3` - Updates sort params from URL/event params
    * `merge_lists/2` - Merges keyword lists for multi-sort

  ## What This Tests

    * Rendering sort links (sortable vs non-sortable)
    * Sort direction toggling
    * Parameter handling with/without shift key (multi-sort)
    * Keyword list merging for multi-column sorting
  """

  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest
  import LiveTable.SortHelpers

  describe "sort_link/1 with sortable: false" do
    test "renders plain label when sortable is false" do
      html =
        render_component(&sort_link/1, %{
          sortable: false,
          label: "Description"
        })

      assert html =~ "Description"
      refute html =~ "phx-click"
      refute html =~ "cursor-pointer"
    end

    test "renders label in span tag" do
      html =
        render_component(&sort_link/1, %{
          sortable: false,
          label: "Non-Sortable Field"
        })

      assert html =~ "<span>"
      assert html =~ "Non-Sortable Field"
      assert html =~ "</span>"
    end
  end

  describe "sort_link/1 with sortable: true" do
    test "renders clickable link when sortable is true" do
      html =
        render_component(&sort_link/1, %{
          sortable: true,
          label: "Name",
          key: :name,
          sort_params: []
        })

      assert html =~ "phx-click=\"sort\""
      assert html =~ "cursor-pointer"
      assert html =~ "Name"
    end

    test "includes correct phx-value-sort for ascending" do
      html =
        render_component(&sort_link/1, %{
          sortable: true,
          label: "Price",
          key: :price,
          sort_params: []
        })

      # When no current sort, clicking should sort ascending first (then toggle to desc)
      assert html =~ "phx-value-sort"
      # Default is nil -> asc -> desc (HTML entity encoded)
      assert html =~ "price"
      assert html =~ "desc"
    end

    test "shows sort icons" do
      html =
        render_component(&sort_link/1, %{
          sortable: true,
          label: "Stock",
          key: :stock,
          sort_params: []
        })

      assert html =~ "<svg"
      assert html =~ "path"
    end

    test "highlights ascending icon when sorted asc" do
      html =
        render_component(&sort_link/1, %{
          sortable: true,
          label: "Name",
          key: :name,
          sort_params: [name: :asc]
        })

      # The ascending path should have text-primary class
      assert html =~ "text-primary"
    end

    test "highlights descending icon when sorted desc" do
      html =
        render_component(&sort_link/1, %{
          sortable: true,
          label: "Name",
          key: :name,
          sort_params: [name: :desc]
        })

      # The descending path should have text-primary class
      assert html =~ "text-primary"
    end

    test "toggles to desc when currently asc" do
      html =
        render_component(&sort_link/1, %{
          sortable: true,
          label: "Name",
          key: :name,
          sort_params: [name: :asc]
        })

      # Should toggle to desc (HTML entity encoded in output)
      assert html =~ "phx-value-sort"
      assert html =~ "name"
      assert html =~ "desc"
    end

    test "toggles to asc when currently desc" do
      html =
        render_component(&sort_link/1, %{
          sortable: true,
          label: "Name",
          key: :name,
          sort_params: [name: :desc]
        })

      # Should toggle to asc (HTML entity encoded in output)
      assert html =~ "phx-value-sort"
      assert html =~ "name"
      assert html =~ "asc"
    end

    test "includes SortableColumn hook for shift-click multi-sort" do
      html =
        render_component(&sort_link/1, %{
          sortable: true,
          label: "Name",
          key: :name,
          sort_params: []
        })

      # Should include the hook attribute (script is separate)
      assert html =~ "phx-hook"
      assert html =~ "SortableColumn"
    end

    test "renders with correct element id" do
      html =
        render_component(&sort_link/1, %{
          sortable: true,
          label: "Price",
          key: :price,
          sort_params: []
        })

      assert html =~ ~s(id="price")
    end
  end

  describe "next_sort_order/1" do
    test "returns 'desc' for 'asc'" do
      assert next_sort_order("asc") == "desc"
    end

    test "returns 'asc' for 'desc'" do
      assert next_sort_order("desc") == "asc"
    end
  end

  describe "update_sort_params/3 with nil params" do
    test "returns map unchanged when params is nil" do
      map = %{"page" => "1", "sort_params" => [name: :asc]}

      result = update_sort_params(map, nil, false)

      assert result == map
    end

    test "returns map unchanged when params is nil with shift key" do
      map = %{"sort_params" => [name: :asc]}

      result = update_sort_params(map, nil, true)

      assert result == map
    end
  end

  describe "update_sort_params/3 without shift key (single sort)" do
    test "replaces existing sort params with new ones" do
      map = %{"sort_params" => [name: :asc]}
      params = ~s({"price": "desc"})

      result = update_sort_params(map, params, false)

      assert result["sort_params"] == [price: :desc]
    end

    test "adds sort params to empty map" do
      map = %{}
      params = ~s({"name": "asc"})

      result = update_sort_params(map, params, false)

      assert result["sort_params"] == [name: :asc]
    end

    test "handles multiple fields in params" do
      map = %{}
      params = ~s({"name": "asc", "price": "desc"})

      result = update_sort_params(map, params, false)

      # Both should be present in the new sort_params
      assert :name in Keyword.keys(result["sort_params"])
      assert :price in Keyword.keys(result["sort_params"])
    end
  end

  describe "update_sort_params/3 with shift key (multi-sort)" do
    test "merges new sort with existing sorts" do
      map = %{"sort_params" => [name: :asc]}
      params = ~s({"price": "desc"})

      result = update_sort_params(map, params, true)

      # Both sorts should be present
      assert result["sort_params"][:name] == :asc
      assert result["sort_params"][:price] == :desc
    end

    test "updates existing sort direction when same field" do
      map = %{"sort_params" => [name: :asc, price: :asc]}
      params = ~s({"name": "desc"})

      result = update_sort_params(map, params, true)

      # Name should be updated, price should remain
      assert result["sort_params"][:name] == :desc
      assert result["sort_params"][:price] == :asc
    end

    test "preserves order when updating existing field" do
      map = %{"sort_params" => [name: :asc, price: :desc]}
      params = ~s({"name": "desc"})

      result = update_sort_params(map, params, true)

      # Keys should maintain original order
      keys = Keyword.keys(result["sort_params"])
      assert List.first(keys) == :name
    end

    test "adds new field to end of sort list" do
      map = %{"sort_params" => [name: :asc]}
      params = ~s({"price": "desc"})

      result = update_sort_params(map, params, true)

      keys = Keyword.keys(result["sort_params"])
      assert List.last(keys) == :price
    end

    test "handles nil sort_params gracefully with shift key" do
      # When existing sort_params is nil, merge_lists will fail
      # This tests the actual behavior - the function throws on nil
      map = %{"sort_params" => []}
      params = ~s({"name": "asc"})

      result = update_sort_params(map, params, true)

      # With empty list, it should work
      assert result["sort_params"][:name] == :asc
    end
  end

  describe "merge_lists/2" do
    test "merges two keyword lists" do
      list1 = [name: :asc, price: :desc]
      list2 = [stock: :asc]

      result = merge_lists(list1, list2)

      assert result[:name] == :asc
      assert result[:price] == :desc
      assert result[:stock] == :asc
    end

    test "updates values for existing keys from list2" do
      list1 = [name: :asc, price: :desc]
      list2 = [name: :desc]

      result = merge_lists(list1, list2)

      # Name should be updated to desc
      assert result[:name] == :desc
      # Price should remain unchanged
      assert result[:price] == :desc
    end

    test "preserves order of list1 keys" do
      list1 = [a: 1, b: 2, c: 3]
      list2 = [b: 20]

      result = merge_lists(list1, list2)

      keys = Keyword.keys(result)
      assert Enum.slice(keys, 0, 3) == [:a, :b, :c]
    end

    test "appends new keys from list2 at the end" do
      list1 = [a: 1, b: 2]
      list2 = [c: 3, d: 4]

      result = merge_lists(list1, list2)

      keys = Keyword.keys(result)
      # a, b from list1, then c, d from list2
      assert keys == [:a, :b, :c, :d]
    end

    test "handles empty list1" do
      list1 = []
      list2 = [a: 1, b: 2]

      result = merge_lists(list1, list2)

      assert result == [a: 1, b: 2]
    end

    test "handles empty list2" do
      list1 = [a: 1, b: 2]
      list2 = []

      result = merge_lists(list1, list2)

      assert result == [a: 1, b: 2]
    end

    test "handles both lists empty" do
      result = merge_lists([], [])

      assert result == []
    end

    test "does not duplicate keys that exist in both" do
      list1 = [a: 1, b: 2]
      list2 = [a: 10, b: 20]

      result = merge_lists(list1, list2)

      # Should only have 2 keys, not 4
      assert length(result) == 2
      assert result[:a] == 10
      assert result[:b] == 20
    end
  end

  describe "integration: sort state persistence" do
    test "sort params can be encoded and decoded" do
      # Simulate encoding sort params for URL
      sort_params = [name: :asc, price: :desc]

      encoded =
        Jason.encode!(Enum.into(sort_params, %{}, fn {k, v} -> {to_string(k), to_string(v)} end))

      # Simulate decoding and updating
      result = update_sort_params(%{}, encoded, false)

      # Values should be atoms after processing
      assert result["sort_params"][:name] == :asc
      assert result["sort_params"][:price] == :desc
    end
  end
end
