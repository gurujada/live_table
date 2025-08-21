defmodule LiveTable.Range do
  @moduledoc """
  A module for handling range-based filters in LiveTable.

  This module provides functionality for creating and managing range filters that can handle
  numeric values, dates, and datetimes. It supports creating range sliders with customizable
  options and appearances.

  Makes use of nouislider under the hood for creating the range slider.
  See the [noUiSlider documentation](https://refreshless.com/nouislider/) for more details
  on customizing the slider behavior and appearance.

  > **Note**: Requires the TableHooks to be imported in your app.js

  ## Options
  The module accepts the following options:
  - `:type` - The type of range filter (`:number`, `:date`, or `:datetime`)
  - `:label` - The label text for the range filter
  - `:unit` - The unit to display after the label (optional)
  - `:css_classes` - CSS classes for the main container
  - `:slider_classes` - CSS classes for the slider element
  - `:label_classes` - CSS classes for the label element

  For default values, see: [LiveTable.Range source code](https://github.com/gurujada/live_table/blob/master/lib/live_table/range.ex)

  ## Types Support
  The module supports three types of range filters:
  - `:number` - For numeric ranges
  - `:date` - For date ranges
  - `:datetime` - For datetime ranges


  ### :number
  For numeric ranges with configurable min, max and step values:

  ```elixir
  Range.new(:price, "price_range", %{
    type: :number,
    label: "Price",
    default_min: 0,
    default_max: 1000,
    step: 10
  })
  # Renders a range filter with from 0 to 1000 with a step of 10.
  ```

  ### :date
  For date ranges with customizable date boundaries:

  ```elixir
  Range.new(:created_at, "date_range", %{
    type: :date,
    label: "Creation Date",
    default_min: ~D[2024-01-01],
    default_max: ~D[2024-12-31]
  })
  # Renders a date range filter with dates from 2024-01-01 to 2024-12-31.
  ```

  ### :datetime
  For datetime ranges with configurable datetime boundaries:

  ```elixir
  Range.new(:updated_at, "datetime_range", %{
    type: :datetime,
    label: "Last Updated",
    default_min: ~N[2024-01-01 00:00:00],
    default_max: ~N[2024-12-31 23:59:59],
    step: 3600 # Step in seconds
  })
  # Renders a datetime range filter with dates from 2024-01-01 00:00:00 to 2024-12-31 23:59:59.
  # Remember to pass the datetime values in `NaiveDateTime` format.
  ```

  ## Examples

  ```elixir
  # Creating a numeric range filter
  Range.new(:price, "price_range", %{
    type: :number,
    label: "Price Range",
    unit: "$",
    min: 0,
    max: 1000,
    step: 10
  })

  # Creating a date range filter
  Range.new(:created_at, "date_range", %{
    type: :date,
    label: "Date Range",
    min: ~D[2024-01-01],
    max: ~D[2024-12-31]
  })
  ```
  If you want to use the range filter with a joined schema, you can pass the field as a tuple, with the table name and the field-
  ```elixir
  Range.new({:suppliers, :created_at}, "created_at", %{
    type: :date,
    label: "Supplier Creation",
    min: ~D[2024-01-01],
    max: ~D[2024-12-31],
  })
  ```
  """

  import Ecto.Query
  use Phoenix.Component
  import LiveTable.TableConfig, only: [deep_merge: 2]

  defstruct [:field, :key, :options]

  @today Date.utc_today()
  @now NaiveDateTime.utc_now()
  @type_defaults %{
    number: %{
      min: 0,
      max: 100,
      step: 1,
      default_min: 0,
      default_max: 100,
      current_min: nil,
      current_max: nil,
      pips_mode: "positions",
      pips_values: [0, 25, 50, 75, 100],
      pips_density: 4,
      pips_stepped: true
    },
    date: %{
      min: Date.add(@today, -1),
      max: Date.add(@today, 1),
      step: 1,
      default_min: Date.add(@today, -1),
      default_max: Date.add(@today, 1),
      current_min: nil,
      current_max: nil,
      pips_mode: "count",
      # weekly markers
      pips_density: 3,
      pips_stepped: true,
      pips_values: [Date.add(@today, -7), Date.add(@today, 0), Date.add(@today, 7)]
    },
    datetime: %{
      min: NaiveDateTime.add(@now, -24 * 3600),
      max: NaiveDateTime.add(@now, 24 * 3600),
      default_min: NaiveDateTime.add(@now, -24 * 3600),
      default_max: NaiveDateTime.add(@now, 24 * 3600),
      current_min: nil,
      current_max: nil,
      step: 3600,
      pips_mode: "count",
      # hourly markers
      pips_density: 2,
      pips_stepped: true,
      pips_values: [
        NaiveDateTime.add(@now, -3600),
        NaiveDateTime.add(@now, 0),
        NaiveDateTime.add(@now, 3600)
      ]
    }
  }

  @default_options %{
    type: :number,
    label: "Range",
    pips: false,
    unit: "",
    css_classes: "",
    slider_classes: "w-full h-2 mt-6 mb-8",
    label_classes: "block text-sm font-medium leading-6 text-gray-900 dark:text-gray-100",
    event_type: "change",
    slider_options: %{
      tooltips: true,
      padding: 0,
      behaviour: "drag"
    }
  }

  @doc false
  def new(field, key, options) do
    type = Map.get(options, :type, :number)
    type_defaults = Map.get(@type_defaults, type)

    complete_options =
      @default_options
      |> deep_merge(type_defaults)
      |> deep_merge(options)
      |> Map.put(:type, type)

    %__MODULE__{field: field, key: key, options: complete_options}
  end

  @doc false
  def apply(acc, %__MODULE__{field: {table, field}, options: %{type: :number} = options}) do
    {min_value, max_value} = get_min_max(options)

    dynamic(
      [{^table, t}],
      ^acc and fragment("? BETWEEN ? AND ?", field(t, ^field), ^min_value, ^max_value)
    )
  end

  @doc false
  def apply(acc, %__MODULE__{field: field, options: %{type: :number} = options})
      when is_atom(field) do
    {min_value, max_value} = get_min_max(options)
    dynamic([p], ^acc and fragment("? BETWEEN ? AND ?", field(p, ^field), ^min_value, ^max_value))
  end

  @doc false
  def apply(acc, %__MODULE__{field: {table, field}, options: %{type: :date} = options}) do
    {min_value, max_value} = get_min_max(options)

    dynamic(
      [{^table, t}],
      ^acc and
        fragment(
          "? BETWEEN ? AND ?",
          fragment("DATE(?)", field(t, ^field)),
          type(^min_value, :date),
          type(^max_value, :date)
        )
    )
  end

  @doc false
  def apply(acc, %__MODULE__{field: field, options: %{type: :date} = options}) do
    {min_value, max_value} = get_min_max(options)

    dynamic(
      [p],
      ^acc and
        fragment(
          "? BETWEEN ? AND ?",
          fragment("DATE(?)", field(p, ^field)),
          type(^min_value, :date),
          type(^max_value, :date)
        )
    )
  end

  @doc false
  def apply(acc, %__MODULE__{field: {table, field}, options: %{type: :datetime} = options}) do
    {min_value, max_value} = get_min_max(options)

    dynamic(
      [{^table, t}],
      ^acc and fragment("? BETWEEN ? AND ?", field(t, ^field), ^min_value, ^max_value)
    )
  end

  @doc false
  def apply(acc, %__MODULE__{field: field, options: %{type: :datetime} = options}) do
    {min_value, max_value} = get_min_max(options)
    dynamic([p], ^acc and fragment("? BETWEEN ? AND ?", field(p, ^field), ^min_value, ^max_value))
  end

  defp format_value(:number, value), do: value
  defp format_value(:date, nil), do: nil
  defp format_value(:date, value), do: Date.to_iso8601(value)

  defp format_value(:datetime, nil), do: nil

  defp format_value(:datetime, value) do
    value
    |> NaiveDateTime.to_iso8601()
    |> String.replace(" ", "T")
  end

  @doc false
  def render(assigns) do
    {current_min, current_max} = get_current_min_max(assigns.applied_filters, assigns.key)
    assigns = Map.put(assigns, :current_min, current_min) |> Map.put(:current_max, current_max)

    ~H"""
    <div class={@filter.options.css_classes}>
      <label :if={@filter.options.label} class={@filter.options.label_classes}>
        {@filter.options.label}
        <span :if={@filter.options.unit != ""} class="text-gray-500 dark:text-gray-400">
          ({@filter.options.unit})
        </span>
      </label>
      <div class="mt-3">
        <div
          id={"range_filter[#{@key}]"}
          phx-hook="RangeSlider"
          phx-update="ignore"
          data-key={@key}
          data-type={@filter.options.type}
          data-min={format_value(@filter.options.type, @filter.options.min)}
          data-max={format_value(@filter.options.type, @filter.options.max)}
          data-default-min={format_value(@filter.options.type, @filter.options.default_min)}
          data-default-max={format_value(@filter.options.type, @filter.options.default_max)}
          data-current-min={format_value(@filter.options.type, @current_min)}
          data-current-max={format_value(@filter.options.type, @current_max)}
          data-event-type={@filter.options.event_type}
          data-pips={Jason.encode!(@filter.options.pips)}
          data-pips-mode={@filter.options.pips_mode}
          data-pips-values={Jason.encode!(@filter.options.pips_values)}
          data-pips-density={@filter.options.pips_density}
          data-pips-stepped={if @filter.options.pips_stepped, do: "true", else: "false"}
          data-step={@filter.options.step}
          data-tooltips={Jason.encode!(@filter.options.slider_options.tooltips)}
          data-padding={Jason.encode!(@filter.options.slider_options.padding)}
          class={@filter.options.slider_classes}
        >
          <div id={"slider[#{@key}]"} class="slider-target"></div>
        </div>
      </div>
    </div>
    """
  end

  defp get_current_min_max(applied_filters, key) do
    case Map.get(applied_filters, key) do
      nil -> {nil, nil}
      %{options: %{current_min: min, current_max: max}} -> {min, max}
    end
  end

  defp get_min_max(options) do
    min = Map.get(options, :current_min) || Map.get(options, :default_min)
    max = Map.get(options, :current_max) || Map.get(options, :default_max)
    {min, max}
  end
end
