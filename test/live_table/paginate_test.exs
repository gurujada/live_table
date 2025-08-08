defmodule LiveTable.PaginateTest do
  use LiveTable.DataCase
  alias LiveTable.Paginate

  describe "maybe_paginate/3" do
    test "returns original query when pagination is disabled" do
      base_query = from(u in "users")
      paginate_params = %{"per_page" => "10", "page" => "1"}
      result = Paginate.maybe_paginate(base_query, paginate_params, false)
      assert result == base_query
    end

    test "applies pagination when enabled" do
      base_query = from(u in "users")
      paginate_params = %{"per_page" => "10", "page" => "1"}
      result = Paginate.maybe_paginate(base_query, paginate_params, true)
      query_string = inspect(result)
      assert query_string =~ "limit: ^11"
      assert query_string =~ "offset: ^0"
    end
  end

  describe "paginate/2" do
    test "applies correct limit and offset for first page" do
      base_query = from(u in "users")
      paginate_params = %{"per_page" => "10", "page" => "1"}
      result = Paginate.paginate(base_query, paginate_params)
      query_string = inspect(result)
      assert query_string =~ "limit: ^11"
      assert query_string =~ "offset: ^0"
    end

    test "applies correct limit and offset for second page" do
      base_query = from(u in "users")
      paginate_params = %{"per_page" => "10", "page" => "2"}
      result = Paginate.paginate(base_query, paginate_params)
      query_string = inspect(result)
      assert query_string =~ "limit: ^11"
      assert query_string =~ "offset: ^1"
    end

    test "handles string inputs correctly" do
      base_query = from(u in "users")
      paginate_params = %{"per_page" => "5", "page" => "3"}
      result = Paginate.paginate(base_query, paginate_params)
      query_string = inspect(result)
      assert query_string =~ "limit: ^6"
      assert query_string =~ "offset: ^10"
    end

    test "prevents negative offset" do
      base_query = from(u in "users")
      paginate_params = %{"per_page" => "10", "page" => "-1"}
      result = Paginate.paginate(base_query, paginate_params)
      query_string = inspect(result)
      assert query_string =~ "limit: ^11"
      assert query_string =~ "offset: ^0"
    end
  end
end
