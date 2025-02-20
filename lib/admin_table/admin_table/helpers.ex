defmodule AdminTable.Helpers do
  use Phoenix.Component

  defmacro __using__(opts) do
    quote do
      import AdminTable.SortHelpers
      use AdminTable.FilterHelpers
      use AdminTable.LiveViewHelpers, resource: unquote(opts[:resource])

      def parse_range_values(:number, min, max) do
        {min_float, _} = Float.parse(min)
        {max_float, _} = Float.parse(max)
        {min_float, max_float}
      end

      def parse_range_values(:date, min, max) do
        {Date.from_iso8601!(min), Date.from_iso8601!(max)}
      end

      def parse_range_values(:datetime, min, max) do
        {NaiveDateTime.from_iso8601!(min), NaiveDateTime.from_iso8601!(max)}
      end
    end
  end
end
