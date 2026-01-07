defmodule LiveTable.TableConfig do
  @moduledoc false

  @default_options %{
    pagination: %{
      enabled: true,
      mode: :buttons,
      sizes: [10, 25, 50],
      default_size: 10
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
      placeholder: "Search...",
      mode: :ilike # :ilike (PostgreSQL), :like (case-sensitive), :like_lower (SQLite compatible)
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

    base = @default_options
    |> deep_merge(app_defaults)
    |> deep_merge(table_options)

    # allow app-level search_mode config
    app_search_mode = Application.get_env(:live_table, :search_mode)

    # apply app-level search_mode if not overridden in table_options
    if app_search_mode && !get_in(table_options, [:search, :mode]) do
      put_in(base, [:search, :mode], app_search_mode)
    else
      base
    end
  end
end
