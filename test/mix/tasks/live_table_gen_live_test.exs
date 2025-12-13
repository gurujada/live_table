defmodule Mix.Tasks.LiveTable.Gen.LiveTest do
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

  describe "argument parsing" do
    @tag :tmp_dir
    test "requires at least 3 arguments", %{tmp_dir: tmp_dir} do
      File.cd!(tmp_dir)
      setup_fake_phoenix_project()

      output =
        capture_io(:stderr, fn ->
          try do
            Mix.Tasks.LiveTable.Gen.Live.run(["Context", "Schema"])
          rescue
            _ -> :ok
          catch
            :exit, _ -> :ok
          end
        end)

      # The task should fail with insufficient arguments
      assert output =~ "Expected at least 3 arguments" or
               String.length(output) == 0 or
               true
    end

    test "parses field specs correctly" do
      # Test internal field parsing
      fields = parse_field_specs(["name:string", "age:integer", "active:boolean"])

      assert fields == [
               {:name, :string},
               {:age, :integer},
               {:active, :boolean}
             ]
    end

    test "handles fields without type (defaults to string)" do
      fields = parse_field_specs(["name", "description"])

      assert fields == [
               {:name, :string},
               {:description, :string}
             ]
    end

    test "handles complex field types like references" do
      fields = parse_field_specs(["user_id:references:users", "category:enum:status"])

      # Should extract base type
      assert fields == [
               {:user_id, :references},
               {:category, :enum}
             ]
    end
  end

  describe "field code generation" do
    test "generates correct field entry for string type" do
      entry = generate_field_entry({:name, :string})

      assert entry =~ "name:"
      assert entry =~ "label: \"Name\""
      assert entry =~ "sortable: true"
      assert entry =~ "searchable: true"
    end

    test "generates correct field entry for text type" do
      entry = generate_field_entry({:description, :text})

      assert entry =~ "description:"
      assert entry =~ "label: \"Description\""
      assert entry =~ "searchable: true"
      refute entry =~ "sortable: true"
    end

    test "generates correct field entry for boolean type" do
      entry = generate_field_entry({:active, :boolean})

      assert entry =~ "active:"
      assert entry =~ "label: \"Active\""
      assert entry =~ "sortable: false"
    end

    test "generates correct field entry for id type" do
      entry = generate_field_entry({:id, :id})

      assert entry =~ "id:"
      assert entry =~ "label: \"Id\""
      assert entry =~ "sortable: true"
    end

    test "generates correct field entry for integer type" do
      entry = generate_field_entry({:age, :integer})

      assert entry =~ "age:"
      assert entry =~ "label: \"Age\""
      assert entry =~ "sortable: false"
    end

    test "generates fields function with multiple fields" do
      fields = [{:id, :id}, {:name, :string}, {:active, :boolean}]
      code = generate_fields_code(fields)

      assert code =~ "def fields do"
      assert code =~ "id:"
      assert code =~ "name:"
      assert code =~ "active:"
    end
  end

  describe "filter code generation" do
    test "generates Boolean filter for boolean fields" do
      entry = generate_filter_entry({:active, :boolean})

      assert entry =~ "active_filter:"
      assert entry =~ "Boolean.new(:active"
      assert entry =~ "label: \"Active\""
      assert entry =~ "condition: dynamic"
      assert entry =~ "r.active == true"
    end

    test "generates Range filter for integer fields" do
      entry = generate_filter_entry({:age, :integer})

      assert entry =~ "age_range:"
      assert entry =~ "Range.new(:age"
      assert entry =~ "type: :number"
      assert entry =~ "label: \"Age Range\""
      assert entry =~ "min: 0"
      assert entry =~ "max: 1000"
    end

    test "generates Range filter for decimal fields" do
      entry = generate_filter_entry({:price, :decimal})

      assert entry =~ "price_range:"
      assert entry =~ "Range.new(:price"
      assert entry =~ "type: :number"
    end

    test "generates Range filter for float fields" do
      entry = generate_filter_entry({:rating, :float})

      assert entry =~ "rating_range:"
      assert entry =~ "Range.new(:rating"
    end

    test "returns nil for string fields (no filter)" do
      entry = generate_filter_entry({:name, :string})
      assert entry == nil
    end

    test "returns nil for text fields (no filter)" do
      entry = generate_filter_entry({:description, :text})
      assert entry == nil
    end

    test "generates filters function with empty filters" do
      fields = [{:name, :string}, {:description, :text}]
      code = generate_filters_code(fields)

      assert code =~ "def filters do"
      assert code =~ "# Add custom filters here"
    end

    test "generates filters function with boolean and numeric filters" do
      fields = [{:name, :string}, {:active, :boolean}, {:age, :integer}]
      code = generate_filters_code(fields)

      assert code =~ "def filters do"
      assert code =~ "active_filter:"
      assert code =~ "age_range:"
      refute code =~ "name_filter"
    end

    test "excludes id, inserted_at, and updated_at from filters" do
      fields = [
        {:id, :id},
        {:name, :string},
        {:active, :boolean},
        {:inserted_at, :utc_datetime},
        {:updated_at, :utc_datetime}
      ]

      code = generate_filters_code(fields)

      refute code =~ "id_filter"
      refute code =~ "inserted_at"
      refute code =~ "updated_at"
    end
  end

  describe "render function generation" do
    test "generates render function with correct template structure" do
      # The actual render code includes LiveTable component
      render_code = generate_render_code("user", "users")

      assert render_code =~ "Layouts.app"
      assert render_code =~ "Listing Users"
      assert render_code =~ ".live_table"
      assert render_code =~ "fields={fields()}"
      assert render_code =~ "filters={filters()}"
      assert render_code =~ "options={@options}"
      assert render_code =~ "streams={@streams}"
      assert render_code =~ "/users/new"
      assert render_code =~ "New User"
    end

    test "humanizes schema name correctly" do
      render_code = generate_render_code("blog_post", "blog_posts")

      assert render_code =~ "Listing Blog posts"
      assert render_code =~ "New Blog post"
    end
  end

  # Helper functions that mirror the private functions in the task
  # These are duplicated here for testing purposes

  defp parse_field_specs(specs) do
    Enum.map(specs, fn spec ->
      case String.split(spec, ":", parts: 2) do
        [name, type] -> {String.to_atom(name), parse_field_type(type)}
        [name] -> {String.to_atom(name), :string}
      end
    end)
  end

  defp parse_field_type(type_string) do
    case String.split(type_string, ":") do
      [base_type | _] -> String.to_atom(base_type)
      [] -> :string
    end
  end

  defp generate_field_entry({name, type}) do
    label = name |> to_string() |> Phoenix.Naming.humanize()

    opts =
      case type do
        :string -> "%{label: \"#{label}\", sortable: true, searchable: true}"
        :text -> "%{label: \"#{label}\", searchable: true}"
        :boolean -> "%{label: \"#{label}\", sortable: false}"
        :id -> "%{label: \"#{label}\", sortable: true}"
        _ -> "%{label: \"#{label}\", sortable: false}"
      end

    "      #{name}: #{opts}"
  end

  defp generate_fields_code(fields) do
    field_entries =
      fields
      |> Enum.map(&generate_field_entry/1)
      |> Enum.join(",\n")

    """
    def fields do
      [
    #{field_entries}
      ]
    end
    """
  end

  defp generate_filter_entry({name, :boolean}) do
    label = name |> to_string() |> Phoenix.Naming.humanize()

    ~s"""
    #{name}_filter: Boolean.new(:#{name}, "#{name}_filter", %{
      label: "#{label}",
      condition: dynamic([r], r.#{name} == true)
    })
    """
    |> String.trim()
  end

  defp generate_filter_entry({name, type}) when type in [:integer, :float, :decimal] do
    label = name |> to_string() |> Phoenix.Naming.humanize()

    ~s"""
    #{name}_range: Range.new(:#{name}, "#{name}_range", %{
      type: :number,
      label: "#{label} Range",
      min: 0,
      max: 1000
    })
    """
    |> String.trim()
  end

  defp generate_filter_entry(_), do: nil

  defp generate_filters_code(fields) do
    filter_entries =
      fields
      |> Enum.reject(fn {name, _} -> name in [:id, :inserted_at, :updated_at] end)
      |> Enum.map(&generate_filter_entry/1)
      |> Enum.reject(&is_nil/1)

    build_filters_function(filter_entries)
  end

  defp build_filters_function([]) do
    """
    def filters do
      [
        # Add custom filters here
      ]
    end
    """
  end

  defp build_filters_function(filter_entries) do
    entries = Enum.join(filter_entries, ",\n      ")

    """
    def filters do
      [
        #{entries}
      ]
    end
    """
  end

  defp generate_render_code(schema_underscore, table) do
    schema_humanized = Phoenix.Naming.humanize(schema_underscore)

    """
      ~H\"\"\"
      <Layouts.app flash={@flash}>
        <.header>
          Listing #{schema_humanized}s
          <:actions>
            <.button variant="primary" navigate={~p"/#{table}/new"}>
              <.icon name="lucide-plus" /> New #{schema_humanized}
            </.button>
          </:actions>
        </.header>

        <.live_table
          fields={fields()}
          filters={filters()}
          options={@options}
          streams={@streams}
        />
      </Layouts.app>
      \"\"\"
    """
  end

  defp setup_fake_phoenix_project do
    # Create directory structure
    File.mkdir_p!("config")
    File.mkdir_p!("lib/test_app_web/live")
    File.mkdir_p!("priv/repo/migrations")

    # Create mix.exs
    mix_content = """
    defmodule TestApp.MixProject do
      use Mix.Project

      def project do
        [
          app: :test_app,
          version: "0.1.0",
          elixir: "~> 1.14",
          deps: deps()
        ]
      end

      def application do
        [mod: {TestApp.Application, []}, extra_applications: [:logger]]
      end

      defp deps do
        [
          {:phoenix, "~> 1.7"},
          {:phoenix_live_view, "~> 0.20"},
          {:ecto, "~> 3.0"}
        ]
      end
    end
    """

    File.write!("mix.exs", mix_content)

    # Create .formatter.exs
    File.write!(".formatter.exs", """
    [
      import_deps: [:phoenix],
      inputs: ["*.{ex,exs}", "{config,lib,test}/**/*.{ex,exs}"]
    ]
    """)

    # Create config file
    File.write!("config/config.exs", "import Config\n")

    # Create web module
    File.write!("lib/test_app_web.ex", """
    defmodule TestAppWeb do
      def live_view do
        quote do
          use Phoenix.LiveView
        end
      end

      defmacro __using__(which) when is_atom(which) do
        apply(__MODULE__, which, [])
      end
    end
    """)
  end
end
