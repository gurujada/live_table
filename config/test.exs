import Config

config :live_table, :env, :test
config :live_table, :app, :live_table

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

config :live_table, Oban, testing: :manual

config :live_table, LiveTable.TestEndpoint,
  url: [host: "localhost"],
  secret_key_base: String.duplicate("a", 64),
  live_view: [signing_salt: "live_table_test"],
  debug_errors: true,
  server: false

config :live_table, :pubsub, LiveTable.TestPubSub
