defmodule Mix.Tasks.LiveTable.Install do
  @moduledoc """
  Installs and configures LiveTable in your Phoenix application.

  This task configures all necessary files for LiveTable to work properly:
  - Adds LiveTable configuration to config/config.exs
  - Optionally configures Oban for CSV/PDF exports

  ## Usage

      $ mix live_table.install

  With Oban for exports:

      $ mix live_table.install --oban

  This task assumes LiveTable dependency is already added to mix.exs.

  ## Runtime Hooks

  LiveTable uses Phoenix 1.8+ runtime colocated hooks which require no JavaScript
  configuration. The hooks are automatically registered when components render.
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
    |> maybe_configure_oban(app_name)
    |> Igniter.add_notice("LiveTable has been successfully configured!")
    |> Igniter.add_notice("")
    |> Igniter.add_notice("Next steps:")
    |> Igniter.add_notice("1. Restart your Phoenix server")
    |> Igniter.add_notice("2. Create your first LiveTable by following the Quick Start guide")
    |> add_oban_next_steps(app_name)
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
          app: #{inspect(app_atom)},
          repo: #{inspect(repo_module)},
          pubsub: #{inspect(pubsub_module)}
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
      |> Igniter.add_notice("3. Start Oban by adding it to your supervision tree:")
      |> Igniter.add_notice(
        "   children = [..., {Oban, Application.fetch_env!(:#{app_atom}, Oban)}]"
      )
    else
      igniter
    end
  end
end
