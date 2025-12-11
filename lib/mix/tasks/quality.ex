defmodule Mix.Tasks.LiveTable.Quality do
  @shortdoc "Run all quality checks (format, compile, test)"
  @moduledoc """
  Runs format, compile (warnings-as-errors), and test checks.

  Fails fast on first error. Output is suppressed on success, shown on failure.
  """

  use Mix.Task

  @impl Mix.Task
  def run(_args) do
    IO.puts("Running quality checks...\n")

    with :ok <- check("format", ["--check-formatted"]),
         :ok <- check("compile", ["--warnings-as-errors"]),
         :ok <- check("test", []) do
      IO.puts("\n✓ All quality checks passed!")
    end
  end

  defp check(task, args) do
    {output, code} = System.cmd("mix", [task | args], stderr_to_stdout: true)

    if code == 0 do
      IO.puts("✓ #{task}")
      :ok
    else
      IO.puts("✗ #{task} failed\n")
      IO.puts(output)
      System.halt(code)
    end
  end
end
