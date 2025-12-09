defmodule LiveTable.RangeTest do
  use LiveTable.DataCase
  alias LiveTable.Range
  import Phoenix.LiveViewTest

  describe "new/3" do
    test "creates a range filter with default options" do
      range = Range.new(:price, "price_range", %{})

      assert range.field == :price
      assert range.key == "price_range"
      assert range.options.label == "Range"
      assert range.options.min == 0
      assert range.options.max == 100
      assert range.options.step == 1
      assert range.options.default_min == 0
      assert range.options.default_max == 100
    end

    test "creates a range filter with custom options" do
      options = %{
        label: "Price Range",
        unit: "$",
        min: 10,
        max: 1000,
        step: 5,
        default_min: 50,
        default_max: 500
      }

      range = Range.new(:price, "price_range", options)

      assert range.options.label == "Price Range"
      assert range.options.unit == "$"
      assert range.options.min == 10
      assert range.options.max == 1000
      assert range.options.step == 5
      assert range.options.default_min == 50
      assert range.options.default_max == 500
    end

    test "creates a range filter with float step" do
      options = %{
        min: 0.0,
        max: 5.0,
        step: 0.5,
        default_min: 1.0,
        default_max: 4.5
      }

      range = Range.new(:rating, "rating_range", options)

      assert range.options.min == 0.0
      assert range.options.max == 5.0
      assert range.options.step == 0.5
    end

    test "creates a range filter with joined field" do
      options = %{
        label: "Supplier Price"
      }

      range = Range.new({:suppliers, :price}, "supplier_price", options)

      assert range.field == {:suppliers, :price}
      assert range.key == "supplier_price"
    end

    test "preserves custom CSS classes" do
      options = %{
        css_classes: "custom-container",
        slider_classes: "custom-slider",
        label_classes: "custom-label"
      }

      range = Range.new(:value, "value_range", options)

      assert range.options.css_classes == "custom-container"
      assert range.options.slider_classes == "custom-slider"
      assert range.options.label_classes == "custom-label"
    end

    test "sets slider options correctly" do
      options = %{
        slider_options: %{
          tooltips: false
        }
      }

      range = Range.new(:value, "value_range", options)

      assert range.options.slider_options.tooltips == false
    end
  end

  describe "apply/2" do
    test "applies range filter for simple field" do
      range =
        Range.new(:price, "price_range", %{
          current_min: 10,
          current_max: 100
        })

      acc = true
      dynamic = Range.apply(acc, range)

      # Create a query to test the dynamic
      query = from(p in "products", select: %{id: p.id, price: p.price}, where: ^dynamic)
      {sql, params} = Ecto.Adapters.SQL.to_sql(:all, Repo, query)

      assert sql =~ "BETWEEN"
      assert params == [true, 10, 100]
    end

    test "applies range filter for joined field" do
      range =
        Range.new({:suppliers, :price}, "supplier_price", %{
          current_min: 20,
          current_max: 200
        })

      acc = true
      dynamic = Range.apply(acc, range)

      # The dynamic should reference the suppliers table
      query =
        from(p in "products",
          join: s in "suppliers",
          as: :suppliers,
          on: p.supplier_id == s.id,
          select: %{id: p.id, supplier_price: s.price},
          where: ^dynamic
        )

      {sql, _params} = Ecto.Adapters.SQL.to_sql(:all, Repo, query)

      assert sql =~ "BETWEEN"
      # suppliers table alias
      assert sql =~ "s1"
    end

    test "uses default values when current values not set" do
      range =
        Range.new(:price, "price_range", %{
          default_min: 5,
          default_max: 50
        })

      acc = true
      dynamic = Range.apply(acc, range)

      query = from(p in "products", select: %{id: p.id, price: p.price}, where: ^dynamic)
      {_sql, params} = Ecto.Adapters.SQL.to_sql(:all, Repo, query)

      assert params == [true, 5, 50]
    end

    test "handles float values correctly" do
      range =
        Range.new(:rating, "rating_range", %{
          current_min: 2.5,
          current_max: 4.5
        })

      acc = true
      dynamic = Range.apply(acc, range)

      query = from(p in "products", select: %{id: p.id, rating: p.rating}, where: ^dynamic)
      {_sql, params} = Ecto.Adapters.SQL.to_sql(:all, Repo, query)

      assert params == [true, 2.5, 4.5]
    end
  end

  describe "render/1" do
    test "renders range slider with default options" do
      range = Range.new(:price, "price_range", %{})

      html =
        render_component(&Range.render/1, %{
          filter: range,
          key: "price_range",
          applied_filters: %{}
        })

      assert html =~ "Range"
      assert html =~ ~s(id="range_filter[price_range]")
      assert html =~ ~s(name="price_range")
    end

    test "renders range slider with unit" do
      range =
        Range.new(:price, "price_range", %{
          label: "Price",
          unit: "$"
        })

      html =
        render_component(&Range.render/1, %{
          filter: range,
          key: "price_range",
          applied_filters: %{}
        })

      assert html =~ "Price"
      assert html =~ "($)"
    end

    test "renders with current values from applied filters" do
      range =
        Range.new(:price, "price_range", %{
          current_min: 25,
          current_max: 75
        })

      applied_filters = %{
        "price_range" => %{
          options: %{current_min: 30, current_max: 70}
        }
      }

      html =
        render_component(&Range.render/1, %{
          filter: range,
          key: "price_range",
          applied_filters: applied_filters
        })

      # The component should use the applied filter values
      assert html =~ "price_range"
    end

    test "renders with custom CSS classes" do
      range =
        Range.new(:value, "value_range", %{
          css_classes: "custom-container",
          slider_classes: "custom-slider",
          label_classes: "custom-label"
        })

      html =
        render_component(&Range.render/1, %{
          filter: range,
          key: "value_range",
          applied_filters: %{}
        })

      assert html =~ "custom-container"
      assert html =~ "custom-slider"
      assert html =~ "custom-label"
    end

    test "renders with pips configuration" do
      range =
        Range.new(:value, "value_range", %{
          pips: true,
          pips_mode: "positions",
          pips_values: [0, 50, 100]
        })

      html =
        render_component(&Range.render/1, %{
          filter: range,
          key: "value_range",
          applied_filters: %{}
        })

      # Should render without errors with pips config
      assert html =~ ~s(id="range_filter[value_range]")
    end
  end

  describe "edge cases and error handling" do
    test "handles nil current values gracefully" do
      range =
        Range.new(:price, "price_range", %{
          current_min: nil,
          current_max: nil,
          default_min: 0,
          default_max: 100
        })

      acc = true
      dynamic = Range.apply(acc, range)

      query = from(p in "products", select: %{id: p.id, price: p.price}, where: ^dynamic)
      {_sql, params} = Ecto.Adapters.SQL.to_sql(:all, Repo, query)

      # Should fall back to default values
      assert params == [true, 0, 100]
    end

    test "handles empty applied filters map" do
      range = Range.new(:price, "price_range", %{})

      html =
        render_component(&Range.render/1, %{
          filter: range,
          key: "price_range",
          applied_filters: %{}
        })

      # Should render without errors
      assert html =~ ~s(id="range_filter[price_range]")
    end

    test "deep merges options correctly" do
      options = %{
        slider_options: %{
          tooltips: false
        }
      }

      range = Range.new(:value, "value_range", options)

      # Should override specified options
      assert range.options.slider_options.tooltips == false
    end
  end
end
