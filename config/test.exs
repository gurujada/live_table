import Config

config :live_table, LiveTable.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "live_table_test",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

config :logger, level: :warning
config :live_table, sql_sandbox: true

config :live_table, :repo, LiveTable.Repo
