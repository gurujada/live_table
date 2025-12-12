defmodule LiveTable.SortHelpers do
  @moduledoc false
  use Phoenix.Component

  def sort_link(%{sortable: true} = assigns) do
    ~H"""
    <div
      :if={@sortable}
      class="group inline-flex items-center cursor-pointer whitespace-nowrap align-middle"
      phx-click="sort"
      id={@key}
      phx-hook=".SortableColumn"
      phx-value-sort={
        Jason.encode!(%{
          @key => (@sort_params[@key] || :asc) |> to_string() |> next_sort_order()
        })
      }
    >
      <span class="leading-5">{@label}</span>
      <span class="ml-2 flex-none rounded text-muted-foreground group-hover:visible group-focus:visible">
        <svg
          class="size-4 relative top-[1px] text-muted-foreground"
          xmlns="http://www.w3.org/2000/svg"
          width="24"
          height="24"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          stroke-linecap="round"
          stroke-linejoin="round"
        >
          <path
            class={[Keyword.get(@sort_params, @key) == :desc && "text-primary"]}
            d="m7 15 5 5 5-5"
          >
          </path>
          <path
            class={[Keyword.get(@sort_params, @key) == :asc && "text-primary"]}
            d="m7 9 5-5 5 5"
          >
          </path>
        </svg>
      </span>
    </div>
    <script :type={Phoenix.LiveView.ColocatedHook} name=".SortableColumn">
      export default {
        mounted() {
          this.handleClick = (event) => {
            if (event.shiftKey) {
              event.preventDefault();
              this.pushEvent("sort", {
                sort: this.el.getAttribute("phx-value-sort"),
                shift_key: true,
              });
            }
          };
          this.el.addEventListener("click", this.handleClick);
        },
        destroyed() {
          this.el.removeEventListener("click", this.handleClick);
        },
      }
    </script>
    """
  end

  def sort_link(assigns) do
    ~H"""
    <span>{@label}</span>
    """
  end

  def next_sort_order("asc"), do: "desc"
  def next_sort_order("desc"), do: "asc"

  def update_sort_params(map, nil, _), do: map

  def update_sort_params(map, params, true) do
    p =
      params
      |> Jason.decode!()
      |> Keyword.new(fn {k, v} -> {String.to_existing_atom(k), String.to_existing_atom(v)} end)

    map
    |> Map.update("sort_params", nil, fn x ->
      merge_lists(x, p)
    end)
  end

  # Replaces existing sort params with new ones when shift key is not pressed
  def update_sort_params(map, params, false) do
    p =
      params
      |> Jason.decode!()
      |> Keyword.new(fn {k, v} -> {String.to_existing_atom(k), String.to_existing_atom(v)} end)

    map
    |> Map.put("sort_params", p)
  end

  def merge_lists(list1, list2) do
    list2_map = Enum.into(list2, %{})

    list1
    |> Enum.map(fn {key, value} ->
      {key, Map.get(list2_map, key, value)}
    end)
    |> Kernel.++(Enum.reject(list2, fn {key, _} -> key in Keyword.keys(list1) end))
  end
end
