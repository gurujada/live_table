defmodule LiveTable.TestComponents do
  @moduledoc false
  # A components module with no Sutra UI, used to test LiveTable without it.
  # docs/custom-components.md shows the same module.
  @behaviour LiveTable.Components

  use Phoenix.Component

  @impl true
  def search(assigns) do
    ~H"""
    <input
      type="search"
      name="search"
      id={@id}
      value={@value}
      placeholder={@placeholder}
      phx-debounce={@debounce}
    />
    """
  end

  @impl true
  def per_page(assigns) do
    ~H"""
    <select name="per_page" id={@id}>
      <option :for={size <- @sizes} value={size} selected={to_string(size) == @value}>
        {size}
      </option>
    </select>
    """
  end

  @impl true
  def exports(assigns) do
    ~H"""
    <button
      :for={format <- @formats}
      type="button"
      phx-click="export"
      phx-value-format={format}
    >
      Export {String.upcase(to_string(format))}
    </button>
    """
  end

  @impl true
  def empty_state(assigns) do
    ~H"""
    <p>Nothing to show.</p>
    """
  end

  @impl true
  def boolean_filter(assigns) do
    ~H"""
    <input type="hidden" name={"filters[#{@key}]"} value="false" />
    <input
      type="checkbox"
      id={"filters-#{@key}"}
      name={"filters[#{@key}]"}
      value="true"
      checked={Map.has_key?(@applied_filters, @key)}
    />
    <label for={"filters-#{@key}"}>{@filter.options.label}</label>
    """
  end

  @impl true
  def range_filter(assigns) do
    ~H"""
    <fieldset>
      <legend>{@filter.options.label}</legend>
      <input
        type="number"
        name={"filters[#{@key}][min]"}
        value={@current_min || @filter.options.default_min}
        step={@filter.options.step}
      />
      <input
        type="number"
        name={"filters[#{@key}][max]"}
        value={@current_max || @filter.options.default_max}
        step={@filter.options.step}
      />
    </fieldset>
    """
  end

  @impl true
  def select_filter(assigns) do
    ~H"""
    <label for={"filters-#{@key}"}>{@filter.options.label}</label>
    <select id={"filters-#{@key}"} name={"filters[#{@key}][id][]"} multiple>
      <option
        :for={option <- @filter.options.options}
        value={option_id(option)}
        selected={option_id(option) in selected_ids(@applied_filters, @key)}
      >
        {option.label}
      </option>
    </select>
    """
  end

  defp option_id(%{value: [id | _]}), do: id
  defp option_id(%{value: id}), do: id

  defp selected_ids(applied_filters, key) do
    case Map.get(applied_filters, key) do
      %LiveTable.Select{options: %{selected: selected}} -> selected
      _ -> []
    end
  end
end

defmodule LiveTable.TestPartialComponents do
  @moduledoc false
  use LiveTable.Components.Sutra
  use Phoenix.Component

  def per_page(assigns) do
    ~H"""
    <select name="per_page" id="custom-per-page">
      <option :for={size <- @sizes} value={size}>{size}</option>
    </select>
    """
  end
end

defmodule LiveTable.TestIncompleteComponents do
  @moduledoc false
  @behaviour LiveTable.Components

  defdelegate search(assigns), to: LiveTable.TestComponents
  defdelegate per_page(assigns), to: LiveTable.TestComponents
  defdelegate exports(assigns), to: LiveTable.TestComponents
  defdelegate empty_state(assigns), to: LiveTable.TestComponents
  defdelegate boolean_filter(assigns), to: LiveTable.TestComponents
end
