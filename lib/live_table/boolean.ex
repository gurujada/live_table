defmodule LiveTable.Boolean do
  @moduledoc """
    A module for handling boolean (checkbox) filters in LiveTable.

    This module provides functionality for creating and managing boolean filters implemented
    as checkboxes in the LiveTable interface. It's designed to handle simple true/false and even complex
    filtering scenarios with customizable options and conditions.

    Similar to all filters in LiveTable, Boolean filters can be created using the `new/3` function,
    which takes the `key`, `field`, and an `options` map.
    The key will be used to reference the filter in the URL params.


  ### Options map
  The boolean filter accepts the following arguments in the options map:
  - `:label` - The text label displayed next to the checkbox
  - `:condition` - The Ecto query condition to be applied when the checkbox is checked (a dynamic query)
  - `:class` - Optional CSS classes for the checkbox

  ## Examples
  ```elixir
  # Creating a basic boolean filter for active status
  Boolean.new(:active, "active_filter", %{
    label: "Show Active Only",
    condition: dynamic([p], p.active == true)
  })

  # Creating a boolean filter with a complex condition
  Boolean.new(:premium, "premium_filter", %{
    label: "Premium Users",
    condition: dynamic([p], p.subscription_level == "premium" and p.active == true)
  })

  # Creating a boolean filter for any toggleable condition
  Boolean.new(:premium, "premium_filter", %{
    label: "Greater than 50$",
    condition: dynamic([p], p.price > 50)
  })
  ```
  Since the condition is a dynamic query, a condition using joined fields can be given.
  ```elixir
  Boolean.new(
    :supplier_email,
    "supplier",
    %{
      label: "Email",
      condition: dynamic([p, s], s.contact_info == "procurement@autopartsdirect.com")
    }
  )
  ```
  > **Note**: Remember to use aliases in the same order in which they were defined in `fields()`.


  If an associated field is not defined in the `fields()` function, and a boolean filter needs to be applied,
  a tuple containing `{:table_name, field}` can be passed as the field and can be
  aliased using the `table_name` in `dynamic`

  ```elixir
  Boolean.new(
    {:suppliers, :email},
    "supplier",
    %{
      label: "Email",
      condition: dynamic([p, s], s.contact_info == "procurement@autopartsdirect.com")
    }
  )
  ```

  """

  import Ecto.Query
  use Phoenix.Component
  import SutraUI.Checkbox, only: [checkbox: 1]
  import SutraUI.Label, only: [label: 1]

  defstruct [:field, :key, :options]

  @doc false
  def new(field, key, options) do
    %__MODULE__{field: field, key: key, options: options}
  end

  @doc false
  def apply(acc, %__MODULE__{options: %{condition: condition}}) do
    dynamic(^acc and ^condition)
  end

  @doc false
  def render(assigns) do
    ~H"""
    <div class="flex items-center gap-2">
      <input type="hidden" name={"filters[#{@key}]"} value="false" />
      <.checkbox
        id={"filters-#{@key}"}
        name={"filters[#{@key}]"}
        checked={Map.has_key?(@applied_filters, @key) || Map.get(@filter.options, :default)}
        class={Map.get(@filter.options, :class, "")}
      />
      <.label for={"filters-#{@key}"}>
        {@filter.options.label}
      </.label>
    </div>
    """
  end
end
