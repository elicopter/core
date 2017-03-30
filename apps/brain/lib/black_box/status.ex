defmodule Brain.BlackBox.Status do
  defmacro __using__(_opts) do
    quote do
      defp system_status do
        {uptime, _} = :erlang.statistics(:wall_clock)
        {:ok, %{
          memory: :erlang.memory() |> Enum.into(%{}),
          processes: processes(),
          uptime: uptime
        }}
      end

      defp status(%{status: status, loops_recording: loops_recording} = state) do
        loops_recording = false
        with {:ok, system_status} <- system_status(),
             internal_status      <- Map.merge(system_status, %{loops_recording: loops_recording}) do
          {:ok, Map.merge(status, internal_status)}
        end
      end

      defp processes do
        Process.list |> Enum.reduce([], fn(pid, acc) ->
          process_info = Process.info(pid)
          process_info = %{
            name:               process_info[:registered_name],
            stack_size:         process_info[:stack_size],
            message_queue_size: process_info[:message_queue_len],
            heap_size:          process_info[:heap_size],
            memory:             process_info[:memory],
            status:             process_info[:status]
          }
          case process_info[:name] do
            name when is_atom(name) or is_binary(name) ->
              [process_info | acc]
            _ -> acc
          end
        end) |> Enum.filter(fn (process) -> process_selected?(process[:name]) end)
      end

      defp process_selected?(process_name) do
        process_name = "#{process_name}"
        process_name |> String.contains?("Brain")
      end
    end
  end
end
