defmodule Mix.Tasks.LiveTable.Install do
  @moduledoc """
  Installs and configures LiveTable in your Phoenix application.

  This task configures all necessary files for LiveTable to work properly:
  - Adds LiveTable configuration to config/config.exs
  - Updates assets/js/app.js with TableHooks
  - Updates assets/css/app.css with LiveTable styles
  - Adds exports to static paths in *_web.ex

  ## Usage

      $ mix live_table.install

  This task assumes LiveTable dependency is already added to mix.exs.
  """

  use Igniter.Mix.Task

  @shortdoc "Installs and configures LiveTable in your Phoenix application"

  @impl Igniter.Mix.Task
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      group: :live_table,
      example: "mix live_table.install",
      schema: [
        oban: :boolean
      ]
    }
  end

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    app_name = Igniter.Project.Module.module_name_prefix(igniter)

    igniter
    |> configure_live_table_config(app_name)
    |> configure_app_js()
    |> configure_app_css()
    |> maybe_configure_oban(app_name)
    |> Igniter.add_notice("LiveTable has been successfully configured!")
    |> Igniter.add_notice("")
    |> Igniter.add_notice("Next steps:")
    |> Igniter.add_notice("1. Restart your Phoenix server")
    |> Igniter.add_notice("2. Create your first LiveTable by following the Quick Start guide")
    |> static_paths_reminder()
    |> add_oban_next_steps(app_name)
  end

  defp static_paths_reminder(igniter) do
    Igniter.add_notice(
      igniter,
      "3. Reminder: add \"exports\" to your static paths (in YourAppWeb.static_paths)"
    )
  end

  defp configure_live_table_config(igniter, app_module) do
    repo_module = Module.concat([app_module, "Repo"])
    pubsub_module = Module.concat([app_module, "PubSub"])

    app_atom =
      app_module
      |> Module.split()
      |> List.last()
      |> Macro.underscore()
      |> String.to_atom()

    has_config? =
      Igniter.Project.Config.configures_root_key?(igniter, "config.exs", :live_table)

    case has_config? do
      true ->
        igniter

      false ->
        config_content = """
        config :live_table,
          repo: #{inspect(repo_module)},
          pubsub: #{inspect(pubsub_module)},
          app: #{inspect(app_atom)}
        """

        igniter
        |> Igniter.include_or_create_file("config/config.exs", "import Config\n")
        |> Igniter.update_file("config/config.exs", fn source ->
          content = Rewrite.Source.get(source, :content)

          updated_content =
            case String.contains?(content, "config :live_table") do
              true -> content
              false -> content <> "\n" <> config_content <> "\n"
            end

          Rewrite.Source.update(source, :content, updated_content)
        end)
    end
  end

  defp configure_app_js(igniter) do
    path = "assets/js/app.js"

    case Igniter.exists?(igniter, path) do
      true ->
        igniter = Igniter.include_existing_file(igniter, path)
        content = igniter.rewrite |> Rewrite.source!(path) |> Rewrite.Source.get(:content)

        case table_hooks_present?(content) do
          true ->
            igniter

          false ->
            updated_content = update_app_js_content(content)

            igniter
            |> Igniter.update_file(path, fn source ->
              Rewrite.Source.update(source, :content, updated_content)
            end)
        end

      false ->
        Igniter.add_warning(igniter, "Could not find #{path}")
    end
  end

  defp table_hooks_present?(content), do: String.contains?(content, "TableHooks")

  defp update_app_js_content(content) do
    import_line =
      ~s|import { TableHooks } from "../../deps/live_table/priv/static/live-table.js"|

    content
    |> add_import_line(import_line)
    |> add_hooks_to_livesocket()
  end

  defp add_import_line(content, import_line) do
    lines = String.split(content, "\n")

    case find_last_import_line(lines) do
      nil ->
        import_line <> "\n\n" <> content

      index when is_integer(index) ->
        {before, after_lines} = Enum.split(lines, index + 1)
        (before ++ [import_line] ++ after_lines) |> Enum.join("\n")
    end
  end

  defp find_last_import_line(lines) do
    lines
    |> Enum.with_index()
    |> Enum.filter(fn {line, _} -> String.match?(line, ~r/^\s*import\s+/) end)
    |> case do
      [] -> nil
      imports -> imports |> List.last() |> elem(1)
    end
  end

  defp add_hooks_to_livesocket(content) do
    case Regex.run(~r/new\s+LiveSocket\([^,]+,\s*[^,]+,\s*\{([^}]*)\}/s, content, return: :index) do
      [{match_start, match_length}, {options_start, options_length}] ->
        options = String.slice(content, options_start, options_length)

        new_options =
          cond do
            String.contains?(options, "hooks") ->
              String.replace(options, ~r/hooks:\s*[^,}]+/, "hooks: TableHooks")

            String.trim(options) == "" ->
              "hooks: TableHooks"

            true ->
              options <> ", hooks: TableHooks"
          end

        full_match = String.slice(content, match_start, match_length)
        new_match = String.replace(full_match, options, new_options)
        String.replace(content, full_match, new_match)

      _ ->
        content <>
          """

          // LiveTable: Could not automatically add hooks to LiveSocket
          // Please manually add hooks: TableHooks to your LiveSocket configuration:
          // let liveSocket = new LiveSocket("/live", Socket, {
          //   params: {_csrf_token: csrfToken},
          //   hooks: TableHooks
          // })
          """
    end
  end

  # assets/css/app.css

  defp configure_app_css(igniter) do
    path = "assets/css/app.css"

    case Igniter.exists?(igniter, path) do
      true ->
        igniter = Igniter.include_existing_file(igniter, path)
        content = igniter.rewrite |> Rewrite.source!(path) |> Rewrite.Source.get(:content)

        case String.contains?(content, "live-table.css") do
          true ->
            igniter

          false ->
            live_table_import = ~s|@import "../../deps/live_table/priv/static/live-table.css";|
            updated_content = add_css_import(content, live_table_import)

            igniter
            |> Igniter.update_file(path, fn source ->
              Rewrite.Source.update(source, :content, updated_content)
            end)
        end

      false ->
        Igniter.add_warning(igniter, "Could not find #{path}")
    end
  end

  defp add_css_import(content, import_line) do
    lines = String.split(content, "\n")

    case find_last_css_import_line(lines) do
      nil ->
        import_line <> "\n\n" <> content

      index when is_integer(index) ->
        {before, after_lines} = Enum.split(lines, index + 1)
        (before ++ [import_line] ++ after_lines) |> Enum.join("\n")
    end
  end

  defp find_last_css_import_line(lines) do
    lines
    |> Enum.with_index()
    |> Enum.filter(fn {line, _} -> String.match?(line, ~r/^\s*@import\s+/) end)
    |> case do
      [] -> nil
      imports -> imports |> List.last() |> elem(1)
    end
  end

  # web module static_paths
  # (no static paths modifications; reminder printed in final notices)

  # Oban integration helpers

  defp safe_add_oban_dep(igniter) do
    try do
      igniter
      |> Igniter.Project.Deps.add_dep({:oban, "~> 2.19"}, on_exists: :skip, yes?: true)
      |> Igniter.apply_and_fetch_dependencies(yes: true, fetch?: true)
    rescue
      _ ->
        Igniter.add_warning(
          igniter,
          "Could not modify mix.exs to add Oban. Please add {:oban, \"~> 2.19\"} manually and run mix deps.get"
        )
    end
  end

  defp oban_wanted?(igniter) do
    opts = igniter.args.options

    cond do
      Keyword.has_key?(opts, :oban) ->
        opts[:oban]

      # In auto-yes mode, do not prompt; default to no unless explicitly set
      opts[:yes] ->
        false

      # Prompt regardless of TTY so it can be covered in IO-captured tests
      true ->
        Igniter.Util.IO.yes?("Configure Oban for exports now?")
    end
  end

  defp maybe_configure_oban(igniter, app_module) do
    if oban_wanted?(igniter), do: configure_oban(igniter, app_module), else: igniter
  end

  defp configure_oban(igniter, app_module) do
    repo_module = Module.concat([app_module, "Repo"])

    app_atom =
      app_module
      |> Module.split()
      |> List.last()
      |> Macro.underscore()
      |> String.to_atom()

    oban_config = """
    config :#{app_atom}, Oban,
      repo: #{inspect(repo_module)},
      plugins: [Oban.Plugins.Pruner],
      queues: [exports: 10]
    """

    igniter
    |> safe_add_oban_dep()
    |> Igniter.include_or_create_file("config/config.exs", "import Config\n")
    |> Igniter.update_file("config/config.exs", fn source ->
      content = Rewrite.Source.get(source, :content)

      updated =
        if String.contains?(content, "config :#{app_atom}, Oban"),
          do: content,
          else: content <> "\n" <> oban_config <> "\n"

      Rewrite.Source.update(source, :content, updated)
    end)
  end

  defp oban_configured?(igniter, app_module) do
    app_atom =
      app_module
      |> Module.split()
      |> List.last()
      |> Macro.underscore()
      |> String.to_atom()

    igniter =
      if Igniter.exists?(igniter, "config/config.exs") do
        Igniter.include_existing_file(igniter, "config/config.exs")
      else
        igniter
      end

    case igniter.rewrite |> Rewrite.source("config/config.exs") do
      {:ok, source} ->
        content = Rewrite.Source.get(source, :content)
        String.contains?(content, "config :#{app_atom}, Oban")

      _ ->
        false
    end
  end

  defp add_oban_next_steps(igniter, app_module) do
    if oban_configured?(igniter, app_module) do
      app_atom =
        app_module
        |> Module.split()
        |> List.last()
        |> Macro.underscore()
        |> String.to_atom()

      igniter
      |> Igniter.add_notice("4. Start Oban by adding it to your supervision tree:")
      |> Igniter.add_notice(
        "   children = [..., {Oban, Application.fetch_env!(:#{app_atom}, Oban)}]"
      )
    else
      Igniter.add_notice(
        igniter,
        "4. Exports use Oban. To enable them later, configure Oban and add it to your supervision tree."
      )
    end
  end
end
