import Config

config :live_table,
  ecto_repos: [LiveTable.Repo]

import_config "#{config_env()}.exs"
