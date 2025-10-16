defmodule LiveTable.TableComponent do
  @moduledoc false
  defmacro __using__(opts) do
    quote do
      use Phoenix.Component
      import LiveTable.SortHelpers
      alias Phoenix.LiveView.JS

      def live_table(var!(assigns)) do
        var!(assigns) =
          var!(assigns)
          |> assign(:table_options, unquote(opts)[:table_options])
          |> assign_new(:actions, fn -> [] end)

        ~H"""
        <div class="w-full" id="live-table" phx-hook="Download">
          <.render_header {assigns} />
          <.render_content {assigns} />
          <.render_footer {assigns} />
        </div>
        """
      end

      defp render_header(%{table_options: %{custom_header: {module, function}}} = assigns) do
        # Call custom header component
        apply(module, function, [assigns])
      end

      defp render_header(var!(assigns)) do
        ~H"""
        <.header_section
          fields={@fields}
          filters={@filters}
          options={@options}
          table_options={@table_options}
        />
        """
      end

      defp header_section(%{table_options: %{mode: :table}} = var!(assigns)) do
        ~H"""
        <div class="px-4 sm:px-6 lg:px-8">
          <!-- Header with title -->
          <div class="flex sm:items-center justify-end">
            <div
              :if={get_in(@table_options, [:exports, :enabled])}
              class="mt-4 sm:ml-16 sm:mt-0 sm:flex-none"
            >
              <.exports formats={get_in(@table_options, [:exports, :formats])} />
            </div>
          </div>
          
        <!-- Controls section -->
          <div class="mt-4">
            <.render_controls {assigns} />
          </div>
        </div>
        """
      end

      defp header_section(%{table_options: %{mode: :card}} = var!(assigns)) do
        ~H"""
        <div class="px-4 sm:px-6 lg:px-8">
          <div class="flex sm:items-center justify-end">
            <div
              :if={get_in(@table_options, [:exports, :enabled])}
              class="mt-4 sm:ml-16 sm:mt-0 sm:flex-none"
            >
              <.exports formats={get_in(@table_options, [:exports, :formats])} />
            </div>
          </div>
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
          fields={@fields}
          filters={@filters}
          options={@options}
          table_options={@table_options}
        />
        """
      end

      defp common_controls(var!(assigns)) do
        ~H"""
        <.form for={%{}} phx-change="sort">
          <div class="space-y-4">
            <!-- Search and controls bar -->
            <div class="flex flex-col sm:flex-row sm:items-center gap-2">
              <div class="flex items-center gap-3">
                <!-- Search -->
                <div
                  :if={
                    Enum.any?(@fields, fn
                      {_, %{searchable: true}} -> true
                      _ -> false
                    end) && @table_options.search.enabled
                  }
                  class="w-64"
                >
                  <label for="table-search" class="sr-only">Search</label>
                  <div class="relative rounded-md shadow-sm">
                    <div class="pointer-events-none absolute inset-y-0 left-0 z-10 flex items-center pl-3">
                      <svg
                        class="h-5 w-5 text-gray-400"
                        viewBox="0 0 20 20"
                        fill="currentColor"
                        aria-hidden="true"
                      >
                        <path
                          fill-rule="evenodd"
                          d="M9 3.5a5.5 5.5 0 100 11 5.5 5.5 0 000-11zM2 9a7 7 0 1112.452 4.391l3.328 3.329a.75.75 0 11-1.06 1.06l-3.329-3.328A7 7 0 012 9z"
                          clip-rule="evenodd"
                        />
                      </svg>
                    </div>
                    <input
                      type="text"
                      name="search"
                      autocomplete="off"
                      id="table-search"
                      class="input input-bordered w-full pl-10"
                      placeholder={@table_options[:search][:placeholder]}
                      value={@options["filters"]["search"]}
                      phx-debounce={@table_options[:search][:debounce]}
                    />
                  </div>
                </div>
                
        <!-- Per page -->
                <select
                  :if={@options["pagination"]["paginate?"]}
                  name="per_page"
                  value={@options["pagination"]["per_page"]}
                  class="select select-bordered w-20"
                >
                  {Phoenix.HTML.Form.options_for_select(
                    get_in(@table_options, [:pagination, :sizes]),
                    @options["pagination"]["per_page"]
                  )}
                </select>
              </div>
              
        <!-- Filter toggle -->
              <button :if={length(@filters) > 3} type="button" phx-click="toggle_filters" class="btn">
                <svg class="-ml-0.5 h-5 w-5" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
                  <path
                    fill-rule="evenodd"
                    d="M2.628 1.601C5.028 1.206 7.49 1 10 1s4.973.206 7.372.601a.75.75 0 01.628.74v2.288a2.25 2.25 0 01-.659 1.59l-4.682 4.683a2.25 2.25 0 00-.659 1.59v3.037c0 .684-.31 1.33-.844 1.757l-1.937 1.55A.75.75 0 018 18.25v-5.757a2.25 2.25 0 00-.659-1.591L2.659 6.22A2.25 2.25 0 012 4.629V2.34a.75.75 0 01.628-.74z"
                    clip-rule="evenodd"
                  />
                </svg>
                <span phx-update="ignore" id="filter-toggle-text">Filters</span>
              </button>
            </div>
            
        <!-- Filters section -->
            <div
              id="filters-container"
              class={["", length(@filters) > 3 && "hidden"]}
              phx-hook="FilterToggle"
            >
              <.filters filters={@filters} applied_filters={@options["filters"]} />
            </div>
          </div>
        </.form>
        """
      end

      defp render_content(%{table_options: %{custom_content: {module, function}}} = assigns) do
        # Call custom content component
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
          <div class="-mx-4 -my-2 overflow-x-auto sm:-mx-6 lg:-mx-8">
            <div class="inline-block min-w-full py-2 align-middle sm:px-6 lg:px-8">
              <div class="overflow-hidden shadow sm:rounded-lg">
                <table class="table divide-y dark:divide-gray-700">
                  <thead class="bg-gray-50 dark:bg-gray-800">
                    <tr>
                      <th
                        :for={{key, field} <- @fields}
                        scope="col"
                        class="px-3 py-3.5 text-start text-sm font-semibold text-gray-900 dark:text-gray-100"
                      >
                        <.sort_link
                          key={key}
                          label={field.label}
                          sort_params={@options["sort"]["sort_params"]}
                          sortable={field.sortable}
                        />
                      </th>
                      <th
                        :if={has_actions(@actions)}
                        scope="col"
                        class="px-3 py-3.5 text-start text-sm font-semibold text-gray-900 dark:text-gray-100"
                      >
                        {actions_label(@actions)}
                      </th>
                    </tr>
                  </thead>
                  <tbody class="divide-y dark:divide-gray-700 bg-white dark:bg-gray-900">
                    <tr id="empty-placeholder" class="only:table-row hidden">
                      <td
                        colspan={length(@fields) + if(has_actions(@actions), do: 1, else: 0)}
                        class="py-10 text-center"
                      >
                        <svg
                          class="mx-auto h-12 w-12 text-gray-400"
                          fill="none"
                          viewBox="0 0 24 24"
                          stroke="currentColor"
                          aria-hidden="true"
                        >
                          <path
                            stroke-linecap="round"
                            stroke-linejoin="round"
                            stroke-width="2"
                            d="M9 13h6m-3-3v6m-9 1V7a2 2 0 012-2h6l2 2h6a2 2 0 012 2v8a2 2 0 01-2 2H5a2 2 0 01-2-2z"
                          />
                        </svg>
                        <h3 class="mt-2 text-sm font-semibold text-gray-900 dark:text-gray-100">
                          No data
                        </h3>
                        <p class="mt-1 text-sm text-gray-500 dark:text-gray-400">
                          Get started by creating a new record.
                        </p>
                      </td>
                    </tr>
                    <.render_row
                      streams={@streams}
                      fields={@fields}
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

      defp content_section(%{table_options: %{mode: :card, use_streams: false}} = var!(assigns)) do
        ~H"""
        <div class="mt-8 grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-3">
          <div :for={record <- @streams}>
            {@table_options.card_component.(%{record: record})}
          </div>
        </div>
        """
      end

      defp content_section(%{table_options: %{mode: :card, use_streams: true}} = var!(assigns)) do
        ~H"""
        <div class="mt-8 grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-3">
          <div :for={{id, record} <- @streams.resources} id={id}>
            {@table_options.card_component.(%{record: record})}
          </div>
        </div>
        """
      end

      defp render_row(%{table_options: %{use_streams: false}} = var!(assigns)) do
        ~H"""
        <tr :for={resource <- @streams}>
          <td
            :for={{key, field} <- @fields}
            class="whitespace-nowrap px-3 py-4 text-sm text-gray-900 dark:text-gray-100"
          >
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
          <td
            :for={{key, field} <- @fields}
            class="whitespace-nowrap px-3 py-4 text-sm text-gray-900 dark:text-gray-100"
          >
            {render_cell(Map.get(resource, key), field, resource)}
          </td>
          <td :if={has_actions(@actions)}>
            <.render_actions actions={@actions} record={resource} />
          </td>
        </tr>
        """
      end

      defp render_row(_),
        do:
          raise(ArgumentError,
            message: "Requires `use_streams` to be set to a boolean in table_options"
          )

      defp footer_section(var!(assigns)) do
        ~H"""
        <.paginate
          :if={@options["pagination"]["paginate?"]}
          current_page={@options["pagination"]["page"]}
          has_next_page={@options["pagination"][:has_next_page]}
        />
        """
      end

      defp render_footer(%{table_options: %{custom_footer: {module, function}}} = assigns) do
        # Call custom content component
        apply(module, function, [assigns])
      end

      defp render_footer(var!(assigns)) do
        ~H"""
        <.footer_section {assigns} />
        """
      end

      def filters(var!(assigns)) do
        ~H"""
        <div :if={@filters != []} class="rounded-lg bg-gray-50 p-4 dark:bg-gray-800">
          <div class="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
            <%= for {key, filter} <- @filters do %>
              <div>
                {filter.__struct__.render(%{
                  key: key,
                  filter: filter,
                  applied_filters: @applied_filters
                })}
              </div>
            <% end %>
          </div>
          <div
            :if={@applied_filters != %{"search" => ""}}
            class="mt-4 flex justify-end border-t border-gray-200 pt-4 dark:border-gray-700"
          >
            <.link phx-click="sort" phx-value-clear_filters="true" class="btn">
              <svg class="-ml-0.5 h-5 w-5" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
                <path
                  fill-rule="evenodd"
                  d="M8.75 1A2.75 2.75 0 006 3.75v.443c-.795.077-1.584.176-2.365.298a.75.75 0 10.23 1.482l.149-.022.841 10.518A2.75 2.75 0 007.596 19h4.807a2.75 2.75 0 002.742-2.53l.841-10.52.149.023a.75.75 0 00.23-1.482A41.03 41.03 0 0014 4.193V3.75A2.75 2.75 0 0011.25 1h-2.5zM10 4c.84 0 1.673.025 2.5.075V3.75c0-.69-.56-1.25-1.25-1.25h-2.5c-.69 0-1.25.56-1.25 1.25v.325C8.327 4.025 9.16 4 10 4zM8.58 7.72a.75.75 0 00-1.5.06l.3 7.5a.75.75 0 101.5-.06l-.3-7.5zm4.34.06a.75.75 0 10-1.5-.06l-.3 7.5a.75.75 0 101.5.06l.3-7.5z"
                  clip-rule="evenodd"
                />
              </svg>
              Clear filters
            </.link>
          </div>
        </div>
        """
      end

      def paginate(var!(assigns)) do
        ~H"""
        <nav class="flex items-center justify-between px-4 py-3 sm:px-6" aria-label="Pagination">
          <div class="hidden sm:block">
            <p class="text-sm text-gray-700 dark:text-gray-300">
              Page <span class="font-medium">{@current_page}</span>
            </p>
          </div>
          <div class="flex flex-1 justify-between sm:justify-end">
            <button
              phx-click="sort"
              phx-value-page={String.to_integer(@current_page) - 1}
              class={["btn", String.to_integer(@current_page) == 1 && "btn-disabled cursor-not-allowed"]}
              disabled={String.to_integer(@current_page) == 1}
            >
              Previous
            </button>
            <button
              phx-click="sort"
              phx-value-page={String.to_integer(@current_page) + 1}
              class={["btn ml-3", !@has_next_page && "btn-disabled cursor-not-allowed"]}
              disabled={!@has_next_page}
            >
              Next
            </button>
          </div>
        </nav>
        """
      end

      def exports(var!(assigns)) do
        ~H"""
        <div
          class="dropdown dropdown-end text-left"
          phx-click-away={JS.hide(to: "#export-dropdown")}
          phx-window-keydown={JS.hide(to: "#export-dropdown")}
          phx-key="escape"
        >
          <div>
            <button
              type="button"
              class="btn"
              id="export-menu-button"
              aria-expanded="false"
              aria-haspopup="true"
              phx-click={
                JS.toggle(
                  to: "#export-dropdown",
                  in: "transition ease-out duration-150 opacity-0 -translate-y-1",
                  out: "transition ease-in duration-150 opacity-100 translate-y-0"
                )
              }
              data-hide-on-click="#export-dropdown"
            >
              Export
              <svg
                class="-mr-1 h-5 w-5 text-gray-400"
                viewBox="0 0 20 20"
                fill="currentColor"
                aria-hidden="true"
              >
                <path
                  fill-rule="evenodd"
                  d="M5.23 7.21a.75.75 0 011.06.02L10 11.168l3.71-3.938a.75.75 0 111.08 1.04l-4.25 4.5a.75.75 0 01-1.08 0l-4.25-4.5a.75.75 0 01.02-1.06z"
                  clip-rule="evenodd"
                />
              </svg>
            </button>
          </div>

          <div
            id="export-dropdown"
            class="dropdown-content bg-base-100 rounded-box w-56 shadow hidden z-50"
            role="menu"
            aria-orientation="vertical"
            aria-labelledby="export-menu-button"
            tabindex="-1"
          >
            <ul class="menu menu-sm" role="none">
              <li :for={format <- @formats} role="none">
                <.link
                  href="#"
                  role="menuitem"
                  aria-label={"Export as #{String.upcase(to_string(format))}"}
                  phx-click={if(format == :csv, do: "export-csv", else: "export-pdf")}
                  class="btn btn-ghost btn-sm w-full justify-start"
                >
                  <svg
                    class="h-4 w-4 text-gray-500 dark:text-gray-300"
                    viewBox="0 0 24 24"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="2"
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    aria-hidden="true"
                  >
                    <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" />
                    <polyline points="7 10 12 15 17 10" />
                    <line x1="12" y1="15" x2="12" y2="3" />
                  </svg>
                  <span>Export as {String.upcase(to_string(format))}</span>
                </.link>
              </li>
            </ul>
          </div>
        </div>
        """
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
      defp render_cell(value, _field, _record), do: Phoenix.HTML.Safe.to_iodata(value)

      defoverridable live_table: 1,
                     render_header: 1,
                     render_content: 1,
                     render_footer: 1

      def render_actions(var!(assigns)) do
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

      def has_actions([]), do: false
      def has_actions(actions) when is_list(actions), do: true
      def has_actions(%{items: items}) when is_list(items), do: length(items) > 0
      def has_actions(_), do: false

      def actions_label(%{label: label}), do: label
      def actions_label(_), do: "Actions"
    end
  end
end
