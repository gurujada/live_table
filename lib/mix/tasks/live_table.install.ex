if Code.ensure_loaded?(Igniter.Mix.Task) do
  defmodule Mix.Tasks.LiveTable.Install do
    @moduledoc """
    Installs and configures LiveTable in your Phoenix application.

    ## Usage

        $ mix live_table.install

    With Oban for exports:

        $ mix live_table.install --oban

    ## Requirements

    This task requires the `:igniter` dependency:

        {:igniter, "~> 0.7", only: :dev, runtime: false}

    For manual installation without Igniter, see:
    https://hexdocs.pm/live_table/installation.html
    """

    use Igniter.Mix.Task

    @shortdoc "Installs and configures LiveTable in your Phoenix application"

    @impl Igniter.Mix.Task
    def info(_argv, _composing_task) do
      %Igniter.Mix.Task.Info{
        group: :live_table,
        example: "mix live_table.install",
        schema: [oban: :boolean]
      }
    end

    @impl Igniter.Mix.Task
    def igniter(igniter) do
      app_name = Igniter.Project.Module.module_name_prefix(igniter)

      igniter
      |> configure_live_table(app_name)
      |> maybe_configure_oban(app_name)
      |> add_notices(app_name)
    end

    defp configure_live_table(igniter, app_module) do
      if Igniter.Project.Config.configures_root_key?(igniter, "config/config.exs", :live_table) do
        igniter
      else
        repo = Module.concat([app_module, "Repo"])
        pubsub = Module.concat([app_module, "PubSub"])

        app_atom =
          app_module |> Module.split() |> List.last() |> Macro.underscore() |> String.to_atom()

        config = """
        config :live_table,
          app: #{inspect(app_atom)},
          repo: #{inspect(repo)},
          pubsub: #{inspect(pubsub)}
        """

        igniter
        |> Igniter.include_or_create_file("config/config.exs", "import Config\n")
        |> Igniter.update_file("config/config.exs", fn source ->
          content = Rewrite.Source.get(source, :content)

          if Regex.match?(~r/config\s+:live_table\b/, content) do
            source
          else
            Rewrite.Source.update(source, :content, content <> "\n" <> config <> "\n")
          end
        end)
      end
    end

    defp maybe_configure_oban(igniter, app_module) do
      if oban_wanted?(igniter) do
        configure_oban(igniter, app_module)
      else
        igniter
      end
    end

    defp oban_wanted?(igniter) do
      opts = igniter.args.options

      cond do
        Keyword.has_key?(opts, :oban) -> opts[:oban]
        opts[:yes] -> false
        true -> Igniter.Util.IO.yes?("Configure Oban for exports now?")
      end
    end

    defp configure_oban(igniter, app_module) do
      repo = Module.concat([app_module, "Repo"])

      app_atom =
        app_module |> Module.split() |> List.last() |> Macro.underscore() |> String.to_atom()

      config = """
      config :#{app_atom}, Oban,
        repo: #{inspect(repo)},
        plugins: [Oban.Plugins.Pruner],
        queues: [exports: 10]
      """

      igniter
      |> safe_add_oban_dep()
      |> Igniter.include_or_create_file("config/config.exs", "import Config\n")
      |> Igniter.update_file("config/config.exs", fn source ->
        content = Rewrite.Source.get(source, :content)

        if String.contains?(content, "config :#{app_atom}, Oban") do
          source
        else
          Rewrite.Source.update(source, :content, content <> "\n" <> config <> "\n")
        end
      end)
    end

    defp safe_add_oban_dep(igniter) do
      igniter
      |> Igniter.Project.Deps.add_dep({:oban, "~> 2.19"}, on_exists: :skip, yes?: true)
      |> Igniter.apply_and_fetch_dependencies(yes: true, fetch?: true)
    rescue
      _ ->
        Igniter.add_warning(
          igniter,
          "Could not add Oban. Please add {:oban, \"~> 2.19\"} manually."
        )
    end

    defp add_notices(igniter, app_module) do
      igniter
      |> Igniter.add_notice("LiveTable has been successfully configured!")
      |> Igniter.add_notice("")
      |> Igniter.add_notice("Next steps:")
      |> Igniter.add_notice("1. Restart your Phoenix server")
      |> Igniter.add_notice("2. Create your first LiveTable by following the Quick Start guide")
      |> maybe_add_oban_notice(app_module)
    end

    defp maybe_add_oban_notice(igniter, app_module) do
      app_atom =
        app_module |> Module.split() |> List.last() |> Macro.underscore() |> String.to_atom()

      if oban_configured?(igniter, app_atom) do
        igniter
        |> Igniter.add_notice("3. Start Oban by adding it to your supervision tree:")
        |> Igniter.add_notice(
          "   children = [..., {Oban, Application.fetch_env!(:#{app_atom}, Oban)}]"
        )
      else
        igniter
      end
    end

    defp oban_configured?(igniter, app_atom) do
      case Rewrite.source(igniter.rewrite, "config/config.exs") do
        {:ok, source} ->
          source |> Rewrite.Source.get(:content) |> String.contains?("config :#{app_atom}, Oban")

        _ ->
          false
      end
    end
  end
else
  defmodule Mix.Tasks.LiveTable.Install do
    @moduledoc """
    Installs and configures LiveTable in your Phoenix application.

    Requires the `:igniter` dependency. Add to your mix.exs:

        {:igniter, "~> 0.7", only: :dev, runtime: false}

    Then run `mix deps.get` and retry.

    For manual installation, see: https://hexdocs.pm/live_table/installation.html
    """

    use Mix.Task

    @shortdoc "Installs and configures LiveTable (requires :igniter)"

    @impl Mix.Task
    def run(_argv) do
      Mix.raise("""
      mix live_table.install requires the :igniter dependency.

      Add to your mix.exs:

          {:igniter, "~> 0.7", only: :dev, runtime: false}

      Then run:

          mix deps.get
          mix live_table.install

      Or configure manually: https://hexdocs.pm/live_table/installation.html
      """)
    end
  end
end
