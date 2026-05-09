defmodule LiveTable.TestProductLive do
  use Phoenix.LiveView
  use LiveTable.LiveResource, schema: LiveTable.Catalog.Product

  import Ecto.Query

  alias LiveTable.{Boolean, Range, Select, Transformer}

  def mount(_params, _session, socket), do: {:ok, socket}

  def fields do
    [
      id: %{label: "ID", sortable: true},
      name: %{label: "Name", sortable: true, searchable: true},
      description: %{label: "Description", searchable: true},
      price: %{label: "Price", sortable: true},
      stock_quantity: %{label: "Stock", sortable: true}
    ]
  end

  def filters do
    [
      in_stock:
        Boolean.new(:stock_quantity, "in-stock", %{
          label: "In Stock",
          condition: dynamic([p], p.stock_quantity > 0)
        }),
      price_range:
        Range.new(:price, "price_range", %{
          label: "Price Range",
          min: 0,
          max: 500,
          step: 1,
          default_min: 0,
          default_max: 500
        }),
      category:
        Select.new({:category, :id}, "category", %{
          label: "Category",
          options: []
        }),
      min_stock:
        Transformer.new("min_stock", %{
          label: "Minimum Stock",
          render: &__MODULE__.render_min_stock_filter/1,
          query_transformer: {__MODULE__, :apply_min_stock_filter}
        })
    ]
  end

  def table_options do
    %{
      pagination: %{enabled: true, default_size: 2, max_per_page: 5, sizes: [2, 5]},
      sorting: %{enabled: true, default_sort: [name: :asc]},
      exports: %{enabled: false},
      use_streams: true
    }
  end

  def apply_min_stock_filter(query, %{"quantity" => quantity}) when quantity not in ["", nil] do
    min_stock = String.to_integer(quantity)
    from p in query, where: p.stock_quantity >= ^min_stock
  end

  def apply_min_stock_filter(query, _data), do: query

  def render_min_stock_filter(assigns) do
    ~H"""
    <label for={"filters_#{@key}_quantity"}>{@label}</label>
    <input
      id={"filters_#{@key}_quantity"}
      name={"filters[#{@key}][quantity]"}
      value={Map.get(@value, "quantity", "")}
    />
    """
  end

  def render(assigns) do
    ~H"""
    <.live_table
      fields={fields()}
      filters={filters()}
      options={@options}
      streams={@streams}
      actions={actions()}
    />
    """
  end
end

defmodule LiveTable.TestProductNoStreamsLive do
  use Phoenix.LiveView
  use LiveTable.LiveResource, schema: LiveTable.Catalog.Product

  def mount(_params, _session, socket), do: {:ok, socket}

  def fields do
    [
      id: %{label: "ID", sortable: true},
      name: %{label: "Name", sortable: true, searchable: true},
      price: %{label: "Price", sortable: true}
    ]
  end

  def table_options do
    %{
      pagination: %{enabled: true, default_size: 2, max_per_page: 5, sizes: [2, 5]},
      sorting: %{enabled: true, default_sort: [name: :asc]},
      exports: %{enabled: false},
      use_streams: false
    }
  end

  def render(assigns) do
    ~H"""
    <.live_table
      fields={fields()}
      filters={filters()}
      options={@options}
      streams={@resources}
      actions={actions()}
    />
    """
  end
end

defmodule LiveTable.TestProductInfiniteLive do
  use Phoenix.LiveView
  use LiveTable.LiveResource, schema: LiveTable.Catalog.Product

  def mount(_params, _session, socket), do: {:ok, socket}

  def fields do
    [
      id: %{label: "ID", sortable: true},
      name: %{label: "Name", sortable: true, searchable: true},
      price: %{label: "Price", sortable: true}
    ]
  end

  def table_options do
    %{
      pagination: %{
        enabled: true,
        mode: :infinite_scroll,
        default_size: 2,
        max_per_page: 5,
        sizes: [2, 5]
      },
      sorting: %{enabled: true, default_sort: [name: :asc]},
      exports: %{enabled: false},
      mode: :card,
      card_component: &__MODULE__.product_card/1,
      use_streams: true
    }
  end

  def product_card(assigns) do
    ~H"""
    <article>
      <h2>{@record.name}</h2>
      <span>{to_string(@record.price)}</span>
    </article>
    """
  end

  def render(assigns) do
    ~H"""
    <.live_table
      fields={fields()}
      filters={filters()}
      options={@options}
      streams={@streams}
      actions={actions()}
    />
    """
  end
end
