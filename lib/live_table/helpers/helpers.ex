defmodule LiveTable.Helpers do
  @moduledoc false
  use Phoenix.Component

  defmacro __using__(opts) do
    quote do
      import LiveTable.SortHelpers
      use LiveTable.FilterHelpers

      use LiveTable.LiveViewHelpers,
        schema: unquote(opts[:schema]),
        table_options: unquote(opts[:table_options])
    end
  end
end
