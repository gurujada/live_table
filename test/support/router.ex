defmodule LiveTable.TestRouter do
  use Phoenix.Router
  import Phoenix.LiveView.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, false
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  scope "/" do
    pipe_through :browser

    live "/products", LiveTable.TestProductLive
    live "/products_no_streams", LiveTable.TestProductNoStreamsLive
    live "/products_infinite", LiveTable.TestProductInfiniteLive
  end
end
