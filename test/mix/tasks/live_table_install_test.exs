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
      assert config_content =~ "config :live_table"
      assert config_content =~ "app: :test_app"
      assert config_content =~ "repo: TestApp.Repo"
      assert config_content =~ "pubsub: TestApp.PubSub"

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

      config :live_table,
        repo: TestApp.Repo,
        pubsub: TestApp.PubSub
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

    @tag :tmp_dir
    test "configures Oban when --oban flag is provided", %{tmp_dir: tmp_dir} do
      File.cd!(tmp_dir)
      setup_fake_phoenix_project()

      output =
        capture_io(fn ->
          Mix.Tasks.LiveTable.Install.run(["--yes", "--oban"])
        end)

      # Adds Oban config
      config_content = File.read!("config/config.exs")
      assert config_content =~ "config :test_app, Oban"
      assert config_content =~ "repo: TestApp.Repo"
      assert config_content =~ "queues: [exports: 10]"

      # Shows Oban start instruction
      assert output =~ "children = [..., {Oban, Application.fetch_env!(:test_app, Oban)}]"
    end

    @tag :tmp_dir
    test "does not configure Oban when not requested (non-interactive)", %{tmp_dir: tmp_dir} do
      File.cd!(tmp_dir)
      setup_fake_phoenix_project()

      _output =
        capture_io(fn ->
          Mix.Tasks.LiveTable.Install.run(["--yes"])
        end)

      config_content = File.read!("config/config.exs")
      refute config_content =~ "config :test_app, Oban"
    end
  end

  @tag :tmp_dir
  test "prompts and configures Oban when user answers yes", %{tmp_dir: tmp_dir} do
    File.cd!(tmp_dir)
    setup_fake_phoenix_project()

    output =
      capture_io("y\ny\n", fn ->
        Mix.Tasks.LiveTable.Install.run([])
      end)

    # Adds Oban config
    config_content = File.read!("config/config.exs")
    assert config_content =~ "config :test_app, Oban"
    assert config_content =~ "repo: TestApp.Repo"
    assert config_content =~ "queues: [exports: 10]"

    # Shows Oban start instruction
    assert output =~ "children = [..., {Oban, Application.fetch_env!(:test_app, Oban)}]"
  end

  @tag :tmp_dir
  test "prompts and does not configure Oban when user answers no", %{tmp_dir: tmp_dir} do
    File.cd!(tmp_dir)
    setup_fake_phoenix_project()

    _output =
      capture_io("n\ny\n", fn ->
        Mix.Tasks.LiveTable.Install.run([])
      end)

    config_content = File.read!("config/config.exs")
    refute config_content =~ "config :test_app, Oban"
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
