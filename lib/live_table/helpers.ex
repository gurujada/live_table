defmodule LiveTable.Helpers do
  @moduledoc false
  use Phoenix.Component

  defmacro __using__(opts) do
    quote do
      import LiveTable.SortHelpers
      use LiveTable.FilterHelpers

      use LiveTable.LiveViewHelpers,
        # schema: unquote(opts[:schema]),
        table_options: unquote(opts[:table_options])

      # Parse range values, converting to integer if step is integer
      def parse_range_values(%{step: step}, min, max) when is_integer(step) do
        {min_int, _} = Integer.parse(min)
        {max_int, _} = Integer.parse(max)
        {min_int, max_int}
      end

      def parse_range_values(%{step: _step}, min, max) do
        {min_float, _} = Float.parse(min)
        {max_float, _} = Float.parse(max)
        {min_float, max_float}
      end
    end
  end
end
