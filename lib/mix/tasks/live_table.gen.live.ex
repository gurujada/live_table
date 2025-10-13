defmodule Mix.Tasks.LiveTable.Gen.Live do
  @moduledoc """
  Generates LiveView files with interactive data tables.

  Creates the same files as `phx.gen.live` but replaces the basic table with an
  interactive LiveTable component featuring sorting, searching, and filtering.

  ## Usage

      $ mix live_table.gen.live Context Schema table_name field:type field:type

  ## Example

      $ mix live_table.gen.live Accounts User users name:string email:string age:integer active:boolean

  ## What You Get

  Your index page will automatically include:

  - **Sortable columns** - Click headers to sort by any field
  - **Search functionality** - Search across text fields
  - **Smart filtering** - Boolean toggles and numeric ranges
  - **Responsive design** - Works on mobile and desktop
  - **Real-time updates** - Live updates without page refresh

  ## Field Behavior

  Different field types get different capabilities:
  - **String fields** → Searchable and sortable
  - **Text fields** → Searchable (too long to sort effectively)
  - **Boolean fields** → Filterable with true/false toggle
  - **Numeric fields** → Filterable with min/max range sliders
  - **ID fields** → Sortable only

  ## Arguments

  Same as `phx.gen.live`:
  - Context: Business domain (e.g., Accounts, Blog)
  - Schema: Data model (e.g., User, Post)
  - table_name: Database table (e.g., users, posts)
  - fields: Field definitions (e.g., name:string email:string)

  ## Next Steps

  After running this command:
  1. Run `mix ecto.migrate` to create the database table
  2. Start your server and visit the generated routes
  3. Customize field configurations and filters as needed
  """

  use Igniter.Mix.Task

  @shortdoc "Generates LiveView files with LiveTable integration"

  @impl Igniter.Mix.Task
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      group: :live_table,
      example: "mix live_table.gen.live Accounts User users name:string email:string",
      positional: [:context, :schema, :table],
      schema: []
    }
  end

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    argv = igniter.args.argv

    case parse_args(argv) do
      {:ok, context, schema, table, fields} ->
        Mix.Task.run("phx.gen.live", argv)
        all_fields = [{:id, :id} | fields]
        igniter = %{igniter | assigns: Map.put(igniter.assigns, :yes_to_all?, true)}

        igniter
        |> enhance_index_live(context, schema, table, all_fields)
        |> Igniter.add_notice("LiveTable resource generated successfully!")
        |> Igniter.add_notice("Next steps:")
        |> Igniter.add_notice("1. Run migrations: mix ecto.migrate")
        |> Igniter.add_notice("2. Start your server and visit the generated routes")

      {:error, reason} ->
        Igniter.add_issue(igniter, reason)
    end
  end

  defp parse_args(argv) when length(argv) < 3 do
    {:error, "Expected at least 3 arguments: Context Schema table_name [field:type ...]"}
  end

  defp parse_args([context, schema, table | field_specs]) do
    fields = parse_field_specs(field_specs)
    {:ok, context, schema, table, fields}
  end

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

  defp enhance_index_live(igniter, context, schema, table, fields) do
    app = Igniter.Project.Application.app_name(igniter)
    app_module = app |> to_string() |> Macro.camelize() |> String.to_atom()
    schema_module = Module.concat([app_module, String.to_atom(context), String.to_atom(schema)])
    web_module = :"#{app_module}Web"
    index_module = Module.concat([web_module, :"#{schema}Live", :Index])
    app_name = app |> to_string() |> Macro.underscore()
    schema_underscore = schema |> to_string() |> Macro.underscore()
    index_path = "lib/#{app_name}_web/live/#{schema_underscore}_live/index.ex"

    igniter
    |> Igniter.include_existing_file(index_path)
    |> then(fn igniter ->
      case Igniter.Project.Module.find_and_update_module(igniter, index_module, fn zipper ->
             with {:ok, zipper} <- add_live_resource_use(zipper, schema_module),
                  {:ok, zipper} <- add_fields_function(zipper, fields),
                  {:ok, zipper} <- add_filters_function(zipper, fields),
                  {:ok, zipper} <- replace_render_function(zipper, schema_underscore, table) do
               {:ok, zipper}
             end
           end) do
        {:ok, igniter} ->
          igniter

        {:error, igniter} ->
          Igniter.add_warning(igniter, "Could not find or update module #{inspect(index_module)}")
      end
    end)
  end

  defp add_live_resource_use(zipper, schema_module) do
    has_live_resource? =
      zipper
      |> Sourceror.Zipper.traverse(false, fn node, acc ->
        case node do
          %Sourceror.Zipper{node: {:use, _, [{:__aliases__, _, [:LiveTable, :LiveResource]} | _]}} ->
            {node, true}

          _ ->
            {node, acc}
        end
      end)
      |> elem(1)

    if has_live_resource? do
      {:ok, zipper}
    else
      case find_liveview_use_statement(zipper) do
        {:ok, liveview_use_zipper} ->
          use_statement = "use LiveTable.LiveResource, schema: #{inspect(schema_module)}"
          {:ok, ast} = Code.string_to_quoted(use_statement)
          {:ok, Sourceror.Zipper.insert_right(liveview_use_zipper, ast)}

        :error ->
          use_statement = "use LiveTable.LiveResource, schema: #{inspect(schema_module)}"
          {:ok, ast} = Code.string_to_quoted(use_statement)
          {:ok, Sourceror.Zipper.insert_child(zipper, ast)}
      end
    end
  end

  defp find_liveview_use_statement(zipper) do
    zipper
    |> Sourceror.Zipper.find(fn
      %Sourceror.Zipper{node: {:use, _, args}} ->
        Enum.any?(args, fn
          :live_view -> true
          _ -> false
        end)

      _ ->
        false
    end)
    |> case do
      nil -> :error
      zipper -> {:ok, zipper}
    end
  end

  defp add_fields_function(zipper, fields) do
    fields_code = generate_fields_code(fields)

    case Igniter.Code.Function.move_to_def(zipper, :fields, 0) do
      {:ok, func_zipper} ->
        {:ok, ast} = Code.string_to_quoted(fields_code)
        {:ok, Sourceror.Zipper.replace(func_zipper, ast)}

      :error ->
        {:ok, ast} = Code.string_to_quoted(fields_code)
        insert_after_last_impl(zipper, ast)
    end
  end

  defp insert_after_last_impl(zipper, ast) do
    case find_last_impl_function(zipper) do
      {:ok, impl_zipper} ->
        {:ok, Sourceror.Zipper.insert_right(impl_zipper, ast)}

      :error ->
        {:ok, Igniter.Code.Common.add_code(zipper, ast)}
    end
  end

  defp add_filters_function(zipper, fields) do
    filters_code = generate_filters_code(fields)

    case Igniter.Code.Function.move_to_def(zipper, :filters, 0) do
      {:ok, func_zipper} ->
        {:ok, ast} = Code.string_to_quoted(filters_code)
        {:ok, Sourceror.Zipper.replace(func_zipper, ast)}

      :error ->
        case Igniter.Code.Function.move_to_def(zipper, :fields, 0) do
          {:ok, fields_zipper} ->
            {:ok, ast} = Code.string_to_quoted(filters_code)
            {:ok, Sourceror.Zipper.insert_right(fields_zipper, ast)}

          :error ->
            {:ok, ast} = Code.string_to_quoted(filters_code)
            insert_after_last_impl(zipper, ast)
        end
    end
  end

  defp find_last_impl_function(zipper) do
    {_final_zipper, last_impl} =
      zipper
      |> Sourceror.Zipper.traverse(nil, fn node, acc ->
        case node do
          %Sourceror.Zipper{node: {:def, meta, _}} ->
            if Keyword.get(meta, :impl) == true do
              {node, node}
            else
              {node, acc}
            end

          _ ->
            {node, acc}
        end
      end)

    case last_impl do
      nil -> :error
      zipper -> {:ok, zipper}
    end
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

  defp generate_field_entry({name, type}) do
    label = name |> to_string() |> Phoenix.Naming.humanize()

    opts =
      case type do
        :string -> "%{label: \"#{label}\", sortable: true, searchable: true}"
        :text -> "%{label: \"#{label}\", searchable: true}"
        :boolean -> "%{label: \"#{label}\"}"
        :id -> "%{label: \"#{label}\", sortable: true}"
        _ -> "%{label: \"#{label}\", sortable: false}"
      end

    "      #{name}: #{opts}"
  end

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

  defp replace_render_function(zipper, schema_underscore, table) do
    schema_humanized = Phoenix.Naming.humanize(schema_underscore)

    render_code = """
      ~H\"\"\"
      <Layouts.app flash={@flash}>
        <.header>
          Listing #{schema_humanized}s
          <:actions>
            <.button variant="primary" navigate={~p"/#{table}/new"}>
              <.icon name="hero-plus" /> New #{schema_humanized}
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

    case Igniter.Code.Function.move_to_def(zipper, :render, 1) do
      {:ok, func_zipper} ->
        {:ok, ast} = Code.string_to_quoted(render_code)
        {:ok, Sourceror.Zipper.replace(func_zipper, ast)}

      :error ->
        case find_last_use_or_alias(zipper) do
          {:ok, use_alias_zipper} ->
            {:ok, ast} = Code.string_to_quoted(render_code)
            {:ok, Sourceror.Zipper.insert_right(use_alias_zipper, ast)}

          :error ->
            {:ok, ast} = Code.string_to_quoted(render_code)
            {:ok, Igniter.Code.Common.add_code(zipper, ast)}
        end
    end
  end

  defp find_last_use_or_alias(zipper) do
    {_final_zipper, last_use_or_alias} =
      zipper
      |> Sourceror.Zipper.traverse(nil, fn node, acc ->
        case node do
          %Sourceror.Zipper{node: {:use, _, _}} -> {node, node}
          %Sourceror.Zipper{node: {:alias, _, _}} -> {node, node}
          _ -> {node, acc}
        end
      end)

    case last_use_or_alias do
      nil -> :error
      zipper -> {:ok, zipper}
    end
  end
end
