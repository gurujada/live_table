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
      # :auto uses the repo adapter to pick a safe default
      # :ilike (PostgreSQL), :like (case-sensitive), :like_lower (SQLite compatible)
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

    base =
      @default_options
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

  def get_search_mode(table_options, repo \\ Application.get_env(:live_table, :repo)) do
    table_options
    |> get_table_options()
    |> Map.get(:search, %{})
    |> resolve_search_mode(repo)
  end

  def resolve_search_mode(search_opts, repo) do
    mode = Map.get(search_opts, :mode, :auto)
    adapter = Map.get(search_opts, :adapter)
    db = Map.get(search_opts, :db) || Map.get(search_opts, :database)

    cond do
      mode in [:ilike, :like, :like_lower] ->
        mode

      adapter ->
        adapter_to_mode(adapter)

      db ->
        db_to_mode(db)

      mode in [:auto, nil] ->
        repo_adapter(repo) |> adapter_to_mode()

      true ->
        :like_lower
    end
  end

  defp repo_adapter(nil), do: nil
  defp repo_adapter(repo), do: repo.__adapter__()

  defp adapter_to_mode(Ecto.Adapters.Postgres), do: :ilike
  defp adapter_to_mode(Ecto.Adapters.SQLite3), do: :like_lower
  defp adapter_to_mode(Ecto.Adapters.MyXQL), do: :like_lower
  defp adapter_to_mode(Ecto.Adapters.Tds), do: :like_lower
  defp adapter_to_mode(_), do: :like_lower

  defp db_to_mode(db) do
    case normalize_db(db) do
      "postgres" -> :ilike
      "postgresql" -> :ilike
      "sqlite" -> :like_lower
      "sqlite3" -> :like_lower
      "mysql" -> :like_lower
      "mariadb" -> :like_lower
      "maria" -> :like_lower
      "mssql" -> :like_lower
      "sqlserver" -> :like_lower
      _ -> :like_lower
    end
  end

  defp normalize_db(db) when is_atom(db), do: db |> Atom.to_string() |> String.downcase()
  defp normalize_db(db) when is_binary(db), do: String.downcase(db)
  defp normalize_db(_), do: nil
end
