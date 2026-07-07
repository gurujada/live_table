# Transformers API Reference

Transformers are the most powerful feature of LiveTable, allowing you to implement custom filters that can modify the entire query and maintain state. Unlike simple filters that add WHERE conditions, transformers receive the full query and can perform any operations including joins, aggregations, subqueries, and complex transformations.

## Overview

Transformers provide complete control over query modification while maintaining filter state and URL persistence. They are perfect for complex filtering scenarios that go beyond simple field comparisons.

```elixir
def filters do
  [
    # Regular filters
    active: Boolean.new(:active, "active", %{
      label: "Active Only",
      condition: dynamic([p], p.active == true)
    }),
    
    # Transformer - can modify entire query
    sales_performance: Transformer.new("sales_performance", %{
      query_transformer: &apply_sales_filter/2
    })
  ]
end

defp apply_sales_filter(query, filter_data) do
  case filter_data do
    %{"period" => period, "min_sales" => min_sales} ->
      from p in query,
        join: s in Sales, on: s.product_id == p.id,
        where: s.period == ^period and s.total >= ^min_sales,
        group_by: p.id
        
    _ -> 
      query
  end
end
```

## Basic Usage

### Creating a Transformer

```elixir
# Using a function reference
sales_filter: Transformer.new("sales_filter", %{
  query_transformer: &transform_sales_query/2
})

# Using a module and function tuple
analytics_filter: Transformer.new("analytics", %{
  query_transformer: {MyApp.Analytics, :transform_query}
})

# Using an anonymous function
custom_filter: Transformer.new("custom", %{
  query_transformer: fn query, data ->
    # Transform query based on data
    query
  end
})
```

### Transformer Function Signature

Transformer functions receive two arguments:

```elixir
def transform_query(query, filter_data) do
  # query: The current Ecto query
  # filter_data: Map of applied filter data from URL/form
  
  # Return modified query
  query
end
```

## Real-World Examples

### Sales Performance Filter

```elixir
def filters do
  [
    sales_performance: Transformer.new("sales_performance", %{
      query_transformer: &apply_sales_performance/2
    })
  ]
end

defp apply_sales_performance(query, filter_data) do
  case filter_data do
    %{"period" => period, "threshold" => threshold} when period != "" and threshold != "" ->
      {threshold, _} = Integer.parse(threshold)
      
      from p in query,
        join: s in Sale, on: s.product_id == p.id,
        join: pe in SalePeriod, on: pe.sale_id == s.id,
        where: pe.period == ^period,
        group_by: [p.id, p.name, p.price],
        having: sum(s.amount) >= ^threshold,
        select_merge: %{
          total_sales: sum(s.amount),
          sale_count: count(s.id)
        }
        
    _ ->
      query
  end
end
```

### Geographic Region Filter

```elixir
def filters do
  [
    region_analysis: Transformer.new("region_analysis", %{
      query_transformer: {MyApp.Geography, :filter_by_region}
    })
  ]
end

# In your context module
defmodule MyApp.Geography do
  def filter_by_region(query, %{"region" => region, "include_nearby" => "true"}) do
    from p in query,
      join: l in Location, on: l.id == p.location_id,
      join: r in Region, on: r.id == l.region_id,
      left_join: nr in Region, on: nr.parent_id == r.id,
      where: r.name == ^region or nr.name == ^region,
      preload: [location: [region: :parent]]
  end
  
  def filter_by_region(query, %{"region" => region}) do
    from p in query,
      join: l in Location, on: l.id == p.location_id,
      join: r in Region, on: r.id == l.region_id,
      where: r.name == ^region
  end
  
  def filter_by_region(query, _), do: query
end
```

### Date Range with Aggregations

```elixir
def filters do
  [
    date_metrics: Transformer.new("date_metrics", %{
      query_transformer: &apply_date_metrics/2
    })
  ]
end

defp apply_date_metrics(query, filter_data) do
  case filter_data do
    %{"start_date" => start_date, "end_date" => end_date, "metric" => metric} 
    when start_date != "" and end_date != "" ->
      
      {:ok, start_date} = Date.from_iso8601(start_date)
      {:ok, end_date} = Date.from_iso8601(end_date)
      
      case metric do
        "revenue" ->
          from p in query,
            join: o in Order, on: o.product_id == p.id,
            where: o.inserted_at >= ^start_date and o.inserted_at <= ^end_date,
            group_by: [p.id, p.name],
            select_merge: %{
              period_revenue: sum(o.total),
              order_count: count(o.id),
              avg_order_value: avg(o.total)
            }
            
        "popularity" ->
          from p in query,
            join: oi in OrderItem, on: oi.product_id == p.id,
            join: o in Order, on: o.id == oi.order_id,
            where: o.inserted_at >= ^start_date and o.inserted_at <= ^end_date,
            group_by: [p.id, p.name],
            order_by: [desc: count(oi.id)],
            select_merge: %{
              times_ordered: count(oi.id),
              total_quantity: sum(oi.quantity)
            }
            
        _ ->
          query
      end
      
    _ ->
      query
  end
end
```

### College Counselling - Rank-based Filtering

This real-world example shows how to implement complex rank-based filtering for college admissions:

```elixir
defmodule CounsellingWeb.CollegeLive.Index do
  use CounsellingWeb, :live_view
  alias Counselling.Colleges
  alias CounsellingWeb.CollegeLive.CustomHeader
  use LiveTable.LiveResource
  import Ecto.Query

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Colleges")
      |> assign(:data_provider, {Colleges, :list_colleges, []})

    {:ok, socket}
  end

  def fields do
    [
      id: %{label: "ID", sortable: true},
      name: %{label: "College Name", sortable: true, searchable: true},
      location: %{label: "Location", sortable: true, searchable: true}
    ]
  end

  def table_options do
    %{
      mode: :card,
      card_component: &CounsellingWeb.CollegeComponent.college_component/1,
      custom_header: {CustomHeader, :custom_header}
    }
  end

  def filters do
    [
      # Boolean filters for institution types
      iit: Boolean.new(:class, "iit", %{
        label: "IIT",
        condition: dynamic([c], c.class == :IIT)
      }),
      nit: Boolean.new(:class, "nit", %{
        label: "NIT", 
        condition: dynamic([c], c.class == :NIT)
      }),
      
      # Complex rank-based transformer
      rank: Transformer.new("rank", %{
        query_transformer: &rank_filter/2
      }),
      
      # Dynamic sorting transformer
      sort_mode: Transformer.new("sort_mode", %{
        query_transformer: &sort_query/2
      }),
      
      # NIRF ranking limitations
      limit_results: Transformer.new("limit_results", %{
        query_transformer: &limit_results/2
      })
    ]
  end

  # Complex rank filtering with institution-specific adjustments
  def rank_filter(query, %{"value" => ""}) do
    query
  end

  def rank_filter(query, %{"value" => rank}) do
    number = String.to_integer(rank)

    query
    |> where(
      [c, _, rc],
      rc.closing_rank >= ^number or
        rc.closing_rank +
          fragment(
            """
            CASE ?
              WHEN 'IIT' THEN ? * 0.05 *
                CASE WHEN ? <= 1000 THEN 0.8
                     WHEN ? <= 5000 THEN 1.0
                     WHEN ? <= 20000 THEN 1.2
                     ELSE 1.5 END
              WHEN 'NIT' THEN ? * 0.08 *
                CASE WHEN ? <= 1000 THEN 0.8
                     WHEN ? <= 5000 THEN 1.0
                     WHEN ? <= 20000 THEN 1.2
                     ELSE 1.5 END
              WHEN 'IIIT' THEN ? * 0.12 *
                CASE WHEN ? <= 1000 THEN 0.8
                     WHEN ? <= 5000 THEN 1.0
                     WHEN ? <= 20000 THEN 1.2
                     ELSE 1.5 END
              ELSE ? * 0.15 *
                CASE WHEN ? <= 1000 THEN 0.8
                     WHEN ? <= 5000 THEN 1.0
                     WHEN ? <= 20000 THEN 1.2
                     ELSE 1.5 END
            END
            """,
            c.class, rc.closing_rank, rc.closing_rank, rc.closing_rank, rc.closing_rank,
            rc.closing_rank, rc.closing_rank, rc.closing_rank, rc.closing_rank,
            rc.closing_rank, rc.closing_rank, rc.closing_rank, rc.closing_rank,
            rc.closing_rank, rc.closing_rank, rc.closing_rank, rc.closing_rank
          ) >= ^number
    )
  end

  # NIRF ranking filters
  def limit_results(query, %{"nirf" => "Top 10"}) do
    query |> where([_, _, _, nr], nr.nirf_rank <= 10)
  end

  def limit_results(query, %{"nirf" => "Top 25"}) do
    query |> where([_, _, _, nr], nr.nirf_rank <= 25)
  end

  def limit_results(query, %{"nirf" => "All Rankings"}) do
    query
  end

  # Dynamic sorting based on user preference
  def sort_query(query, %{"sort_by" => "NIRF Ranking"}) do
    query |> exclude(:order_by) |> order_by([_, _, _, nr], nr.nirf_rank)
  end

  def sort_query(query, %{"sort_by" => "Name (A-Z)"}) do
    query |> exclude(:order_by) |> order_by([c], c.name)
  end

  def sort_query(query, %{"sort_by" => "Name (Z-A)"}) do
    query |> exclude(:order_by) |> order_by([c], desc: c.name)
  end

  def sort_query(query, _params) do
    query
  end
end
```

### Complex Search with Rankings

```elixir
def filters do
  [
    smart_search: Transformer.new("smart_search", %{
      query_transformer: &apply_smart_search/2
    })
  ]
end

defp apply_smart_search(query, %{"query" => search_term}) when search_term != "" do
  # Complex search with relevance scoring
  from p in query,
    left_join: c in Category, on: c.id == p.category_id,
    left_join: r in Review, on: r.product_id == p.id,
    where: 
      ilike(p.name, ^"%#{search_term}%") or
      ilike(p.description, ^"%#{search_term}%") or
      ilike(c.name, ^"%#{search_term}%"),
    group_by: [p.id, p.name, p.description, p.price],
    order_by: [
      desc: fragment(
        "CASE 
          WHEN ? ILIKE ? THEN 100
          WHEN ? ILIKE ? THEN 75
          WHEN ? ILIKE ? THEN 50
          ELSE 25
        END",
        p.name, ^"#{search_term}%",
        p.name, ^"%#{search_term}%", 
        p.description, ^"%#{search_term}%"
      )
    ],
    select_merge: %{
      relevance_score: fragment(
        "CASE 
          WHEN ? ILIKE ? THEN 100
          WHEN ? ILIKE ? THEN 75  
          WHEN ? ILIKE ? THEN 50
          ELSE 25
        END",
        p.name, ^"#{search_term}%",
        p.name, ^"%#{search_term}%",
        p.description, ^"%#{search_term}%"
      ),
      review_count: count(r.id)
    }
end

defp apply_smart_search(query, _), do: query
```

### Conditional Joins Based on User Role

```elixir
def filters do
  [
    access_control: Transformer.new("access_control", %{
      query_transformer: {MyApp.AccessControl, :apply_user_permissions}
    })
  ]
end

# In your context
defmodule MyApp.AccessControl do
  def apply_user_permissions(query, %{"user_role" => "admin"}) do
    # Admins see everything with additional data
    from p in query,
      left_join: au in AuditLog, on: au.product_id == p.id,
      group_by: [p.id],
      select_merge: %{
        last_modified_by: max(au.user_id),
        modification_count: count(au.id)
      }
  end
  
  def apply_user_permissions(query, %{"user_role" => "manager", "department_id" => dept_id}) do
    # Managers see only their department's products
    from p in query,
      join: d in Department, on: d.id == p.department_id,
      where: d.id == ^dept_id
  end
  
  def apply_user_permissions(query, %{"user_role" => "user"}) do
    # Regular users see only active, public products
    from p in query,
      where: p.active == true and p.public == true
  end
  
  def apply_user_permissions(query, _), do: query
end
```

## State Management

Transformers maintain state through URL parameters and can handle complex form data:

### Form Integration with Custom Header

This example shows how to integrate transformers with a completely custom header component:

```elixir
# Custom Header Component (custom_header.ex)
defmodule CounsellingWeb.CollegeLive.CustomHeader do
  use Phoenix.Component

  def custom_header(assigns) do
    ~H"""
    <section class="relative mb-6 -mt-4 sm:mb-8 sm:-mt-8 lg:mb-12 lg:-mt-12">
      <div class="bg-white dark:bg-gray-800 shadow-2xl border border-gray-100 dark:border-gray-700 rounded-xl sm:rounded-2xl">
        <div class="p-4 sm:p-6 lg:p-8">
          <!-- Main rank input with transformer -->
          <div class="mb-6 p-4 bg-gradient-to-r from-violet-50 to-purple-50 dark:from-violet-900/20 dark:to-purple-900/20 border border-violet-200 dark:border-violet-800 rounded-xl sm:p-6">
            <div class="flex items-center mb-3 sm:mb-4">
              <div class="w-1 h-6 mr-3 bg-gradient-to-b from-violet-500 to-purple-600 rounded-full sm:h-8 sm:mr-4"></div>
              <h3 class="text-lg font-bold text-violet-900 dark:text-violet-100 sm:text-xl">
                Find Colleges for Your Rank
              </h3>
            </div>
            
            <div class="grid gap-3 sm:grid-cols-2 lg:grid-cols-3 sm:gap-4">
              <div>
                <.form
                  for={%{}}
                  id="rank-filter-form"
                  phx-debounce={get_in(@table_options, [:search, :debounce])}
                  phx-change="sort"
                >
                  <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                    Your JEE Rank <span class="text-xs text-gray-500">(Saved automatically, filters all pages)</span>
                  </label>
                  <input
                    type="number"
                    phx-hook="RankInput"
                    id="rank-input"
                    placeholder="e.g., 15000"
                    name="filters[rank][value]"
                    value={
                      Map.get(@options["filters"], :rank) &&
                        Map.get(@options["filters"], :rank).options.applied_data["value"]
                    }
                    class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-700 text-gray-900 dark:text-white rounded-lg focus:ring-2 focus:ring-violet-500 focus:border-violet-500 transition-colors"
                  />
                </.form>
              </div>
              
              <!-- Category selector -->
              <div>
                <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                  Category <span class="text-xs text-gray-500">(Select your reservation category)</span>
                </label>
                <select class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-700 text-gray-900 dark:text-white rounded-lg focus:ring-2 focus:ring-violet-500 focus:border-violet-500 transition-colors">
                  <option>General</option>
                  <option>OBC-NCL</option>
                  <option>SC</option>
                  <option>ST</option>
                  <option>EWS</option>
                </select>
              </div>
            </div>
          </div>

          <!-- Search and filtering controls -->
          <div class="grid gap-4 sm:grid-cols-2 lg:grid-cols-4 mb-6">
            <div>
              <.form
                for={%{}}
                id="college-search-form"
                phx-debounce={get_in(@table_options, [:search, :debounce])}
                phx-change="sort"
              >
                <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                  Search Colleges <span class="text-xs text-gray-500">(By name or location)</span>
                </label>
                <div class="relative">
                  <input
                    type="text"
                    name="search"
                    autocomplete="off"
                    id="college-search"
                    value={@options["filters"]["search"]}
                    placeholder="Search by name or location..."
                    class="w-full pl-10 pr-4 py-2 border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-700 text-gray-900 dark:text-white rounded-lg focus:ring-2 focus:ring-violet-500 focus:border-violet-500 transition-colors"
                  />
                  <svg class="absolute left-3 top-2.5 w-4 h-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"></path>
                  </svg>
                </div>
              </.form>
            </div>

            <!-- NIRF Ranking filter (transformer) -->
            <div>
              <.form
                for={%{}}
                id="nirf-ranking-form"
                phx-debounce={get_in(@table_options, [:search, :debounce])}
                phx-change="sort"
              >
                <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                  NIRF Ranking
                </label>
                <select name="filters[limit_results][nirf]" class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-700 text-gray-900 dark:text-white rounded-lg focus:ring-2 focus:ring-violet-500 focus:border-violet-500 transition-colors">
                  <option selected={
                    Map.get(@options["filters"], :limit_results) &&
                      Map.get(@options["filters"], :limit_results).options.applied_data["nirf"] == "All Rankings"
                  }>All Rankings</option>
                  <option selected={
                    Map.get(@options["filters"], :limit_results) &&
                      Map.get(@options["filters"], :limit_results).options.applied_data["nirf"] == "Top 10"
                  }>Top 10</option>
                  <option selected={
                    Map.get(@options["filters"], :limit_results) &&
                      Map.get(@options["filters"], :limit_results).options.applied_data["nirf"] == "Top 25"
                  }>Top 25</option>
                </select>
              </.form>
            </div>

            <!-- Sort transformer -->
            <div>
              <.form
                for={%{}}
                id="sort-mode-form"
                phx-debounce={get_in(@table_options, [:search, :debounce])}
                phx-change="sort"
              >
                <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                  Sort By <span class="text-xs text-gray-500">(Change display order)</span>
                </label>
                <select name="filters[sort_mode][sort_by]" class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-700 text-gray-900 dark:text-white rounded-lg focus:ring-2 focus:ring-violet-500 focus:border-violet-500 transition-colors">
                  <option>NIRF Ranking</option>
                  <option>Name (A-Z)</option>
                  <option>Name (Z-A)</option>
                </select>
              </.form>
            </div>
          </div>

          <!-- Boolean filters for institution types -->
          <div class="mb-4">
            <.form
              for={%{}}
              id="institution-type-form"
              phx-debounce={get_in(@table_options, [:search, :debounce])}
              phx-change="sort"
            >
              <span class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-3">
                Institution Type <span class="text-xs text-gray-500">(IIT = Premier institutes, NIT = National institutes, IIIT = Information technology, GFTI = Government funded)</span>
              </span>
              <div class="flex flex-wrap gap-x-6">
                <.input
                  :for={{id, %Boolean{field: :class, options: %{label: label}}} <- @filters}
                  type="checkbox"
                  name={"filters[#{id}]"}
                  label={label}
                  checked={Map.has_key?(@options["filters"], id)}
                />
              </div>
            </.form>
          </div>

          <!-- Clear filters -->
          <div class="flex items-center justify-end pt-4 border-t border-gray-200 dark:border-gray-600 h-6">
            <.link
              :if={@options["filters"] != %{"search" => ""}}
              phx-click="sort"
              phx-value-clear_filters="true"
              class="my-auto text-sm text-gray-500 hover:text-gray-700 dark:text-gray-400 dark:hover:text-gray-300 transition-colors"
            >
              Clear All Filters
            </.link>
          </div>
        </div>
      </div>
    </section>
    """
  end
end

# Helper function for accessing transformer values
defp get_transformer_value(filters, transformer_key, field_key) do
  case Map.get(filters, transformer_key) do
    %LiveTable.Transformer{options: %{applied_data: data}} ->
      Map.get(data, field_key, "")
    _ ->
      ""
  end
end
```

### Event Handling

```elixir
def handle_event("update_transformer", %{"sales_performance" => params}, socket) do
  # Update transformer state without applying
  {:noreply, socket}
end

def handle_event("apply_transformer", %{"sales_performance" => params}, socket) do
  # Apply transformer by updating URL parameters
  {:noreply, 
   push_patch(socket, 
     to: ~p"/products?#{%{"sales_performance" => params}}"
   )}
end
```

## Advanced Patterns

### Chaining Transformers

```elixir
def filters do
  [
    # First transformer: Add time-based filtering
    time_filter: Transformer.new("time_filter", %{
      query_transformer: &apply_time_filter/2
    }),
    
    # Second transformer: Add performance metrics  
    performance_metrics: Transformer.new("performance", %{
      query_transformer: &add_performance_metrics/2
    }),
    
    # Third transformer: Apply sorting/ranking
    ranking: Transformer.new("ranking", %{
      query_transformer: &apply_ranking/2
    })
  ]
end

# Transformers are applied in order defined
```

### Conditional Transformer Application

```elixir
defp apply_analytics_transformer(query, filter_data) do
  # Only apply if user has analytics permission
  if has_analytics_access?(filter_data) do
    from p in query,
      join: a in Analytics, on: a.product_id == p.id,
      select_merge: %{
        conversion_rate: a.conversion_rate,
        bounce_rate: a.bounce_rate,
        avg_session_duration: a.avg_session_duration
      }
  else
    query
  end
end

defp has_analytics_access?(%{"user_permissions" => permissions}) do
  "analytics" in permissions
end

defp has_analytics_access?(_), do: false
```

### Error Handling

```elixir
defp safe_transformer(query, filter_data) do
  try do
    apply_complex_transformation(query, filter_data)
  rescue
    e in Ecto.Query.CompileError ->
      Logger.error("Query compilation error in transformer: #{inspect(e)}")
      query
      
    e ->
      Logger.error("Unexpected error in transformer: #{inspect(e)}")
      query
  end
end
```

## Performance Considerations

### Efficient Query Building

```elixir
# ✅ Good: Build query incrementally
defp apply_multi_condition_filter(query, filter_data) do
  query
  |> maybe_add_time_filter(filter_data)
  |> maybe_add_category_filter(filter_data)
  |> maybe_add_metrics(filter_data)
end

defp maybe_add_time_filter(query, %{"date_range" => range}) when range != "" do
  # Add time-based filtering
  query
end

defp maybe_add_time_filter(query, _), do: query

# ❌ Avoid: Complex nested conditions in single query
```

### Database Index Optimization

```sql
-- Add indexes for transformer queries
CREATE INDEX idx_sales_product_period ON sales(product_id, period);
CREATE INDEX idx_orders_date_status ON orders(inserted_at, status);
CREATE INDEX idx_products_category_active ON products(category_id, active);
```

## Debugging Transformers

### Query Inspection

```elixir
defp debug_transformer(query, filter_data) do
  result_query = apply_transformation(query, filter_data)
  
  # Log the generated SQL (in development)
  if Mix.env() == :dev do
    IO.inspect(Ecto.Adapters.SQL.to_sql(:all, Repo, result_query), label: "Transformer Query")
  end
  
  result_query
end
```

### State Debugging

```elixir
def handle_event("debug_transformers", _params, socket) do
  transformers = socket.assigns.filters
  |> Enum.filter(fn {_, filter} -> 
    match?(%LiveTable.Transformer{}, filter)
  end)
  
  IO.inspect(transformers, label: "Active Transformers")
  {:noreply, socket}
end
```

## Best Practices

### 1. Keep Transformers Focused
```elixir
# ✅ Good: Single responsibility
sales_filter: Transformer.new("sales", %{
  query_transformer: &add_sales_filtering/2
})

metrics_calculator: Transformer.new("metrics", %{
  query_transformer: &add_performance_metrics/2
})

# ❌ Avoid: Doing everything in one transformer
```

### 2. Handle Empty/Invalid Data
```elixir
defp apply_filter(query, filter_data) do
  case filter_data do
    %{"field" => value} when value != "" and not is_nil(value) ->
      # Apply transformation
      transform_query(query, value)
    _ ->
      # Return unchanged query for invalid/empty data
      query
  end
end
```

### 3. Use Type Safety
```elixir
defp apply_numeric_filter(query, %{"amount" => amount_str}) do
  case Integer.parse(amount_str || "") do
    {amount, ""} when amount > 0 ->
      from p in query, where: p.amount >= ^amount
    _ ->
      query
  end
end
```

### 4. Document Complex Logic
```elixir
defp apply_complex_business_logic(query, filter_data) do
  # This transformer implements the "Premium Customer Analysis" requirements:
  # 1. Customers with orders > $1000 in last 6 months
  # 2. Include loyalty points and tier information  
  # 3. Calculate lifetime value with predictive scoring
  
  case filter_data do
    %{"analysis_type" => "premium"} ->
      # Implementation here...
  end
end
```

## Troubleshooting

### Common Issues

**Transformer not applying:**
- Check that transformer key in URL matches filter definition
- Verify transformer function exists and is accessible
- Ensure filter_data is in expected format

**Query compilation errors:**
- Check that all referenced tables/fields exist
- Verify join conditions are correct
- Test transformer functions in isolation

**Performance issues:**
- Add database indexes for transformer queries
- Use `explain analyze` to check query execution plans
- Consider breaking complex transformers into simpler ones

**State not persisting:**
- Verify transformer key is included in URL parameters
- Check that form field names match expected data structure
- Ensure the LiveView uses the LiveResource macro and does not override LiveTable's generated `handle_params/3`

Transformers provide unlimited flexibility for complex filtering scenarios while maintaining the simplicity and URL persistence that makes LiveTable powerful.
