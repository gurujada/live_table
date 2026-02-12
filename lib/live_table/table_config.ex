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
      placeholder: "Search...",
      # :auto detects the database adapter and picks the best mode
      # :ilike uses PostgreSQL's native ILIKE (fastest on PG)
      # :like_lower uses lower() function (works on all databases)
      mode: :auto
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

  @doc """
  Determines the search mode based on configuration and database adapter.

  ## Modes
    - :auto - Automatically detects the database and chooses the best mode
      - PostgreSQL: uses :ilike (native case-insensitive operator)
      - All others: uses :like_lower (portable case-insensitive via lower())
    - :ilike - Forces PostgreSQL ILIKE operator
    - :like_lower - Forces portable lower() function (works on any database)

  ## Examples

      # Auto-detect (default)
      get_search_mode(%{search: %{mode: :auto}}, MyApp.Repo)
      # Returns :ilike for PostgreSQL, :like_lower for others

      # Explicit mode
      get_search_mode(%{search: %{mode: :like_lower}}, MyApp.Repo)
      # Returns :like_lower regardless of database
  """
  def get_search_mode(table_options, repo \\ Application.get_env(:live_table, :repo)) do
    mode = get_in(table_options, [:search, :mode]) || :auto

    if mode == :auto do
      adapter_to_mode(repo.__adapter__())
    else
      mode
    end
  end

  # PostgreSQL gets native ILIKE optimization
  defp adapter_to_mode(Ecto.Adapters.Postgres), do: :ilike

  # All other databases get portable lower() function
  # This works on SQLite, MySQL, SQL Server, Oracle, etc.
  defp adapter_to_mode(_), do: :like_lower
end
