defmodule Plug.Adapters.Cowboy.Handler do
  @moduledoc false
  @connection Plug.Adapters.Cowboy.Conn
  @already_sent {:plug_conn, :sent}

  def init({transport, :http}, req, {plug, opts}) when transport in [:tcp, :ssl] do
    {:upgrade, :protocol, __MODULE__, req, {transport, plug, opts}}
  end

  def upgrade(req, env, __MODULE__, {transport, plug, opts}) do
    conn = @connection.conn(req, transport)
    try do
      %{adapter: {@connection, req}} =
        conn
        |> plug.call(opts)
        |> maybe_send(plug)

      {:ok, req, [{:result, :ok} | env]}
    catch
      :error, value ->
        stack = System.stacktrace()
        exception = Exception.normalize(:error, value, stack)
        reason = {{exception, stack}, {plug, :call, [conn, opts]}}
        terminate(reason, req, stack)
      :throw, value ->
        stack = System.stacktrace()
        reason = {{{:nocatch, value}, stack}, {plug, :call, [conn, opts]}}
        terminate(reason, req, stack)
      :exit, value ->
        stack = System.stacktrace()
        reason = {value, {plug, :call, [conn, opts]}}
        terminate(reason, req, stack)
    after
      receive do
        @already_sent -> :ok
      after
        0 -> :ok
      end
    end
  end

  defp maybe_send(%Plug.Conn{state: :unset}, _plug),      do: raise Plug.Conn.NotSentError
  defp maybe_send(%Plug.Conn{state: :set} = conn, _plug), do: Plug.Conn.send_resp(conn)
  defp maybe_send(%Plug.Conn{} = conn, _plug),            do: conn
  defp maybe_send(other, plug) do
    raise "Cowboy adapter expected #{inspect plug} to return Plug.Conn but got: #{inspect other}"
  end

  defp terminate(reason, req, stack) do
    :cowboy_req.maybe_reply(stack, req)
    exit(reason)
  end
end
