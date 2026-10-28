defmodule LiveTable.TestApplication do
  @moduledoc false
  use Application

  def start(_type, _args) do
    children =
      if Application.get_env(:live_table, :env) == :test do
        [
          LiveTable.Repo,
          {Phoenix.PubSub, name: LiveTable.TestPubSub},
          LiveTable.TestEndpoint
        ]
      else
        []
      end

    opts = [strategy: :one_for_one, name: LiveTable.TestSupervisor]
    Supervisor.start_link(children, opts)
  end
end
