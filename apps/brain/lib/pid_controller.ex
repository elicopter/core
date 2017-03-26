defmodule Brain.PIDController do
  use GenServer
  require Logger
  alias Brain.{ BlackBox, Storage }

  def init(_) do
    {:ok, configuration} = load_configuration()
    IO.inspect configuration
    {:ok, Map.merge(configuration,
      %{
        sample_rate: @sample_rate,
        last_input: 0,
        integrative_term: 0,
        setpoint: 0,
        process_name: Process.info(self())[:registered_name],
        last_timestamp: nil
      })
    }
  end

  def start_link(opts) do
    Logger.debug "Starting #{__MODULE__}..."
    GenServer.start_link(__MODULE__, nil, opts)
  end

  def handle_call(:snapshot, _from, state) do
    snapshot = %{
      name: state[:process_name] |> Module.split |> List.last,
      kp: state[:kp],
      ki: state[:ki],
      kd: state[:kd],
      minimum_output: state[:minimum_output],
      maximum_output: state[:maximum_output]
    }
    {:reply, {:ok, snapshot}, state}
  end

  def handle_call({:compute, input, setpoint, sample_rate}, _from, state) do
    sample_rate_in_seconds = sample_rate / 1000
    error             = setpoint - input
    proportional_term = state[:kp] * error
    integrative_term  = state[:integrative_term] + (state[:ki] * sample_rate_in_seconds) * error
    derivative_term   = (state[:kd] / sample_rate_in_seconds) * (input - state[:last_input])

    # integrative_term = min(integrative_term, state[:maximum_output])
    # integrative_term = max(integrative_term, state[:minimum_output])

    output = proportional_term + integrative_term - derivative_term
    output = min(output, state[:maximum_output])
    output = max(output, state[:minimum_output])

    trace(state, error, output, proportional_term, integrative_term, derivative_term)

    {:reply, {:ok, output}, Map.merge(state, %{
      integrative_term: integrative_term,
      last_input: input
    })}
  end

  def handle_cast({:tune, %{kp: kp, ki: ki, kd: kd}}, state) do
    state = Map.merge(state, %{
      kp: kp,
      ki: ki,
      kd: kd
    })
    Logger.info "#{__MODULE__} (#{state[:process_name]}) tuned to kp: #{kp}, ki: #{ki}, kd: #{kd}..."
    :ok = save_configuration(state)
    {:noreply, state}
  end

  def handle_cast({:tune, %{kp: kp}}, state) do
    state = Map.merge(state, %{
      kp: kp
    })
    Logger.info "#{__MODULE__} (#{state[:process_name]}) tuned to kp: #{kp}..."
    :ok = save_configuration(state)
    {:noreply, state}
  end

  def handle_cast({:tune, %{ki: ki}}, state) do
    state = Map.merge(state, %{
      ki: ki
    })
    Logger.info "#{__MODULE__} (#{state[:process_name]}) tuned to ki: #{ki}..."
    :ok = save_configuration(state)
    {:noreply, state}
  end

  def handle_cast({:tune, %{kd: kd}}, state) do
    state = Map.merge(state, %{
      kd: kd,
    })
    Logger.info "#{__MODULE__} (#{state[:process_name]}) tuned to kd: #{kd}..."
    :ok = save_configuration(state)
    {:noreply, state}
  end

  def handle_cast({:reset, _}, state) do
    new_state = %{
      integrative_term: 0
    }
    Logger.info "#{__MODULE__} (#{state[:process_name]}) reinitialized..."
    {:noreply, Map.merge(state, new_state)}
  end

  defp trace(state, error, output, proportional_term, integrative_term, derivative_term) do
    data = %{
      kp: state[:kp],
      ki: state[:ki],
      kd: state[:kd],
      proportional_term: proportional_term,
      integrative_term: integrative_term,
      derivative_term: derivative_term,
      error: error,
      output: output
    }
    BlackBox.trace(__MODULE__, Process.info(self())[:registered_name], data)
  end

  def compute(pid, input, setpoint, sample_rate) do
    GenServer.call(pid, {:compute, input, setpoint, sample_rate})
  end

  def configure(pid, configuration) do
    GenServer.call(pid, Tuple.insert_at(configuration, 0, :configure))
  end

  def snapshot(pid) do
    GenServer.call(pid, :snapshot)
  end

  defp load_configuration do
    process_name  = Process.info(self())[:registered_name]
    configuration = case Storage.retreive do
      {:ok, nil} ->
        Logger.debug("#{process_name} loaded default configuration.")
        Application.get_env(:brain, process_name)
      {:ok, saved_configuration} ->
        Logger.debug("#{process_name} loaded saved configuration.")
        saved_configuration
    end
    {:ok,
      %{
        kp: (configuration[:kp] || configuration["kp"]),
        ki: (configuration[:ki] || configuration["ki"]),
        kd: (configuration[:kd] || configuration["kd"]),
        minimum_output: configuration[:minimum_output] || configuration["minimum_output"],
        maximum_output: configuration[:maximum_output] || configuration["maximum_output"]
      }
    }
  end

  defp save_configuration(state) do
    Storage.store(%{
      kp: state[:kp],
      ki: state[:ki],
      kd: state[:kd],
      minimum_output: state[:minimum_output],
      maximum_output: state[:maximum_output]
    })
  end
end
