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
       --alias:live_select=#{Path.expand("../deps/live_select/priv/static/live_select.min.js", __DIR__)}
       --alias:nouislider=#{Path.expand("../assets/vendor/nouislider.mjs", __DIR__)}
       --alias:nouislider/dist/nouislider.css=#{Path.expand("../assets/vendor/nouislider.css", __DIR__)}
     ),
    cd: Path.expand("../assets", __DIR__)
  ],
  live_table_css: [
    args: ~w(
      css/live-table.css
      --bundle
      --outfile=../priv/static/live-table.css
      --loader:.css=css
      --alias:nouislider/dist/nouislider.css=#{Path.expand("../assets/vendor/nouislider.css", __DIR__)}
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

import_config "#{config_env()}.exs"
