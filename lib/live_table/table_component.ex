defmodule LiveTable.TableComponent do
  @moduledoc false
  defmacro __using__(opts) do
    quote do
      import Phoenix.Component
      import LiveTable.SortHelpers
      alias Phoenix.LiveView.JS

      def live_table(var!(assigns)) do
        var!(assigns) =
          var!(assigns)
          |> assign(:table_options, unquote(opts)[:table_options])
          |> assign_new(:actions, fn -> [] end)
          |> assign_new(:id, fn -> "live-table" end)
          |> assign_new(:nonce, fn -> nil end)

        ~H"""
        <div class="w-full" id={@id} phx-hook=".Download">
          <.render_header {assigns} />
          <.render_content {assigns} />
          <.render_footer {assigns} />
        </div>
        <script :type={Phoenix.LiveView.ColocatedHook} name=".Download" runtime nonce={@nonce}>
          {
            mounted() {
              this.handleEvent("download", ({ path }) => {
                const link = document.createElement("a");
                link.href = path;
                link.setAttribute("download", "");
                link.style.display = "none";
                document.body.appendChild(link);
                link.click();
                document.body.removeChild(link);
              });
            }
          }
        </script>
        """
      end

      defp render_header(%{table_options: %{custom_header: {module, function}}} = assigns) do
        apply(module, function, [assigns])
      end

      defp render_header(var!(assigns)) do
        ~H"""
        <.header_section
          id={@id}
          nonce={@nonce}
          fields={@fields}
          filters={@filters}
          options={@options}
          table_options={@table_options}
        />
        """
      end

      defp header_section(%{table_options: %{mode: :table}} = var!(assigns)) do
        ~H"""
        <div class="mt-4">
          <.render_controls {assigns} />
        </div>
        """
      end

      defp header_section(%{table_options: %{mode: :card}} = var!(assigns)) do
        ~H"""
        <div class="px-4 sm:px-6 lg:px-8">
          <div class="mt-4">
            <.render_controls {assigns} />
          </div>
        </div>
        """
      end

      defp render_controls(%{table_options: %{custom_controls: {module, function}}} = assigns) do
        apply(module, function, [assigns])
      end

      defp render_controls(var!(assigns)) do
        ~H"""
        <.common_controls
          id={@id}
          nonce={@nonce}
          fields={@fields}
          filters={@filters}
          options={@options}
          table_options={@table_options}
        />
        """
      end

      defp common_controls(var!(assigns)) do
        ~H"""
        <.form for={%{}} id={"#{@id}-controls-form"} phx-change="sort">
          <div class="space-y-4">
            <!-- Search and controls bar -->
            <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
              <div class="flex items-center gap-3">
                <div
                  :if={
                    Enum.any?(@fields, fn
                      {_, %{searchable: true}} -> true
                      _ -> false
                    end) && @table_options.search.enabled
                  }
                  class="w-56"
                >
                  {LiveTable.Components.impl().search(%{
                    id: dom_id(@id, "table-search"),
                    value: @options["filters"]["search"],
                    placeholder: @table_options[:search][:placeholder],
                    debounce: @table_options[:search][:debounce]
                  })}
                </div>

                <div :if={
                  @options["pagination"]["paginate?"] &&
                    @table_options.pagination[:mode] != :infinite_scroll
                }>
                  {LiveTable.Components.impl().per_page(%{
                    id: dom_id(@id, "per-page-select"),
                    nonce: @nonce,
                    value: to_string(@options["pagination"]["per_page"]),
                    sizes: get_in(@table_options, [:pagination, :sizes])
                  })}
                </div>

                <!-- Filter toggle -->
                <button
                  :if={length(@filters) > (get_in(@table_options, [:max_filters]) || 3)}
                  type="button"
                  phx-click={
                    JS.toggle(to: "#" <> dom_id(@id, "filters-container"))
                    |> JS.toggle(to: "#" <> dom_id(@id, "filter-show-text"))
                    |> JS.toggle(to: "#" <> dom_id(@id, "filter-hide-text"))
                  }
                  class="btn btn-outline"
                >
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    width="24"
                    height="24"
                    viewBox="0 0 24 24"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="2"
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    class="size-4"
                    aria-hidden="true"
                  >
                    <path d="M3 6h18" /><path d="M7 12h10" /><path d="M10 18h4" />
                  </svg>
                  <span id={dom_id(@id, "filter-show-text")}>Show Filters</span>
                  <span id={dom_id(@id, "filter-hide-text")} class="hidden">Hide Filters</span>
                </button>
              </div>

              <div :if={get_in(@table_options, [:exports, :enabled])} class="">
                <.exports
                  id={dom_id(@id, "export-dropdown")}
                  formats={get_in(@table_options, [:exports, :formats])}
                  nonce={@nonce}
                />
              </div>
            </div>

            <!-- Filters section -->
            <div
              id={dom_id(@id, "filters-container")}
              class={["", length(@filters) > (get_in(@table_options, [:max_filters]) || 3) && "hidden"]}
            >
              <.filters filters={@filters} applied_filters={@options["filters"]} />
            </div>
          </div>
        </.form>
        """
      end

      defp render_content(%{table_options: %{custom_content: {module, function}}} = assigns) do
        apply(module, function, [assigns])
      end

      defp render_content(var!(assigns)) do
        ~H"""
        <.content_section {assigns} />
        """
      end

      defp content_section(%{table_options: %{mode: :table}} = var!(assigns)) do
        ~H"""
        <div class="mt-8 flow-root">
          <div class="-mx-4 -my-2 sm:-mx-6 lg:-mx-8">
            <div class="min-w-full py-2 align-middle sm:px-6 lg:px-8">
              <div class={[
                "shadow sm:rounded-lg border border-border",
                @table_options[:fixed_header] && "max-h-[600px] overflow-y-auto",
                !@table_options[:fixed_header] && "overflow-hidden"
              ]}>
                <table class="table min-w-full">
                  <thead class={[
                    "bg-muted",
                    @table_options[:fixed_header] && "sticky top-0 z-10"
                  ]}>
                    <tr>
                      <th
                        :for={{key, field} <- visible_fields(@fields)}
                        scope="col"
                        class="px-3 py-3 text-start text-sm font-semibold text-foreground"
                      >
                        <.sort_link
                          key={key}
                          label={field.label}
                          sort_params={@options["sort"]["sort_params"]}
                          sortable={Map.get(field, :sortable, false)}
                          nonce={@nonce}
                          table_id={@id}
                        />
                      </th>
                      <th
                        :if={has_actions(@actions)}
                        scope="col"
                        class="px-3 py-3 text-center text-sm font-semibold text-foreground"
                      >
                        {actions_label(@actions)}
                      </th>
                    </tr>
                  </thead>
                  <tbody
                    id={dom_id(@id, "resources-stream")}
                    phx-update={@table_options[:use_streams] && "stream"}
                    class="bg-background"
                  >
                    <tr
                      id={dom_id(@id, "empty-placeholder")}
                      class="only:table-row hidden hover:bg-transparent"
                    >
                      <td colspan={
                        length(visible_fields(@fields)) + if(has_actions(@actions), do: 1, else: 0)
                      }>
                        <.render_empty_state table_options={@table_options} />
                      </td>
                    </tr>
                    <.render_row
                      streams={@streams}
                      fields={visible_fields(@fields)}
                      table_options={@table_options}
                      actions={@actions}
                    />
                  </tbody>
                </table>
              </div>
            </div>
          </div>
        </div>
        """
      end

      defp content_section(
             %{table_options: %{mode: :card, pagination: %{mode: :infinite_scroll}}} =
               var!(assigns)
           ) do
        ~H"""
        <div
          id={dom_id(@id, "infinite-scroll-container")}
          phx-update="stream"
          phx-viewport-bottom={@options["pagination"][:has_next_page] && "load_more"}
          phx-throttle="1000"
          class="mt-8 grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-3"
        >
          <div id={dom_id(@id, "empty-placeholder")} class="hidden only:block col-span-full">
            <.render_empty_state table_options={@table_options} />
          </div>
          <div :for={{id, record} <- @streams.resources} id={id}>
            {@table_options.card_component.(%{record: record})}
          </div>
        </div>

        <.loader
          :if={@options["pagination"][:has_next_page]}
          loading_component={@table_options.pagination[:loading_component]}
        />
        """
      end

      defp loader(%{loading_component: component} = assigns) when is_function(component, 1) do
        component.(%{})
      end

      defp loader(var!(assigns)) do
        ~H"""
        <div class="flex justify-center py-8">
          <svg
            xmlns="http://www.w3.org/2000/svg"
            width="24"
            height="24"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            stroke-linecap="round"
            stroke-linejoin="round"
            class="size-6 animate-spin text-muted-foreground"
            aria-hidden="true"
          >
            <path d="M21 12a9 9 0 1 1-6.219-8.56" />
          </svg>
        </div>
        """
      end

      defp content_section(%{table_options: %{mode: :card, use_streams: false}} = var!(assigns)) do
        ~H"""
        <div class="mt-8 grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-3">
          <div :if={@streams == []} class="col-span-full">
            <.render_empty_state table_options={@table_options} />
          </div>
          <div :for={record <- @streams}>
            {@table_options.card_component.(%{record: record})}
          </div>
        </div>
        """
      end

      defp content_section(%{table_options: %{mode: :card, use_streams: true}} = var!(assigns)) do
        ~H"""
        <div
          id={dom_id(@id, "resources-stream")}
          phx-update="stream"
          class="mt-8 grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-3"
        >
          <div id={dom_id(@id, "card-empty-placeholder")} class="hidden only:block col-span-full">
            <.render_empty_state table_options={@table_options} />
          </div>
          <div :for={{id, record} <- @streams.resources} id={id}>
            {@table_options.card_component.(%{record: record})}
          </div>
        </div>
        """
      end

      defp render_empty_state(%{table_options: %{empty_state: callback}} = assigns)
           when is_function(callback, 1) do
        callback.(assigns)
      end

      defp render_empty_state(assigns) do
        LiveTable.Components.impl().empty_state(assigns)
      end

      defp render_row(%{table_options: %{use_streams: false}} = var!(assigns)) do
        ~H"""
        <tr :for={resource <- @streams}>
          <td :for={{key, field} <- @fields} class="whitespace-nowrap px-3 py-3.5 text-sm text-foreground">
            {render_cell(Map.get(resource, key), field, resource)}
          </td>
          <td :if={has_actions(@actions)}>
            <.render_actions actions={@actions} record={resource} />
          </td>
        </tr>
        """
      end

      defp render_row(%{table_options: %{use_streams: true}} = var!(assigns)) do
        ~H"""
        <tr :for={{id, resource} <- @streams.resources} id={id}>
          <td :for={{key, field} <- @fields} class="whitespace-nowrap px-3 py-3.5 text-sm text-foreground">
            {render_cell(Map.get(resource, key), field, resource)}
          </td>
          <td :if={has_actions(@actions)}>
            <.render_actions actions={@actions} record={resource} />
          </td>
        </tr>
        """
      end

      defp footer_section(var!(assigns)) do
        ~H"""
        <.paginate
          :if={
            @options["pagination"]["paginate?"] && @table_options.pagination[:mode] != :infinite_scroll
          }
          current_page={@options["pagination"]["page"]}
          has_next_page={@options["pagination"][:has_next_page]}
        />
        """
      end

      defp render_footer(%{table_options: %{custom_footer: {module, function}}} = assigns) do
        apply(module, function, [assigns])
      end

      defp render_footer(var!(assigns)) do
        ~H"""
        <.footer_section {assigns} />
        """
      end

      defp filters(var!(assigns)) do
        filter_count = length(var!(assigns).filters)
        cols = min(filter_count, 3)
        var!(assigns) = assign(var!(assigns), :cols, cols)

        ~H"""
        <div :if={@filters != []} class="filter-bar">
          <div class={[
            "filter-bar-grid",
            filter_bar_cols_class(@cols)
          ]}>
            <div :for={{key, filter} <- @filters} class="filter-bar-item">
              {filter.__struct__.render(%{
                key: key,
                filter: filter,
                applied_filters: @applied_filters
              })}
            </div>
          </div>
          <div
            :if={@applied_filters != %{"search" => ""} and @applied_filters != %{}}
            class="filter-bar-actions"
          >
            <button
              type="button"
              phx-click="sort"
              phx-value-clear_filters="true"
              class="filter-bar-clear"
            >
              <svg
                xmlns="http://www.w3.org/2000/svg"
                width="24"
                height="24"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
                class="size-4"
                aria-hidden="true"
              >
                <path d="M18 6 6 18" /><path d="m6 6 12 12" />
              </svg>
              Clear Filters
            </button>
          </div>
        </div>
        """
      end

      defp filter_bar_cols_class(cols) do
        case cols do
          1 -> "filter-bar-cols-1"
          2 -> "filter-bar-cols-2"
          3 -> "filter-bar-cols-3"
          _ -> "filter-bar-cols-3"
        end
      end

      defp paginate(var!(assigns)) do
        ~H"""
        <nav class="flex items-center justify-between px-4 py-3 sm:px-6" aria-label="Pagination">
          <div class="hidden sm:block">
            <p class="text-sm text-muted-foreground">
              Page <span class="font-medium text-foreground">{@current_page}</span>
            </p>
          </div>
          <div class="flex flex-1 justify-between sm:justify-end">
            <button
              type="button"
              phx-click="sort"
              phx-value-page={String.to_integer(@current_page) - 1}
              class={[
                "btn-outline",
                String.to_integer(@current_page) == 1 && "opacity-50 cursor-not-allowed"
              ]}
              disabled={String.to_integer(@current_page) == 1}
            >
              Previous
            </button>
            <button
              type="button"
              phx-click="sort"
              phx-value-page={String.to_integer(@current_page) + 1}
              class={["btn-outline ml-3", !@has_next_page && "opacity-50 cursor-not-allowed"]}
              disabled={!@has_next_page}
            >
              Next
            </button>
          </div>
        </nav>
        """
      end

      defp exports(assigns) do
        LiveTable.Export.validate_formats!(assigns.formats)
        LiveTable.Components.impl().exports(assigns)
      end

      defp render_cell(value, field, _record)
           when is_nil(value) and not is_nil(field.empty_text) do
        field.empty_text
      end

      defp render_cell(value, %{renderer: renderer}, record) when is_function(renderer, 1) do
        renderer.(value)
      end

      defp render_cell(value, %{renderer: renderer}, record) when is_function(renderer, 2) do
        renderer.(value, record)
      end

      defp render_cell(value, %{component: component}, record) when is_function(component, 1) do
        component.(%{value: value, record: record})
      end

      defp render_cell(value, %{component: component}, record) when is_function(component, 2) do
        component.(value, record)
      end

      defp render_cell(true, _field, _record), do: "Yes"
      defp render_cell(false, _field, _record), do: "No"
      defp render_cell(value, _field, _record), do: safe_cell_value(value)

      defp safe_cell_value(value) do
        Phoenix.HTML.Safe.to_iodata(value)
      rescue
        Protocol.UndefinedError ->
          value
          |> to_string()
          |> Phoenix.HTML.Safe.to_iodata()
      end

      defoverridable live_table: 1,
                     render_header: 1,
                     render_content: 1,
                     render_footer: 1

      defp render_actions(var!(assigns)) do
        ~H"""
        <div class="flex">
          <%= for {_key, component} <- actions_items(@actions) do %>
            {component.(%{record: @record})}
          <% end %>
        </div>
        """
      end

      defp actions_items(actions) when is_list(actions), do: actions
      defp actions_items(%{items: items}) when is_list(items), do: items
      defp actions_items(_), do: []

      defp has_actions([]), do: false
      defp has_actions(actions) when is_list(actions), do: true
      defp has_actions(%{items: items}) when is_list(items), do: length(items) > 0
      defp has_actions(_), do: false

      defp actions_label(%{label: label}), do: label
      defp actions_label(_), do: "Actions"

      defp visible_fields(fields) do
        Enum.reject(fields, fn {_key, field} -> Map.get(field, :hidden, false) end)
      end
    end
  end
end
