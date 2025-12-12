defmodule Debug do
  @moduledoc """
  Debug utilities for inspecting LiveTable query building.

  The Debug module provides query inspection tools to help developers understand
  and troubleshoot the queries LiveTable generates. Debug output only appears
  in development mode (`Mix.env() == :dev`).

  ## Enabling Debug Mode

  Set the `debug` option in your `table_options/0`:

      def table_options do
        %{
          debug: :query  # or :trace or :off
        }
      end

  ## Debug Modes

  - `:off` - No debug output (default)
  - `:query` - Prints the final compiled query before execution
  - `:trace` - Uses `dbg()` to trace the query building pipeline

  ## Example Output

  With `debug: :query`:

      Query: #Ecto.Query<from p0 in MyApp.Product,
        where: p0.active == true,
        order_by: [asc: p0.name],
        limit: 11,
        offset: 0>

  ## Notes

  - Debug output appears in your terminal/server logs, not the browser
  - Only works in `:dev` environment for safety
  - Useful for understanding filter application and sorting behavior
  """

  defmacro debug_pipeline(pipeline, debug_mode) do
    if Mix.env() == :dev do
      quote do
        case unquote(debug_mode) do
          :trace ->
            unquote(pipeline) |> dbg()

          :query ->
            unquote(pipeline) |> IO.inspect(label: "Query: ")

          :off ->
            unquote(pipeline)
        end
      end
    else
      quote do
        unquote(pipeline)
      end
    end
  end
end
