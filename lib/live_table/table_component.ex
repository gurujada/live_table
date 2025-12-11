defmodule LiveTable.TableComponent do
  @moduledoc false
  defmacro __using__(opts) do
    quote do
      use Phoenix.Component
      import LiveTable.SortHelpers
      import SutraUI.DropdownMenu
      import SutraUI.InputGroup
      import SutraUI.Select
      import SutraUI.Empty
      alias SutraUI.Icon
      alias Phoenix.LiveView.JS

      def live_table(var!(assigns)) do
        var!(assigns) =
          var!(assigns)
          |> assign(:table_options, unquote(opts)[:table_options])
          |> assign_new(:actions, fn -> [] end)

        ~H"""
        <div class="w-full" id="live-table" phx-hook={@table_options[:exports][:enabled] && ".Download"}>
          <.render_header {assigns} />
          <.render_content {assigns} />
          <.render_footer {assigns} />
        </div>
        <script :type={Phoenix.LiveView.ColocatedHook} name=".Download">
          export default {
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
                  <label for="table-search" class="sr-only">Search</label>
                  <.input_group>
                    <:prefix type="icon">
                      <Icon.icon name="hero-magnifying-glass" class="size-4 text-muted-foreground" />
                    </:prefix>
                    <input
                      type="text"
                      name="search"
                      autocomplete="off"
                      id="table-search"
                      class="input w-full pl-9"
                      placeholder={@table_options[:search][:placeholder]}
                      value={@options["filters"]["search"]}
                      phx-debounce={@table_options[:search][:debounce]}
                    />
                  </.input_group>
                </div>

                <.select
                  :if={@options["pagination"]["paginate?"] && @table_options.pagination[:mode] != :infinite_scroll}
                  id="per-page-select"
                  name="per_page"
                  value={to_string(@options["pagination"]["per_page"])}
                  class="w-24"
                  trigger_class="w-full"
                >
                  <:trigger>
                    {@options["pagination"]["per_page"]}
                  </:trigger>
                  <.select_option
                    :for={size <- get_in(@table_options, [:pagination, :sizes])}
                    value={to_string(size)}
                    label={to_string(size)}
                  />
                </.select>

        <!-- Filter toggle -->
                <button
                  :if={length(@filters) > 3}
                  type="button"
                  phx-click={
                    JS.toggle(to: "#filters-container")
                    |> JS.toggle(to: "#filter-show-text")
                    |> JS.toggle(to: "#filter-hide-text")
                  }
                  class="btn btn-outline"
                >
                  <Icon.icon name="hero-funnel" class="size-4" />
                  <span id="filter-show-text">Show Filters</span>
                  <span id="filter-hide-text" class="hidden">Hide Filters</span>
                </button>
              </div>

              <div :if={get_in(@table_options, [:exports, :enabled])} class="">
                <.exports formats={get_in(@table_options, [:exports, :formats])} />
              </div>
            </div>

        <!-- Filters section -->
            <div id="filters-container" class={["", length(@filters) > 3 && "hidden"]}>
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
              <div class="overflow-hidden shadow sm:rounded-lg border border-border">
                <table class="table">
                  <thead class="bg-muted">
                    <tr>
                      <th
                        :for={{key, field} <- @fields}
                        scope="col"
                        class="px-3 py-3 text-start text-sm font-semibold text-foreground"
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
                        class="px-3 py-3 text-start text-sm font-semibold text-foreground"
                      >
                        {actions_label(@actions)}
                      </th>
                    </tr>
                  </thead>
                  <tbody class="bg-background">
                    <tr id="empty-placeholder" class="only:table-row hidden hover:bg-transparent">
                      <td colspan={length(@fields) + if(has_actions(@actions), do: 1, else: 0)}>
                        <.render_empty_state table_options={@table_options} />
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

      defp content_section(
             %{table_options: %{mode: :card, pagination: %{mode: :infinite_scroll}}} =
               var!(assigns)
           ) do
        ~H"""
        <div
          id="infinite-scroll-container"
          phx-update="stream"
          phx-viewport-bottom={@options["pagination"][:has_next_page] && !@loading_more && "load_more"}
          class="mt-8 grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-3"
        >
          <div :for={{id, record} <- @streams.resources} id={id}>
            {@table_options.card_component.(%{record: record})}
          </div>
        </div>

        <.loader
          :if={@loading_more}
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
          <Icon.icon name="hero-arrow-path" class="size-6 animate-spin text-muted-foreground" />
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

      # Empty state rendering - supports custom callback or default Sutra UI empty component
      defp render_empty_state(%{table_options: %{empty_state: callback}} = assigns)
           when is_function(callback, 1) do
        callback.(assigns)
      end

      defp render_empty_state(var!(assigns)) do
        ~H"""
        <.empty>
          <:icon>
            <Icon.icon name="hero-folder-open" class="size-12" />
          </:icon>
          <:title>No data</:title>
          <:description>
            No records found. Try adjusting your filters or create a new record.
          </:description>
        </.empty>
        """
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

      defp render_row(_),
        do:
          raise(ArgumentError,
            message: "Requires `use_streams` to be set to a boolean in table_options"
          )

      defp footer_section(var!(assigns)) do
        ~H"""
        <.paginate
          :if={@options["pagination"]["paginate?"] && @table_options.pagination[:mode] != :infinite_scroll}
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
        <div :if={@filters != []} class="space-y-4">
          <.form for={%{}} phx-change="sort" class="flex flex-wrap gap-4 items-end">
            <div :for={{key, filter} <- @filters} class="contents">
              {filter.__struct__.render(%{
                key: key,
                filter: filter,
                applied_filters: @applied_filters
              })}
            </div>
          </.form>
          <div
            :if={@applied_filters != %{"search" => ""} and @applied_filters != %{}}
            class="flex justify-end"
          >
            <button
              type="button"
              phx-click="sort"
              phx-value-clear_filters="true"
              class="inline-flex items-center gap-1.5 text-sm text-muted-foreground hover:text-foreground transition-colors cursor-pointer"
            >
              <Icon.icon name="hero-x-mark" class="size-4" /> Clear Filters
            </button>
          </div>
        </div>
        """
      end

      def paginate(var!(assigns)) do
        ~H"""
        <nav class="flex items-center justify-between px-4 py-3 sm:px-6" aria-label="Pagination">
          <div class="hidden sm:block">
            <p class="text-sm text-muted-foreground">
              Page <span class="font-medium text-foreground">{@current_page}</span>
            </p>
          </div>
          <div class="flex flex-1 justify-between sm:justify-end">
            <button
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

      def exports(var!(assigns)) do
        ~H"""
        <.dropdown_menu id="export-dropdown">
          <:trigger>
            <span class="flex items-center gap-2">
              <Icon.icon name="hero-arrow-down-tray" class="size-4" /> Export
            </span>
          </:trigger>
          <:item
            :for={format <- @formats}
            icon="hero-arrow-down-tray"
            on_click={if(format == :csv, do: "export-csv", else: "export-pdf")}
          >
            Export as {String.upcase(to_string(format))}
          </:item>
        </.dropdown_menu>
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
