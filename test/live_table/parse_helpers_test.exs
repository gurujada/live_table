defmodule LiveTable.ParseHelpersTest do
  use ExUnit.Case, async: true

  alias LiveTable.ParseHelpers
  alias LiveTable.{Boolean, Range, Select, Transformer}

  import Ecto.Query

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
        }),
      boolean_with_default:
        Boolean.new(:featured, "featured", %{
          label: "Featured",
          condition: dynamic([p], p.featured == true),
          default: true
        })
    ]
  end

  describe "parse_sort_params/2" do
    test "parses sort params with string keys" do
      params = %{"sort_params" => %{"name" => "asc", "price" => "desc"}}
      default = [id: :asc]

      result = ParseHelpers.parse_sort_params(params, default)

      assert result == [name: :asc, price: :desc]
    end

    test "parses sort params with atom keys" do
      params = %{"sort_params" => [name: :asc, price: :desc]}
      default = [id: :asc]

      result = ParseHelpers.parse_sort_params(params, default)

      assert result == [name: :asc, price: :desc]
    end

    test "uses default when no sort params" do
      params = %{}
      default = [name: :asc]

      result = ParseHelpers.parse_sort_params(params, default)

      assert result == [name: :asc]
    end
  end

  describe "parse_filters/3" do
    test "parses empty filters" do
      params = %{"filters" => %{}}
      socket = %{assigns: %{options: %{}}}

      result = ParseHelpers.parse_filters(params, socket, filters())

      assert result["search"] == ""
    end

    test "parses search term" do
      params = %{"filters" => %{}, "search" => "laptop"}
      socket = %{assigns: %{options: %{}}}

      result = ParseHelpers.parse_filters(params, socket, filters())

      assert result["search"] == "laptop"
    end

    test "applies default filters on initial load" do
      params = %{"filters" => %{}}
      socket = %{assigns: %{}}

      result = ParseHelpers.parse_filters(params, socket, filters())

      assert result[:boolean_with_default] != nil
      assert result[:under_100] == nil
    end

    test "does not apply defaults when filters already present" do
      params = %{"filters" => %{"under_100" => "true"}}
      socket = %{assigns: %{options: %{}}}

      result = ParseHelpers.parse_filters(params, socket, filters())

      assert result[:boolean_with_default] == nil
    end

    test "flattens nested select values from structured live_select payload" do
      params = %{"filters" => %{"category" => %{"id" => [["1"], ["2"]]}}}
      socket = %{assigns: %{options: %{}}}

      result = ParseHelpers.parse_filters(params, socket, filters())

      assert result[:category].options.selected == [1, 2, 1, 2]
    end

    test "drops blank select values from structured live_select payload" do
      params = %{"filters" => %{"category" => %{"id" => ["", ["3"]]}}}
      socket = %{assigns: %{options: %{}}}

      result = ParseHelpers.parse_filters(params, socket, filters())

      assert result[:category].options.selected == [1, 2, 3]
    end

    test "preserves nested string select values for name-based filters" do
      custom_filters = [stage: Select.new({:stage, :name}, "stage", %{selected: []})]
      params = %{"filters" => %{"stage" => %{"id" => [["migration"]]}}}
      socket = %{assigns: %{options: %{}}}

      result = ParseHelpers.parse_filters(params, socket, custom_filters)

      assert result[:stage].options.selected == ["migration"]
    end

    test "keeps structured single select values as strings" do
      custom_filters = [
        seat_type: Select.new({:rank_cutoff, :seat_type}, "seat_type_select", %{selected: []})
      ]

      params = %{"filters" => %{"seat_type" => %{"id" => ["open"]}}}
      socket = %{assigns: %{options: %{}}}

      result = ParseHelpers.parse_filters(params, socket, custom_filters)

      assert result[:seat_type].options.selected == ["open"]
    end

    test "parses integer range filter values" do
      params = %{"filters" => %{"price_range" => %{"min" => "50", "max" => "200"}}}
      socket = %{assigns: %{options: %{}}}

      result = ParseHelpers.parse_filters(params, socket, filters())

      assert result[:price_range].options.current_min == 50
      assert result[:price_range].options.current_max == 200
    end

    test "parses float range filter values" do
      custom_filters = [
        rating:
          Range.new(:rating, "rating", %{
            step: 0.5,
            current_min: nil,
            current_max: nil
          })
      ]

      params = %{"filters" => %{"rating" => %{"min" => "10.5", "max" => "50.5"}}}
      socket = %{assigns: %{options: %{}}}

      result = ParseHelpers.parse_filters(params, socket, custom_filters)

      assert result[:rating].options.current_min == 10.5
      assert result[:rating].options.current_max == 50.5
    end
  end

  describe "get_filter/2" do
    test "retrieves filter by atom key" do
      result = ParseHelpers.get_filter(:under_100, filters())

      assert %Boolean{} = result
      assert result.key == "under-100"
    end

    test "retrieves filter by string key" do
      result = ParseHelpers.get_filter("under_100", filters())

      assert %Boolean{} = result
      assert result.key == "under-100"
    end

    test "returns nil for non-existent key" do
      result = ParseHelpers.get_filter(:nonexistent, filters())

      assert result == nil
    end

    test "retrieves Range filter" do
      result = ParseHelpers.get_filter(:price_range, filters())

      assert %Range{} = result
      assert result.field == :price
    end

    test "retrieves Select filter" do
      result = ParseHelpers.get_filter(:category, filters())

      assert %Select{} = result
      assert result.field == {:category, :id}
    end

    test "retrieves Transformer filter" do
      result = ParseHelpers.get_filter(:high_value, filters())

      assert %Transformer{} = result
      assert result.key == "high_value"
    end
  end

  describe "coerce_select_value/1" do
    test "coerces integer string to integer" do
      assert ParseHelpers.coerce_select_value("42") == 42
    end

    test "keeps non-integer string as string" do
      assert ParseHelpers.coerce_select_value("hello") == "hello"
    end

    test "passes through integer" do
      assert ParseHelpers.coerce_select_value(42) == 42
    end
  end

  describe "build_options/4" do
    test "builds complete options map" do
      sort_params = [name: :asc]
      filters = %{price: %Range{}}
      params = %{"page" => "2", "per_page" => "25"}

      table_options = %{
        sorting: %{enabled: true},
        pagination: %{enabled: true, default_size: 10, max_per_page: 50}
      }

      result = ParseHelpers.build_options(sort_params, filters, params, table_options)

      assert result["sort"]["sortable?"] == true
      assert result["sort"]["sort_params"] == [name: :asc]
      assert result["pagination"]["paginate?"] == true
      assert result["pagination"]["page"] == "2"
      assert result["pagination"]["per_page"] == "25"
      assert result["filters"] == filters
    end

    test "defaults invalid pagination params through options building" do
      table_options = %{
        sorting: %{enabled: true},
        pagination: %{enabled: true, default_size: 25, max_per_page: 50}
      }

      result =
        ParseHelpers.build_options(
          [],
          %{},
          %{"page" => "abc", "per_page" => "100"},
          table_options
        )

      assert result["pagination"]["page"] == "1"
      assert result["pagination"]["per_page"] == "50"
    end

    test "defaults nil pagination params through options building" do
      table_options = %{
        sorting: %{enabled: true},
        pagination: %{enabled: true, default_size: 25, max_per_page: 50}
      }

      result = ParseHelpers.build_options([], %{}, %{}, table_options)

      assert result["pagination"]["page"] == "1"
      assert result["pagination"]["per_page"] == "25"
    end

    test "keeps valid non-default pagination params through options building" do
      table_options = %{
        sorting: %{enabled: true},
        pagination: %{enabled: true, default_size: 10, max_per_page: 100}
      }

      result =
        ParseHelpers.build_options(
          [],
          %{},
          %{"page" => "5", "per_page" => "50"},
          table_options
        )

      assert result["pagination"]["page"] == "5"
      assert result["pagination"]["per_page"] == "50"
    end
  end
end
