if Code.ensure_loaded?(Igniter.Mix.Task) do
  defmodule Mix.Tasks.LiveTable.Install do
    @moduledoc """
    Installs and configures LiveTable in your Phoenix application.

    Adds `:sutra_ui`, the recommended UI components. To use your own components
    instead, remove it and see the Custom Components guide.

    ## Usage

        $ mix live_table.install

    Adds `LiveTable.ExportPlug` to your router, which serves the table's exports.

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
        example: "mix live_table.install"
      }
    end

    @impl Igniter.Mix.Task
    def igniter(igniter) do
      app_name = Igniter.Project.Module.module_name_prefix(igniter)

      igniter
      |> configure_live_table(app_name)
      |> add_sutra_dep()
      |> add_export_route()
      |> add_notices()
    end

    defp configure_live_table(igniter, app_module) do
      if Igniter.Project.Config.configures_root_key?(igniter, "config/config.exs", :live_table) do
        igniter
      else
        repo = Module.concat([app_module, "Repo"])

        config = """
        config :live_table, repo: #{inspect(repo)}
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

    defp add_sutra_dep(igniter) do
      Igniter.Project.Deps.add_dep(igniter, {:sutra_ui, "~> 0.4.0"}, on_exists: :skip, yes?: true)
    rescue
      _ ->
        Igniter.add_warning(
          igniter,
          "Could not add Sutra UI. Please add {:sutra_ui, \"~> 0.4.0\"} manually."
        )
    end

    # Outside any pipeline: the link is authorised by the encrypted token it carries.
    defp add_export_route(igniter) do
      {igniter, router} = Igniter.Libs.Phoenix.select_router(igniter)

      if router && !export_route?(igniter, router) do
        Igniter.Libs.Phoenix.add_scope(
          igniter,
          "/",
          ~s(forward "/live_table/exports", LiveTable.ExportPlug),
          router: router
        )
      else
        igniter
      end
    end

    defp export_route?(igniter, router) do
      case Igniter.Project.Module.find_module(igniter, router) do
        {:ok, {_igniter, source, _zipper}} ->
          source |> Rewrite.Source.get(:content) |> String.contains?("LiveTable.ExportPlug")

        _ ->
          false
      end
    end

    defp add_notices(igniter) do
      igniter
      |> Igniter.add_notice("LiveTable has been successfully configured!")
      |> Igniter.add_notice("")
      |> Igniter.add_notice("Next steps:")
      |> Igniter.add_notice("1. Set up Sutra UI: mix sutra_ui.install")
      |> Igniter.add_notice(
        "   (or remove :sutra_ui and use your own components, see the Custom Components guide)"
      )
      |> Igniter.add_notice("2. Restart your Phoenix server")
      |> Igniter.add_notice("3. Create your first LiveTable by following the Quick Start guide")
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
