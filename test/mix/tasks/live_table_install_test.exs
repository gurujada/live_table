defmodule Mix.Tasks.LiveTable.InstallTest do
  use ExUnit.Case
  import ExUnit.CaptureIO

  @moduletag :tmp_dir

  setup do
    # Store original directory
    original_dir = File.cwd!()

    on_exit(fn ->
      File.cd!(original_dir)
    end)

    :ok
  end

  describe "mix live_table.install" do
    test "adds Sutra UI and says how to set it up" do
      igniter =
        Igniter.Test.phx_test_project()
        |> Igniter.compose_task("live_table.install", ["--yes"])

      mix_exs = igniter.rewrite |> Rewrite.source!("mix.exs") |> Rewrite.Source.get(:content)
      assert mix_exs =~ ~s({:sutra_ui, "~> 0.4.0"})
      assert mix_exs =~ ~s({:typst, "~> 0.4.4"})

      Igniter.Test.assert_has_notice(igniter, &(&1 =~ "mix sutra_ui.install"))
    end

    test "adds LiveTable to the paths Tailwind scans, once" do
      igniter =
        Igniter.Test.phx_test_project()
        |> Igniter.compose_task("live_table.install", ["--yes"])
        |> Igniter.compose_task("live_table.install", ["--yes"])

      css =
        igniter.rewrite
        |> Rewrite.source!("assets/css/app.css")
        |> Rewrite.Source.get(:content)

      assert css =~
               ~s|@import "tailwindcss" source(none);\n@source "../../deps/live_table/lib";\n|

      assert css |> String.split("deps/live_table") |> length() == 2
    end

    test "forwards exports to LiveTable.ExportPlug in the router, once" do
      igniter =
        Igniter.Test.phx_test_project()
        |> Igniter.compose_task("live_table.install", ["--yes"])
        |> Igniter.compose_task("live_table.install", ["--yes"])

      router =
        igniter.rewrite
        |> Rewrite.source!("lib/test_web/router.ex")
        |> Rewrite.Source.get(:content)

      assert router =~ ~s(forward "/live_table/exports", LiveTable.ExportPlug)
      assert router |> String.split("LiveTable.ExportPlug") |> length() == 2
    end

    @tag :tmp_dir
    test "installs LiveTable configuration successfully", %{tmp_dir: tmp_dir} do
      # Setup a fake Phoenix project structure
      File.cd!(tmp_dir)
      setup_fake_phoenix_project()

      # Run the install task
      output =
        capture_io(fn ->
          Mix.Tasks.LiveTable.Install.run(["--yes"])
        end)

      # Verify success message is in notices
      assert output =~ "LiveTable has been successfully configured!"

      # Verify config file was updated
      config_content = File.read!("config/config.exs")
      assert config_content =~ "config :live_table, repo: TestApp.Repo"

      # Note: Phoenix 1.8+ uses runtime colocated hooks, so app.js is NOT modified.
      # The hooks are automatically registered when components render.
    end

    @tag :tmp_dir
    test "handles missing assets directory gracefully", %{tmp_dir: tmp_dir} do
      File.cd!(tmp_dir)

      # Create minimal project structure without assets
      File.mkdir_p!("config")
      File.mkdir_p!("lib")
      create_mix_exs()
      create_formatter_exs()
      File.write!("config/config.exs", "import Config\n# Config file\n")

      # Create web module so it can be found
      web_content = """
      defmodule TestAppWeb do
        def static_paths, do: ~w(assets fonts images favicon.ico robots.txt)
      end
      """

      File.write!("lib/test_app_web.ex", web_content)

      # Task should still succeed since it no longer modifies app.js
      # (Phoenix 1.8+ uses runtime colocated hooks)
      output =
        capture_io(fn ->
          Mix.Tasks.LiveTable.Install.run(["--yes"])
        end)

      # Should complete successfully
      assert output =~ "LiveTable has been successfully configured!"
    end

    @tag :tmp_dir
    test "detects existing configuration and skips duplicate setup", %{tmp_dir: tmp_dir} do
      File.cd!(tmp_dir)
      setup_fake_phoenix_project()

      # Add existing LiveTable config
      existing_config = """
      import Config

      config :live_table, repo: TestApp.Repo
      """

      File.write!("config/config.exs", existing_config)

      output =
        capture_io(fn ->
          Mix.Tasks.LiveTable.Install.run(["--yes"])
        end)

      # The task should complete successfully
      assert output =~ "LiveTable has been successfully configured!"

      # Verify config wasn't duplicated
      config_content = File.read!("config/config.exs")
      # Count occurrences of config :live_table - should be exactly 1
      occurrences =
        config_content |> String.split("config :live_table") |> length() |> Kernel.-(1)

      assert occurrences == 1
    end
  end

  defp setup_fake_phoenix_project do
    # Create directory structure
    File.mkdir_p!("config")
    File.mkdir_p!("assets/js")
    File.mkdir_p!("assets/css")
    File.mkdir_p!("lib")

    # Create mix.exs
    create_mix_exs()

    # Create .formatter.exs (required for Igniter)
    create_formatter_exs()

    # Create config file
    File.write!("config/config.exs", "import Config\n\n# Configuration file\n")

    # Create app.js
    app_js_content = """
    import {Socket} from "phoenix"
    import {LiveSocket} from "phoenix_live_view"
    import topbar from "../vendor/topbar"

    let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
    let liveSocket = new LiveSocket("/live", Socket, {params: {_csrf_token: csrfToken}})

    liveSocket.connect()
    """

    File.write!("assets/js/app.js", app_js_content)

    # Create app.css
    app_css_content = """
    @import "tailwindcss/base";
    @import "tailwindcss/components";
    @import "tailwindcss/utilities";
    """

    File.write!("assets/css/app.css", app_css_content)

    # Create web module
    web_content = """
    defmodule TestAppWeb do
      def static_paths, do: ~w(assets fonts images favicon.ico robots.txt)
    end
    """

    File.write!("lib/test_app_web.ex", web_content)
  end

  defp create_mix_exs do
    mix_content = """
    defmodule TestApp.MixProject do
      use Mix.Project

      def project do
        [
          app: :test_app,
          version: "0.1.0"
        ]
      end
    end
    """

    File.write!("mix.exs", mix_content)
  end

  defp create_formatter_exs do
    formatter_content = """
    [
      import_deps: [:phoenix],
      inputs: ["*.{ex,exs}", "{config,lib,test}/**/*.{ex,exs}"]
    ]
    """

    File.write!(".formatter.exs", formatter_content)
  end
end
