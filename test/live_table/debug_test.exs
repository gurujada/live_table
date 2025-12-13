defmodule LiveTable.DebugTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureIO
  import Ecto.Query

  defmodule TestSchema do
    use Ecto.Schema

    schema "test_table" do
      field :name, :string
    end
  end

  # Test the debug_pipeline macro directly
  defmodule TestDebugModule do
    import Ecto.Query
    import LiveTable.Debug, only: [debug_pipeline: 2]

    def test_query_debug do
      from(t in TestSchema, select: t)
      |> debug_pipeline(:query)
    end

    def test_trace_debug do
      from(t in TestSchema, select: t)
      |> debug_pipeline(:trace)
    end

    def test_off_debug do
      from(t in TestSchema, select: t)
      |> debug_pipeline(:off)
    end
  end

  test "debug_pipeline :query mode shows query with IO.inspect" do
    # Only test in dev environment since debug_pipeline is a no-op in test
    if Mix.env() == :dev do
      output =
        capture_io(fn ->
          TestDebugModule.test_query_debug()
        end)

      assert String.contains?(output, "Query: ")
      assert String.contains?(output, "TestSchema")
    else
      # In non-dev environments, debug_pipeline should be a no-op
      result = TestDebugModule.test_query_debug()
      assert %Ecto.Query{} = result
    end
  end

  test "debug_pipeline :trace mode shows query with dbg" do
    if Mix.env() == :dev do
      output =
        capture_io(fn ->
          TestDebugModule.test_trace_debug()
        end)

      # dbg() shows the query structure
      assert String.contains?(output, "TestSchema")
    else
      # In non-dev environments, debug_pipeline should be a no-op
      result = TestDebugModule.test_trace_debug()
      assert %Ecto.Query{} = result
    end
  end

  test "debug_pipeline :off mode returns query unchanged without output" do
    output =
      capture_io(fn ->
        result = TestDebugModule.test_off_debug()
        assert %Ecto.Query{} = result
      end)

    # Should produce no output regardless of environment
    assert output == ""
  end

  test "debug_pipeline macro only activates in dev environment" do
    # This test verifies the macro behavior
    if Mix.env() == :dev do
      # In dev, debug modes should produce output
      output =
        capture_io(fn ->
          TestDebugModule.test_query_debug()
        end)

      assert output != ""
    else
      # In other environments, no debug output
      output =
        capture_io(fn ->
          TestDebugModule.test_query_debug()
        end)

      assert output == ""
    end
  end
end
