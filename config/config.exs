import Config

config :live_table,
  ecto_repos: [LiveTable.Repo]

config :esbuild,
  version: "0.17.11",
  live_table: [
    args: ~w(
       js/hooks/hooks.js
       --bundle
       --target=es2017
       --format=esm
       --outfile=../priv/static/live-table.js
     ),
    cd: Path.expand("../assets", __DIR__)
  ]

import_config "#{config_env()}.exs"
