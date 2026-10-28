defmodule LiveTable.Repo do
  @moduledoc false
  use Ecto.Repo,
    otp_app: :live_table,
    adapter: Ecto.Adapters.Postgres
end
