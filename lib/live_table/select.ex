defmodule LiveTable.Select do
  @moduledoc """
    A module for handling select-based filters in LiveTable.

    This module provides functionality for creating and managing select filters that can handle
    single or multiple selections. It supports both static options and dynamic option loading,
    with customizable appearances and templates.


  ## Options

    The module accepts the following options:
    - `:label` - The label text for the select filter
    - `:options` - Static list of options for the select
    - `:options_source` - Function or module for dynamic option loading
    - `:option_template` - Custom template for rendering options
    - `:selected` - List of pre-selected values
    - `:placeholder` - Placeholder text for the select
    - `:css_classes` - CSS classes for the main container
    - `:label_classes` - CSS classes for the label element

    ### LiveSelect Options

    These options are passed directly to the underlying `SutraUI.LiveSelect` component:

    - `:mode` - Selection mode (default: `:tags`)
      - `:single` - Select one option, input shows selected label
      - `:tags` - Multi-select with tag pills, dropdown closes after each selection
      - `:quick_tags` - Multi-select with tag pills, dropdown stays open for rapid selection
    - `:allow_clear` - Show clear button in single mode (default: `false`)
    - `:max_selectable` - Maximum number of selections allowed, 0 = unlimited (default: `0`)
    - `:user_defined_options` - Allow users to create custom options by typing (default: `false`)
    - `:debounce` - Debounce time in ms for search input (default: `100`)

    For default values, see: [LiveTable.Select source code](https://github.com/gurujada/live_table/blob/master/lib/live_table/select.ex)

  ## Working with Options

    There are two ways to configure and display options in the select filter:

  ### 1. Static Options

    The simplest approach using a predefined list of options:

    ```elixir
    Select.new(:status, "status_select", %{
      label: "Status",
      options: [
        %{label: "Active", value: [1, "Currently active"]},
        %{label: "Pending", value: [2, "Awaiting processing"]},
        %{label: "Archived", value: [3, "No longer active"]}
      ]
    })
    ```

  ### 2. Dynamic Options via `options_source`

  Load options dynamically using a function or module. Used for fetching new options based on typed input.
  Uses `apply/3` under the hood to apply the function. Uses [`live-select-change`](https://github.com/gurujada/live_table/blob/master/lib/live_table/liveview_helpers.ex#L109) event to update the options.

    ```elixir
      # Point to your custom function
      Select.new({:suppliers, :name}, "supplier_name", %{
        label: "Supplier",
        options_source: {Demo.Catalog, :search_suppliers, []} # Same as you'd use for `apply/3`
      })

      # in your context module
      def search_suppliers(text) do
        Supplier
        |> where([c], ilike(c.name, ^"%\#{text}%"))
        |> select([c], {c.name, [c.id, c.contact_info]})
        |> Repo.all()
      end
    ```

    You could write your function to have other args passed to it as well. Just make sure the first arg is the text.

  ## Return Format Contract

  **IMPORTANT**: The `options_source` callback MUST return data in one of these formats:

    ```elixir
    # Format 1: Tuple with list value (recommended)
    {label, [primary_key, extra_info, ...]}

    # Format 2: Tuple with simple value
    {label, primary_key}
    ```

  The **first element** of the value (or the value itself if not a list) is used as the primary key
  for filtering. This value is used in the `WHERE id IN (...)` query clause.

  ### Correct Examples

    ```elixir
    # Using user ID as the filter value
    def search_users(text) do
      User
      |> where([u], ilike(u.name, ^"%\#{text}%"))
      |> select([u], {u.name, [u.id, u.email]})  # id is first element
      |> limit(10)
      |> Repo.all()
    end

    # Simple format with just the primary key
    def search_categories(text) do
      Category
      |> where([c], ilike(c.name, ^"%\#{text}%"))
      |> select([c], {c.name, c.id})  # id is the value
      |> limit(10)
      |> Repo.all()
    end
    ```

  ### Incorrect Examples

    ```elixir
    # WRONG: Using email as the value - will fail when filtering by id
    def search_users(text) do
      User
      |> where([u], ilike(u.name, ^"%\#{text}%"))
      |> select([u], {u.name, u.email})  # email is NOT a valid primary key!
      |> Repo.all()
    end
    ```

  ## Option Templates

    You can provide custom templates for rendering options in two ways:
    1. Using the default template format for options with label and value pairs
    2. Providing a custom template function through the `:option_template` option

  ### Default Template

    The default template expects options in the format:
    ```elixir
    %{label: label, value: [id, description]}
    ```
    The default template can be seen at [git link](https://github.com/gurujada/live_table/blob/master/lib/live_table/select.ex#L211)

  ### Custom Template
    Custom templates can be provided as functions that take an option map and return rendered HTML:

    ```elixir
    def custom_template(option) do
      assigns = %{option: option}
      ~H\"\"\"
      <div class="flex flex-col">
        <span class="font-bold"><%= @option.label %></span>
        <span class="text-sm text-gray-500"><%= @option.value |> Enum.at(0) %></span>
      </div>
      \"\"\"
    end

    # in your filter definition
    Select.new({:suppliers, :name}, "supplier_name", %{
      label: "Supplier",
      placeholder: "Search for suppliers...",
      options_source: {Demo.Catalog, :search_suppliers, []}
      option_template: &custom_template/1
    })
    ```

    Each method can be combined with others - for example, you could use dynamic or static options with
    custom templates.


  ## Examples

  If the field you want to use is part of the base schema(given to `LiveResource`), you can simply pass the field name as an atom.
    ```elixir
    # Creating a basic select filter (tags mode - default)
    Select.new(:category, "category_select", %{
      label: "Category",
      options: [
        %{label: "Electronics", value: [1, "Electronics"]},
        %{label: "Books", value: [2, "Books"]}
      ]
    })
    ```

    If its part of a joined schema, you can pass it as a tuple, with the table name(aliased in the query) and field name as shown-
    ```elixir
    # Creating a select filter with options loaded from database
    Select.new({:suppliers, :name}, "supplier_name", %{
        label: "Supplier",
        options_source: {Demo.Catalog, :search_suppliers, []}
      })
    ```

  ### Selection Mode Examples

    ```elixir
    # Single selection mode - pick one option
    Select.new(:status, "status_filter", %{
      label: "Status",
      mode: :single,
      allow_clear: true,
      options: [
        %{label: "Active", value: 1},
        %{label: "Inactive", value: 0}
      ]
    })

    # Tags mode (default) - multi-select with dropdown closing after each selection
    Select.new(:categories, "categories_filter", %{
      label: "Categories",
      mode: :tags,
      max_selectable: 5,
      options_source: {Demo.Catalog, :search_categories, []}
    })

    # Quick tags mode - multi-select with dropdown staying open
    Select.new(:tags, "tags_filter", %{
      label: "Tags",
      mode: :quick_tags,
      user_defined_options: true,  # Allow creating new tags by typing
      options_source: {Demo.Content, :search_tags, []}
    })
    ```

    Currently, nested relations are not supported.

  """
  import Ecto.Query

  use Phoenix.Component
  defstruct [:field, :key, :options]

  @default_options %{
    label: "Select",
    options: [],
    options_source: nil,
    option_template: nil,
    selected: [],
    placeholder: "Search...",
    css_classes: "",
    label_classes: "block text-sm font-medium leading-6 text-gray-900 dark:text-gray-100 mb-2",
    # LiveSelect options
    mode: :tags,
    allow_clear: false,
    max_selectable: 0,
    user_defined_options: false,
    debounce: 100
  }

  @doc false
  def new(field, key, options) do
    complete_options = Map.merge(@default_options, options)
    %__MODULE__{field: field, key: key, options: complete_options}
  end

  @doc false
  def apply(acc, %__MODULE__{field: {table, _field}, options: %{selected: values}}) do
    dynamic([{^table, t}], ^acc and t.id in ^values)
  end

  # update to dynamically take primary key. not always id.
  @doc false
  def apply(acc, %__MODULE__{field: _field, options: %{selected: values}}) do
    dynamic([p], ^acc and p.id in ^values)
  end

  @doc false
  def render(assigns) do
    ~H"""
    <div id={"select_filter[#{@key}]"} class={@filter.options.css_classes}>
      <label :if={@filter.options.label} class={@filter.options.label_classes}>
        {@filter.options.label}
      </label>
      <.live_component
        module={SutraUI.LiveSelect}
        field={Phoenix.Component.to_form(%{})["filters[#{@key}]"]}
        id={"#{@key}"}
        placeholder={@filter.options.placeholder}
        mode={@filter.options[:mode] || :tags}
        allow_clear={@filter.options[:allow_clear] || false}
        max_selectable={@filter.options[:max_selectable] || 0}
        user_defined_options={@filter.options[:user_defined_options] || false}
        debounce={@filter.options[:debounce]}
        class="live-table-select"
      >
        <:option :let={option}>
          {render_option_template(@filter.options.option_template, option)}
        </:option>
      </.live_component>
    </div>
    """
  end

  defp render_option_template(nil, %{label: label, value: [id, description]}) do
    assigns = %{label: label, id: id, description: description}

    ~H"""
    <div class="flex flex-col">
      <span class="text-sm font-medium text-gray-900 dark:text-gray-100">{@label}</span>
      <span class="text-xs text-gray-500 dark:text-gray-400 mt-0.5">
        ID: {@id} • {@description}
      </span>
    </div>
    """
  end

  # Fallback for options without the expected structure
  defp render_option_template(nil, %{label: label}) do
    assigns = %{label: label}

    ~H"""
    <span class="text-sm font-medium text-gray-900 dark:text-gray-100">{@label}</span>
    """
  end

  # Custom template provided as a function
  defp render_option_template(template_fn, option) do
    template_fn.(option)
  end
end
