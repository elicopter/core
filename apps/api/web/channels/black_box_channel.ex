defmodule Api.BlackBoxChannel do
  use Phoenix.Channel

  def join("black_box:loop", _message, socket) do
    {:ok, socket}
  end

  def join("black_box:gyroscope", _message, socket) do
    {:ok, socket}
  end

  def join("black_box:accelerometer", _message, socket) do
    {:ok, socket}
  end

  def join("black_box:filter", _message, socket) do
    {:ok, socket}
  end

  def join("black_box:mixer", _message, socket) do
    {:ok, socket}
  end

  def join("black_box:pids", _message, socket) do
    {:ok, socket}
  end
end
