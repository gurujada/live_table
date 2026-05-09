defmodule LiveTable.ConnCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      @endpoint LiveTable.TestEndpoint

      import Plug.Conn
      import Phoenix.ConnTest
      import Phoenix.LiveViewTest
      import LiveTable.ConnCase

      alias LiveTable.Repo
    end
  end

  setup tags do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(LiveTable.Repo)

    unless tags[:async] do
      Ecto.Adapters.SQL.Sandbox.mode(LiveTable.Repo, {:shared, self()})
    end

    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end
