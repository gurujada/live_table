defmodule LiveTable.LiveResource do
  @moduledoc false
  alias LiveTable.{
    Filter,
    Join,
    Paginate,
    Sorting,
    Helpers,
    TableComponent,
    TableConfig,
    Transformer
  }

  defmacro __using__(opts) do
    quote do
      import Ecto.Query
      import Sorting
      import Paginate
      import Join
      import Filter
      import Transformer

      use Helpers,
        schema: unquote(opts[:schema]),
        table_options: TableConfig.get_table_options(table_options())

      use TableComponent, table_options: TableConfig.get_table_options(table_options())

      alias LiveTable.{Boolean, Select, Range, Custom, Transformer}

      @resource_opts unquote(opts)
      @repo Application.compile_env(:live_table, :repo)

      def fields, do: []
      def filters, do: []

      def table_options(), do: %{}

      defoverridable fields: 0, filters: 0, table_options: 0

      def list_resources(fields, options, _, {module, function, args} = data_provider)
          when is_atom(function) do
        {regular_filters, transformers} =
          Map.get(options, "filters", nil)
          |> separate_filters_and_transformers()

        apply(module, function, args)
        |> join_associations(regular_filters)
        |> apply_filters(regular_filters, fields)
        |> maybe_sort(fields, options["sort"]["sort_params"], options["sort"]["sortable?"])
        |> apply_transformers(transformers)
        |> maybe_paginate(options["pagination"], options["pagination"]["paginate?"])
      end

      def list_resources(fields, options, schema, nil) do
        {regular_filters, transformers} =
          Map.get(options, "filters", nil)
          |> separate_filters_and_transformers()

        schema
        |> from(as: :resource)
        |> join_associations(regular_filters)
        |> select_columns(fields)
        |> apply_filters(regular_filters, fields)
        |> maybe_sort(fields, options["sort"]["sort_params"], options["sort"]["sortable?"])
        |> apply_transformers(transformers)
        
        |> maybe_paginate(options["pagination"], options["pagination"]["paginate?"])
      end

      def stream_resources(fields, %{"pagination" => %{"paginate?" => true}} = options, nil) do
        per_page = options["pagination"]["per_page"] |> String.to_integer()

        schema = @resource_opts[:schema]

        list_resources(fields, options, schema, nil)
        |> @repo.all()
        |> Enum.split(per_page)
      end

      def stream_resources(fields, %{"pagination" => %{"paginate?" => false}} = options, nil) do
        schema = @resource_opts[:schema]
        list_resources(fields, options, schema, nil) |> @repo.all()
      end

      def stream_resources(
            fields,
            %{"pagination" => %{"paginate?" => true}} = options,
            data_provider
          )
          when not is_nil(data_provider) do
        per_page = options["pagination"]["per_page"] |> String.to_integer()

        schema = @resource_opts[:schema]

        list_resources(fields, options, schema, data_provider)
        |> @repo.all()
        |> Enum.split(per_page)
      end

      def stream_resources(
            fields,
            %{"pagination" => %{"paginate?" => false}} = options,
            data_provider
          )
          when not is_nil(data_provider) do
        schema = @resource_opts[:schema]
        list_resources(fields, options, schema, data_provider) |> @repo.all()
      end

      def get_merged_table_options do
        TableConfig.get_table_options(table_options())
      end

      defp separate_filters_and_transformers(filters) when is_map(filters) do
        {transformers, regular_filters} =
          filters
          |> Enum.split_with(fn {_, filter} ->
            match?(%LiveTable.Transformer{}, filter)
          end)

        {Map.new(regular_filters), Map.new(transformers)}
      end

      defp separate_filters_and_transformers(nil), do: {%{}, %{}}

      defp apply_transformers(query, transformers) do
        Enum.reduce(transformers, query, fn {_key, transformer}, acc ->
          LiveTable.Transformer.apply(acc, transformer)
        end)
      end
    end
  end
end
