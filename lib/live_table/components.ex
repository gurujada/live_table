defmodule LiveTable.Components do
  @moduledoc false
  # Internal form components for LiveTable using Sutra UI.
  # These components wrap Sutra UI primitives to provide form inputs used by LiveTable.
  # If you want to use different components, configure your own module in config.exs:
  #
  #     config :live_table, :components, MyApp.Components

  use Phoenix.Component

  alias SutraUI.Input, as: SutraInput
  import SutraUI.Checkbox, only: [checkbox: 1]
  import SutraUI.Label, only: [label: 1]
  import SutraUI.Textarea, only: [textarea: 1]
  import SutraUI.Select, only: [select: 1, select_option: 1]

  @doc """
  Renders a checkbox input (without label).

  ## Examples

      <.lt_checkbox name="active" checked={@active} />
      <.lt_checkbox name="terms" id="terms-checkbox" />
  """
  attr(:id, :any, default: nil)
  attr(:name, :any, required: true)
  attr(:checked, :boolean, default: false)
  attr(:rest, :global, include: ~w(disabled required class))

  def lt_checkbox(assigns) do
    ~H"""
    <input type="hidden" name={@name} value="false" disabled={@rest[:disabled]} />
    <.checkbox
      id={@id || @name}
      name={@name}
      checked={@checked}
      {@rest}
    />
    """
  end

  @doc """
  Renders a label.

  ## Examples

      <.lt_label for="email">Email</.lt_label>
  """
  attr(:for, :string, default: nil)
  attr(:class, :string, default: nil)
  slot(:inner_block, required: true)

  def lt_label(assigns) do
    ~H"""
    <.label for={@for} class={@class}>
      {render_slot(@inner_block)}
    </.label>
    """
  end

  @doc """
  Renders a form input with label and error handling.

  Supports text, email, password, number, date, select, textarea, and other HTML5 input types.
  For checkboxes, use the separate `lt_checkbox/1` and `lt_label/1` components.

  ## Examples

      <.input type="text" name="search" label="Search" />
      <.input type="select" name="status" label="Status" options={[{"Active", "active"}]} />
  """

  attr(:id, :any, default: nil)
  attr(:name, :any)
  attr(:label, :string, default: nil)
  attr(:value, :any)

  attr(:type, :string,
    default: "text",
    values: ~w(color date datetime-local email file month number password
               range search select tel text textarea time url week)
  )

  attr(:field, Phoenix.HTML.FormField,
    doc: "a form field struct retrieved from the form, for example: @form[:email]"
  )

  attr(:errors, :list, default: [])
  attr(:prompt, :string, default: nil, doc: "the prompt for select inputs")
  attr(:options, :list, doc: "the options to pass to Phoenix.HTML.Form.options_for_select/2")
  attr(:multiple, :boolean, default: false, doc: "the multiple flag for select inputs")

  attr(:rest, :global,
    include: ~w(accept autocomplete capture cols disabled form list max maxlength min minlength
                multiple pattern placeholder readonly required rows size step)
  )

  def input(%{type: "select"} = assigns) do
    ~H"""
    <div class="field-vertical">
      <.label :if={@label} for={@id || @name}>{@label}</.label>
      <.select
        id={@id || @name}
        name={@name}
        value={@value}
      >
        <:trigger>
          {selected_label(@options, @value, @prompt)}
        </:trigger>
        <.select_option :if={@prompt} value="" label={@prompt} />
        <.select_option
          :for={{label, value} <- normalize_options(@options)}
          value={to_string(value)}
          label={label}
        />
      </.select>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "textarea"} = assigns) do
    ~H"""
    <div class="field-vertical">
      <.label :if={@label} for={@id || @name}>{@label}</.label>
      <.textarea
        id={@id || @name}
        name={@name}
        value={Phoenix.HTML.Form.normalize_value("textarea", @value)}
        {@rest}
      />
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(assigns) do
    ~H"""
    <div class="field-vertical">
      <.label :if={@label} for={@id || @name}>{@label}</.label>
      <SutraInput.input
        type={@type}
        name={@name}
        id={@id || @name}
        value={Phoenix.HTML.Form.normalize_value(@type, @value)}
        {@rest}
      />
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  @doc """
  Renders an error message.
  """
  slot(:inner_block, required: true)

  def error(assigns) do
    ~H"""
    <p class="field-error">
      {render_slot(@inner_block)}
    </p>
    """
  end

  # Helper to normalize options to {label, value} tuples
  defp normalize_options(options) do
    Enum.map(options, fn
      {label, value} -> {label, value}
      value -> {value, value}
    end)
  end

  # Helper to get the selected label for display
  defp selected_label(options, value, prompt) do
    case Enum.find(normalize_options(options), fn {_label, v} ->
           to_string(v) == to_string(value)
         end) do
      {label, _} -> label
      nil -> prompt || "Select..."
    end
  end
end
