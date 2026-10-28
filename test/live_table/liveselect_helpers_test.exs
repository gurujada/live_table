defmodule LiveTable.LiveSelectHelpersTest do
  use ExUnit.Case, async: true

  alias LiveTable.LiveSelectHelpers
  alias LiveTable.{Select}

  def filters do
    [
      category:
        Select.new({:category, :id}, "category", %{
          label: "Category",
          options: [
            %{label: "Electronics", value: [1, "Electronics"]},
            %{label: "Books", value: [2, "Books"]}
          ]
        }),
      status:
        Select.new(:status, "status", %{
          label: "Status",
          options: [
            %{label: "Active", value: "active"},
            %{label: "Draft", value: "draft"}
          ]
        })
    ]
  end

  describe "prepare_live_select_updates/3" do
    test "extracts live select updates from filter params" do
      params = %{
        "filters" => %{
          "category" => %{"id" => ["1", "2"]}
        }
      }

      socket = %{assigns: %{live_select_restored: MapSet.new()}}

      {updates, already_restored} =
        LiveSelectHelpers.prepare_live_select_updates(params, socket, filters())

      assert length(updates) == 1
      {key, ids} = hd(updates)
      assert key == "category"
      assert ids == [1, 2]
      assert already_restored == MapSet.new()
    end

    test "coerces string ids to integers" do
      params = %{
        "filters" => %{
          "category" => %{"id" => ["1", "2", "3"]}
        }
      }

      socket = %{assigns: %{live_select_restored: MapSet.new()}}

      {updates, _} = LiveSelectHelpers.prepare_live_select_updates(params, socket, filters())

      {_key, ids} = hd(updates)
      assert ids == [1, 2, 3]
      assert is_integer(hd(ids))
    end

    test "filters out already restored keys" do
      params = %{
        "filters" => %{
          "category" => %{"id" => ["1"]}
        }
      }

      socket = %{assigns: %{live_select_restored: MapSet.new(["category"])}}

      {updates, _} = LiveSelectHelpers.prepare_live_select_updates(params, socket, filters())

      assert updates == []
    end

    test "returns empty list when no live select filters in params" do
      params = %{
        "filters" => %{
          "other_filter" => "value"
        }
      }

      socket = %{assigns: %{live_select_restored: MapSet.new()}}

      {updates, _} = LiveSelectHelpers.prepare_live_select_updates(params, socket, filters())

      assert updates == []
    end

    test "handles empty filters map" do
      params = %{}
      socket = %{assigns: %{live_select_restored: MapSet.new()}}

      {updates, _} = LiveSelectHelpers.prepare_live_select_updates(params, socket, filters())

      assert updates == []
    end

    test "handles missing live_select_restored in socket" do
      params = %{
        "filters" => %{
          "category" => %{"id" => ["1"]}
        }
      }

      socket = %{assigns: %{}}

      {updates, already_restored} =
        LiveSelectHelpers.prepare_live_select_updates(params, socket, filters())

      assert length(updates) == 1
      assert already_restored == MapSet.new()
    end

    test "handles multiple live select filters" do
      params = %{
        "filters" => %{
          "category" => %{"id" => ["1"]},
          "status" => %{"id" => ["active"]}
        }
      }

      socket = %{assigns: %{live_select_restored: MapSet.new()}}

      {updates, _} = LiveSelectHelpers.prepare_live_select_updates(params, socket, filters())

      assert length(updates) == 2
      keys = Enum.map(updates, fn {k, _} -> k end)
      assert "category" in keys
      assert "status" in keys
    end

    test "uses the filter's name, which is the LiveSelect id, not its key" do
      filters = [supplier: Select.new(:supplier_id, "supplier_select", %{options: []})]
      params = %{"filters" => %{"supplier" => %{"id" => ["3"]}}}
      socket = %{assigns: %{}}

      assert {[{"supplier", [3]}], _} =
               LiveSelectHelpers.prepare_live_select_updates(params, socket, filters)
    end

    test "ignores keys that are not select filters" do
      params = %{"filters" => %{"unknown" => %{"id" => ["1"]}, "category" => %{"id" => ["1"]}}}
      socket = %{assigns: %{}}

      assert {[{"category", [1]}], _} =
               LiveSelectHelpers.prepare_live_select_updates(params, socket, filters())
    end
  end

  describe "track_restored_keys/2" do
    test "adds new keys to already restored" do
      already_restored = MapSet.new([:existing_key])
      live_select_updates = [{:new_key, [1, 2]}, {:another_key, [3]}]

      result = LiveSelectHelpers.track_restored_keys(already_restored, live_select_updates)

      assert MapSet.member?(result, :new_key)
      assert MapSet.member?(result, :another_key)
      assert MapSet.member?(result, :existing_key)
    end

    test "handles empty updates list" do
      already_restored = MapSet.new([:key1])

      result = LiveSelectHelpers.track_restored_keys(already_restored, [])

      assert result == already_restored
    end

    test "handles empty already_restored" do
      live_select_updates = [{:key1, [1]}, {:key2, [2]}]

      result = LiveSelectHelpers.track_restored_keys(MapSet.new(), live_select_updates)

      assert MapSet.member?(result, :key1)
      assert MapSet.member?(result, :key2)
    end
  end
end
