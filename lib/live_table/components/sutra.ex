defmodule LiveTable.Components.Sutra do
  @moduledoc """
  The default `LiveTable.Components`, built on Sutra UI. Used automatically when
  `:sutra_ui` is installed.

  This is the only module that names Sutra UI components. It calls them remotely
  rather than importing them, so LiveTable compiles without `:sutra_ui`.

  `use LiveTable.Components.Sutra` in your own components module to override
  individual components and inherit the rest.
  """

  @behaviour LiveTable.Components

  use Phoenix.Component

  @compile {:no_warn_undefined,
            [
              SutraUI.Checkbox,
              SutraUI.DropdownMenu,
              SutraUI.Empty,
              SutraUI.InputGroup,
              SutraUI.Label,
              SutraUI.RangeSlider,
              SutraUI.Select
            ]}

  defmacro __using__(_opts) do
    quote do
      @behaviour LiveTable.Components

      defdelegate search(assigns), to: LiveTable.Components.Sutra
      defdelegate per_page(assigns), to: LiveTable.Components.Sutra
      defdelegate exports(assigns), to: LiveTable.Components.Sutra
      defdelegate empty_state(assigns), to: LiveTable.Components.Sutra
      defdelegate boolean_filter(assigns), to: LiveTable.Components.Sutra
      defdelegate range_filter(assigns), to: LiveTable.Components.Sutra
      defdelegate select_filter(assigns), to: LiveTable.Components.Sutra

      defoverridable LiveTable.Components
    end
  end

  @impl true
  def search(assigns) do
    ~H"""
    <label for={@id} class="sr-only">Search</label>
    <SutraUI.InputGroup.input_group>
      <:prefix type="icon">
        <svg
          xmlns="http://www.w3.org/2000/svg"
          width="24"
          height="24"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          stroke-linecap="round"
          stroke-linejoin="round"
          class="size-4 text-muted-foreground"
          aria-hidden="true"
        >
          <circle cx="11" cy="11" r="8" /><path d="m21 21-4.3-4.3" />
        </svg>
      </:prefix>
      <input
        type="text"
        name="search"
        autocomplete="off"
        id={@id}
        class="input w-full pl-9"
        placeholder={@placeholder}
        value={@value}
        phx-debounce={@debounce}
      />
    </SutraUI.InputGroup.input_group>
    """
  end

  @impl true
  def per_page(assigns) do
    ~H"""
    <SutraUI.Select.select
      id={@id}
      name="per_page"
      value={@value}
      class="w-24"
      trigger_class="w-full"
    >
      <:trigger>
        {@value}
      </:trigger>
      <SutraUI.Select.select_option
        :for={size <- @sizes}
        value={to_string(size)}
        label={to_string(size)}
      />
    </SutraUI.Select.select>
    """
  end

  @impl true
  def exports(assigns) do
    ~H"""
    <SutraUI.DropdownMenu.dropdown_menu id={@id}>
      <:trigger>
        <span class="flex items-center gap-2">
          <.download_icon /> Export
        </span>
      </:trigger>
      <SutraUI.DropdownMenu.dropdown_item :for={format <- @formats}>
        <button
          type="button"
          class="flex items-center gap-2"
          phx-click="export"
          phx-value-format={format}
        >
          <.download_icon /> Export as {String.upcase(to_string(format))}
        </button>
      </SutraUI.DropdownMenu.dropdown_item>
    </SutraUI.DropdownMenu.dropdown_menu>
    """
  end

  defp download_icon(assigns) do
    ~H"""
    <svg
      xmlns="http://www.w3.org/2000/svg"
      width="24"
      height="24"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="2"
      stroke-linecap="round"
      stroke-linejoin="round"
      class="size-4"
      aria-hidden="true"
    >
      <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" /><polyline points="7 10 12 15 17 10" /><line
        x1="12"
        x2="12"
        y1="15"
        y2="3"
      />
    </svg>
    """
  end

  @impl true
  def empty_state(assigns) do
    ~H"""
    <SutraUI.Empty.empty>
      <:icon>
        <svg
          xmlns="http://www.w3.org/2000/svg"
          width="24"
          height="24"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          stroke-linecap="round"
          stroke-linejoin="round"
          class="size-12"
          aria-hidden="true"
        >
          <path d="m6 14 1.5-2.9A2 2 0 0 1 9.24 10H14.76a2 2 0 0 1 1.74 1.1L18 14" /><path d="M6 14h12v5a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2v-5Z" /><path d="M21 14V7a2 2 0 0 0-2-2H5a2 2 0 0 0-2 2v7" />
        </svg>
      </:icon>
      <:title>No data</:title>
      <:description>
        No records found. Try adjusting your filters or create a new record.
      </:description>
    </SutraUI.Empty.empty>
    """
  end

  @impl true
  def boolean_filter(assigns) do
    ~H"""
    <div class="flex items-center gap-2">
      <input type="hidden" name={"filters[#{@key}]"} value="false" />
      <SutraUI.Checkbox.checkbox
        id={"filters-#{@key}"}
        name={"filters[#{@key}]"}
        checked={Map.has_key?(@applied_filters, @key)}
        class={Map.get(@filter.options, :class, "")}
      />
      <SutraUI.Label.label for={"filters-#{@key}"}>
        {@filter.options.label}
      </SutraUI.Label.label>
    </div>
    """
  end

  @impl true
  def range_filter(assigns) do
    ~H"""
    <div class={@filter.options.css_classes}>
      <label :if={@filter.options.label} class={@filter.options.label_classes}>
        {@filter.options.label}
        <span :if={@filter.options.unit != ""} class="text-muted-foreground">
          ({@filter.options.unit})
        </span>
      </label>
      <div class="mt-3">
        <SutraUI.RangeSlider.range_slider
          name={@key}
          id={"range_filter[#{@key}]"}
          min={@filter.options.min}
          max={@filter.options.max}
          step={@filter.options.step}
          value_min={@current_min || @filter.options.default_min}
          value_max={@current_max || @filter.options.default_max}
          tooltips={@filter.options.slider_options.tooltips}
          pips={@pips_config}
          on_change="range_change"
          class={@filter.options.slider_classes}
        />
      </div>
    </div>
    """
  end

  @impl true
  def select_filter(assigns) do
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
        options={@filter.options[:options] || []}
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
      <span class="text-sm font-medium text-foreground">{@label}</span>
      <span class="text-xs text-muted-foreground mt-0.5">
        ID: {@id} • {@description}
      </span>
    </div>
    """
  end

  defp render_option_template(nil, %{label: label}) do
    assigns = %{label: label}

    ~H"""
    <span class="text-sm font-medium text-foreground">{@label}</span>
    """
  end

  defp render_option_template(template_fn, option) do
    template_fn.(option)
  end
end
