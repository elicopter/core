defmodule Api.UserSocket do
  use Phoenix.Socket

  ## Channels
  channel "black_box:*", Api.BlackBoxChannel
  channel "sensors:*", Api.SensorsChannel

  ## Transports
  transport :websocket, Phoenix.Transports.WebSocket

  def connect(params, socket) do
    {:ok, socket}
  end

  def id(_socket), do: nil
end
