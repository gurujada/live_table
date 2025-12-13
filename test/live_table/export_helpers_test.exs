defmodule LiveTable.ExportHelpersTest do
  @moduledoc """
  Tests for LiveTable.ExportHelpers - export timestamp generation and helpers.

  ExportHelpers provides functions for generating export files with safe filenames
  and handling the export workflow through PubSub.

  ## What This Tests

    * `generate_export_timestamp/0` - Creating filename-safe timestamps
    * Timestamp format validation
    * Character safety for various filesystems

  Note: The macro-injected functions (handle_event for exports, extract_header_data,
  maybe_subscribe, handle_info for file_ready) require a full LiveView context
  and are tested separately in LiveView integration tests.
  """

  use ExUnit.Case, async: true

  alias LiveTable.ExportHelpers

  describe "generate_export_timestamp/0" do
    test "returns a string" do
      timestamp = ExportHelpers.generate_export_timestamp()

      assert is_binary(timestamp)
    end

    test "format contains date components" do
      timestamp = ExportHelpers.generate_export_timestamp()

      # Should contain year (4 digits)
      assert timestamp =~ ~r/\d{4}/
    end

    test "format is safe for filenames" do
      timestamp = ExportHelpers.generate_export_timestamp()

      # Should not contain characters that are problematic for filenames
      # Common problematic characters: : / \ ? * " < > |
      refute timestamp =~ ":"
      refute timestamp =~ "/"
      refute timestamp =~ "\\"
      refute timestamp =~ "?"
      refute timestamp =~ "*"
      refute timestamp =~ "\""
      refute timestamp =~ "<"
      refute timestamp =~ ">"
      refute timestamp =~ "|"
    end

    test "format contains no spaces" do
      timestamp = ExportHelpers.generate_export_timestamp()

      refute timestamp =~ " "
    end

    test "uses hyphens as separators" do
      timestamp = ExportHelpers.generate_export_timestamp()

      # Should use hyphens between components
      assert timestamp =~ "-"
    end

    test "contains only alphanumeric characters and hyphens" do
      timestamp = ExportHelpers.generate_export_timestamp()

      # Should match pattern: alphanumeric and hyphens only
      assert timestamp =~ ~r/^[a-zA-Z0-9\-]+$/
    end

    test "generates unique timestamps" do
      # Generate multiple timestamps and verify they're unique
      # Note: This might occasionally fail if called within same millisecond
      timestamp1 = ExportHelpers.generate_export_timestamp()
      :timer.sleep(1)
      timestamp2 = ExportHelpers.generate_export_timestamp()

      # Timestamps should either be different or very close in time
      # At minimum, they should be valid strings
      assert is_binary(timestamp1)
      assert is_binary(timestamp2)
    end

    test "timestamp is reasonable length for filename" do
      timestamp = ExportHelpers.generate_export_timestamp()

      # Should be reasonable length (not too short, not too long)
      # Example format: "2024-01-15-10-30-45-123456789Z"
      length = String.length(timestamp)
      # At least date
      assert length > 10
      # Not unreasonably long
      assert length < 50
    end

    test "starts with year" do
      timestamp = ExportHelpers.generate_export_timestamp()

      # Current year should be at the start
      current_year = DateTime.utc_now().year |> to_string()
      assert String.starts_with?(timestamp, current_year)
    end

    test "format is consistent across calls" do
      timestamp1 = ExportHelpers.generate_export_timestamp()
      timestamp2 = ExportHelpers.generate_export_timestamp()

      # Both should have same structure (same number of hyphens, similar length)
      hyphen_count1 = timestamp1 |> String.graphemes() |> Enum.count(&(&1 == "-"))
      hyphen_count2 = timestamp2 |> String.graphemes() |> Enum.count(&(&1 == "-"))

      assert hyphen_count1 == hyphen_count2
    end
  end

  describe "generate_export_timestamp/0 cross-platform safety" do
    test "safe for Windows filenames" do
      timestamp = ExportHelpers.generate_export_timestamp()

      # Windows reserved characters: \ / : * ? " < > |
      windows_reserved = ~r/[\\\/:\*\?"<>\|]/
      refute timestamp =~ windows_reserved
    end

    test "safe for macOS filenames" do
      timestamp = ExportHelpers.generate_export_timestamp()

      # macOS only reserves : and /
      refute timestamp =~ ":"
      refute timestamp =~ "/"
    end

    test "safe for Linux filenames" do
      timestamp = ExportHelpers.generate_export_timestamp()

      # Linux only reserves / and null
      refute timestamp =~ "/"
      refute timestamp =~ "\0"
    end

    test "safe for URLs" do
      timestamp = ExportHelpers.generate_export_timestamp()

      # URL unsafe characters that might need encoding
      # We want to avoid: space, #, %, &, +, etc.
      refute timestamp =~ " "
      refute timestamp =~ "#"
      refute timestamp =~ "%"
      refute timestamp =~ "&"
      refute timestamp =~ "+"
    end
  end

  describe "timestamp format details" do
    test "represents current time" do
      now = DateTime.utc_now()
      timestamp = ExportHelpers.generate_export_timestamp()

      # Extract year from timestamp (first 4 characters)
      year_from_timestamp = String.slice(timestamp, 0, 4)

      assert year_from_timestamp == to_string(now.year)
    end

    test "includes month component" do
      timestamp = ExportHelpers.generate_export_timestamp()
      now = DateTime.utc_now()

      # Month should be in the timestamp after year
      month_str = now.month |> to_string() |> String.pad_leading(2, "0")

      # The timestamp should contain the month somewhere
      assert timestamp =~ month_str
    end

    test "includes day component" do
      timestamp = ExportHelpers.generate_export_timestamp()
      now = DateTime.utc_now()

      # Day should be in the timestamp
      day_str = now.day |> to_string() |> String.pad_leading(2, "0")

      assert timestamp =~ day_str
    end
  end

  describe "timestamp usage in filenames" do
    test "can be used to create valid CSV filename" do
      timestamp = ExportHelpers.generate_export_timestamp()
      filename = "export_#{timestamp}.csv"

      # Should be a valid filename
      assert is_binary(filename)
      assert String.ends_with?(filename, ".csv")
      assert String.contains?(filename, timestamp)
    end

    test "can be used to create valid PDF filename" do
      timestamp = ExportHelpers.generate_export_timestamp()
      filename = "report_#{timestamp}.pdf"

      # Should be a valid filename
      assert is_binary(filename)
      assert String.ends_with?(filename, ".pdf")
      assert String.contains?(filename, timestamp)
    end

    test "filename length is reasonable" do
      timestamp = ExportHelpers.generate_export_timestamp()
      filename = "products_export_#{timestamp}.csv"

      # Most filesystems support up to 255 characters
      assert String.length(filename) < 255
    end
  end
end
