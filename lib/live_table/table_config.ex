defmodule LiveTable.TableConfig do
  @moduledoc false

  @default_options %{
    pagination: %{
      enabled: true,
      mode: :buttons,
      sizes: [10, 25, 50],
      default_size: 10,
      max_per_page: 50
    },
    sorting: %{
      enabled: true,
      default_sort: [id: :asc]
    },
    exports: %{
      enabled: true,
      formats: [:csv, :pdf]
    },
    search: %{
      debounce: 300,
      enabled: true,
      placeholder: "Search..."
    },
    mode: :table,
    use_streams: true,
    fixed_header: false,
    debug: :off
  }

  def deep_merge(left, right) do
    Map.merge(left, right, fn
      _, %{} = left, %{} = right -> deep_merge(left, right)
      _, _left, right -> right
    end)
  end

  def get_table_options(table_options) do
    app_defaults = Application.get_env(:live_table, :defaults, %{})

    @default_options
    |> deep_merge(app_defaults)
    |> deep_merge(table_options)
  end
end
