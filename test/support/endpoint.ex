defmodule LiveTable.TestEndpoint do
  use Phoenix.Endpoint, otp_app: :live_table

  @session_options [
    store: :cookie,
    key: "_live_table_test_key",
    signing_salt: "live_table_test"
  ]

  socket "/live", Phoenix.LiveView.Socket,
    websocket: [connect_info: [session: @session_options]],
    longpoll: [connect_info: [session: @session_options]]

  plug Plug.Session, @session_options
  plug LiveTable.TestRouter
end
