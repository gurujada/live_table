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
      import Debug, only: [debug_pipeline: 2]

      use Helpers,
        schema: unquote(opts[:schema]),
        table_options: TableConfig.get_table_options(table_options())

      use TableComponent, table_options: TableConfig.get_table_options(table_options())

      alias LiveTable.{Boolean, Select, Range, Custom, Transformer}

      @resource_opts unquote(opts)
      @repo Application.compile_env(:live_table, :repo)

      def fields, do: []
      def filters, do: []
      def actions, do: []

      def table_options(), do: %{}

      defoverridable fields: 0, filters: 0, table_options: 0, actions: 0

      def list_resources(fields, options, {module, function, args} = _data_provider)
          when is_atom(function) do
        {regular_filters, transformers, debug_mode} = prepare_query_context(options)

        apply(module, function, args)
        |> join_associations(regular_filters)
        |> apply_filters(regular_filters, fields)
        |> maybe_sort(fields, options["sort"]["sort_params"], options["sort"]["sortable?"])
        |> apply_transformers(transformers)
        |> maybe_paginate(options["pagination"], options["pagination"]["paginate?"])
        |> debug_pipeline(debug_mode)
      end

      def list_resources(fields, options, schema) do
        {regular_filters, transformers, debug_mode} = prepare_query_context(options)

        schema
        |> from(as: :resource)
        |> join_associations(regular_filters)
        |> select_columns(fields)
        |> apply_filters(regular_filters, fields)
        |> maybe_sort(fields, options["sort"]["sort_params"], options["sort"]["sortable?"])
        |> apply_transformers(transformers)
        |> maybe_paginate(options["pagination"], options["pagination"]["paginate?"])
        |> debug_pipeline(debug_mode)
      end

      def stream_resources(
            fields,
            %{"pagination" => %{"paginate?" => true}} = options,
            data_source
          ) do
        per_page = options["pagination"]["per_page"] |> String.to_integer()

        data_source = data_source || @resource_opts[:schema]

        list_resources(fields, options, data_source)
        |> @repo.all()
        |> Enum.split(per_page)
      end

      def stream_resources(
            fields,
            %{"pagination" => %{"paginate?" => false}} = options,
            data_source
          ) do
        data_source = data_source || @resource_opts[:schema]

        list_resources(fields, options, data_source) |> @repo.all()
      end

      def get_merged_table_options do
        TableConfig.get_table_options(table_options())
      end

      defp prepare_query_context(options) do
        debug_mode = Map.get(TableConfig.get_table_options(table_options()), :debug, :off)

        {regular_filters, transformers} =
          Map.get(options, "filters", nil)
          |> separate_filters_and_transformers()

        {regular_filters, transformers, debug_mode}
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
