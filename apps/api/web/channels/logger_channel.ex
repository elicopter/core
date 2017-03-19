defmodule Api.LoggerChannel do
  use Phoenix.Channel
  def join(_, _message, socket) do
    {:ok, socket}
  end
end
