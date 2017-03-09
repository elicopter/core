defmodule Phoenix.PubSub do
  @moduledoc """
  Front-end to Phoenix pubsub layer.

  Used internally by Channels for pubsub broadcast but
  also provides an API for direct usage.

  ## Adapters

  Phoenix pubsub was designed to be flexible and support
  multiple backends. We currently ship with two backends:

    * `Phoenix.PubSub.PG2` - uses Distributed Elixir,
      directly exchanging notifications between servers

    * `Phoenix.PubSub.Redis` - uses Redis to exchange
      data between servers

  Pubsub adapters are often configured in your endpoint:

      config :my_app, MyApp.Endpoint,
        pubsub: [adapter: Phoenix.PubSub.PG2,
                 pool_size: 1,
                 name: MyApp.PubSub]

  The configuration above takes care of starting the
  pubsub backend and exposing its functions via the
  endpoint module. If no adapter but a name is given,
  nothing will be started, but the pubsub system will
  work by sending events and subscribing to the given
  name.

  ## Direct usage

  It is also possible to use `Phoenix.PubSub` directly
  or even run your own pubsub backends outside of an
  Endpoint.

  The first step is to start the adapter of choice in your
  supervision tree:

      supervisor(Phoenix.PubSub.Redis, [:my_pubsub, host: "192.168.100.1"])

  The configuration above will start a Redis pubsub and
  register it with name `:my_pubsub`.

  You can now use the functions in this module to subscribe
  and broadcast messages:

      iex> PubSub.subscribe :my_pubsub, self, "user:123"
      :ok
      iex> Process.info(self)[:messages]
      []
      iex> PubSub.broadcast :my_pubsub, "user:123", {:user_update, %{id: 123, name: "Shane"}}
      :ok
      iex> Process.info(self)[:messages]
      {:user_update, %{id: 123, name: "Shane"}}

  ## Implementing your own adapter

  PubSub adapters run inside their own supervision tree.
  If you are interested in providing your own adapter,  let's
  call it `Phoenix.PubSub.MyQueue`, the first step is to provide
  a supervisor module that receives the server name and a bunch
  of options on `start_link/2`:

      defmodule Phoenix.PubSub.MyQueue do
        def start_link(name, options) do
          Supervisor.start_link(__MODULE__, {name, options},
                                name: Module.concat(name, Supervisor))
        end

        def init({name, options}) do
          ...
        end
      end

  On `init/1`, you will define the supervision tree and use the given
  `name` to register the main pubsub process locally. This process must
  be able to handle the following GenServer calls:

    * `subscribe` - subscribes the given pid to the given topic
      sends:        `{:subscribe, pid, topic, opts}`
      respond with: `:ok | {:error, reason} | {:perform, {m, f, a}}`

    * `unsubscribe` - unsubscribes the given pid from the given topic
      sends:        `{:unsubscribe, pid, topic}`
      respond with: `:ok | {:error, reason} | {:perform, {m, f, a}}`

    * `broadcast` - broadcasts a message on the given topic
      sends:        `{:broadcast, :none | pid, topic, message}`
      respond with: `:ok | {:error, reason} | {:perform, {m, f, a}}`

  ### Offloading work to clients via MFA response

  The `Phoenix.PubSub` API allows any of its functions to handle a
  response from the adapter matching `{:perform, {m, f, a}}`. The PubSub
  client will recursively invoke all MFA responses until a result is
  returned. This is useful for offloading work to clients without blocking
  your PubSub adapter. See `Phoenix.PubSub.PG2` implementation for examples.
  """

  @type node_name :: atom :: binary

  defmodule BroadcastError do
    defexception [:message]
    def exception(msg) do
      %BroadcastError{message: "broadcast failed with #{inspect msg}"}
    end
  end

  @doc """
  Subscribes the caller to the PubSub adapter's topic.

    * `server` - The Pid registered name of the server
    * `topic` - The topic to subscribe to, ie: `"users:123"`
    * `opts` - The optional list of options. See below.

  ## Duplicate Subscriptions

  Callers should only subscribe to a given topic a single time.
  Duplicate subscriptions for a Pid/topic pair are allowed and
  will cause duplicate events to be sent; however, when using
  `Phoenix.PubSub.unsubscribe/3`, all duplicate subscriptions
  will be dropped.

  ## Options

    * `:link` - links the subscriber to the pubsub adapter
    * `:fastlane` - Provides a fastlane path for the broadcasts for
      `%Phoenix.Socket.Broadcast{}` events. The fastlane process is
      notified of a cached message instead of the normal subscriber.
      Fastlane handlers must implement `fastlane/1` callbacks which accepts
      a `Phoenix.Socket.Broadcast` structs and returns a fastlaned format
      for the handler. For example:

          PubSub.subscribe(MyApp.PubSub, "topic1",
            fastlane: {fast_pid, Phoenix.Transports.WebSocketSerializer, ["event1"]})
  """
  @spec subscribe(atom, pid, binary, Keyword.t) :: :ok | {:error, term}
  def subscribe(server, pid, topic)
    when is_atom(server) and is_pid(pid) and is_binary(topic) do
    subscribe(server, pid, topic, [])
  end
  @spec subscribe(atom, binary, Keyword.t) :: :ok | {:error, term}
  def subscribe(server, topic, opts)
    when is_atom(server) and is_binary(topic) and is_list(opts) do
    call(server, :subscribe, [self(), topic, opts])
  end
  @spec subscribe(atom, binary) :: :ok | {:error, term}
  def subscribe(server, topic) when is_atom(server) and is_binary(topic) do
    subscribe(server, topic, [])
  end
  @spec subscribe(atom, pid, binary, Keyword.t) :: :ok | {:error, term}
  def subscribe(server, pid, topic, opts) do
    IO.write :stderr, "[warning] Passing a Pid to Phoenix.PubSub.subscribe is deprecated. " <>
                      "Only the calling process may subscribe to topics"
    call(server, :subscribe, [pid, topic, opts])
  end

  @doc """
  Unsubscribes the caller from the PubSub adapter's topic.
  """
  @spec unsubscribe(atom, pid, binary) :: :ok | {:error, term}
  def unsubscribe(server, pid, topic) when is_atom(server) do
    IO.write :stderr, "[warning] Passing a Pid to Phoenix.PubSub.unsubscribe is deprecated. " <>
                      "Only the calling process may unsubscribe from topics"
    call(server, :unsubscribe, [pid, topic])
  end

  @spec unsubscribe(atom, binary) :: :ok | {:error, term}
  def unsubscribe(server, topic) when is_atom(server) do
    call(server, :unsubscribe, [self(), topic])
  end

  @doc """
  Broadcasts message on given topic.

    * `server` - The Pid or registered server name and optional node to
      scope the broadcast, for example: `MyApp.PubSub`, `{MyApp.PubSub, :a@node}`
    * `topic` - The topic to broadcast to, ie: `"users:123"`
    * `message` - The payload of the broadcast

  """
  @spec broadcast(atom, binary, term) :: :ok | {:error, term}
  def broadcast(server, topic, message) when is_atom(server) or is_tuple(server),
    do: call(server, :broadcast, [:none, topic, message])


  @doc """
  Broadcasts message on given topic, to a single node.

    * `node` - The name of the node to broadcast the message on
    * `server` - The Pid or registered server name and optional node to
      scope the broadcast, for example: `MyApp.PubSub`, `{MyApp.PubSub, :a@node}`
    * `topic` - The topic to broadcast to, ie: `"users:123"`
    * `message` - The payload of the broadcast

  """
  @spec direct_broadcast(node_name, atom, binary, term) :: :ok | {:error, term}
  def direct_broadcast(node_name, server, topic, message) when is_atom(server),
    do: call(server, :direct_broadcast, [node_name, :none, topic, message])

  @doc """
  Broadcasts message on given topic.

  Raises `Phoenix.PubSub.BroadcastError` if broadcast fails.
  See `Phoenix.PubSub.broadcast/3` for usage details.
  """
  @spec broadcast!(atom, binary, term) :: :ok | no_return
  def broadcast!(server, topic, message) do
    case broadcast(server, topic, message) do
      :ok -> :ok
      {:error, reason} -> raise BroadcastError, message: reason
    end
  end

  @doc """
  Broadcasts message on given topic, to a single node.

  Raises `Phoenix.PubSub.BroadcastError` if broadcast fails.
  See `Phoenix.PubSub.broadcast/3` for usage details.
  """
  @spec direct_broadcast!(node_name, atom, binary, term) :: :ok | no_return
  def direct_broadcast!(node_name, server, topic, message) do
    case direct_broadcast(node_name, server, topic, message) do
      :ok -> :ok
      {:error, reason} -> raise BroadcastError, message: reason
    end
  end

  @doc """
  Broadcasts message to all but `from_pid` on given topic.
  See `Phoenix.PubSub.broadcast/3` for usage details.
  """
  @spec broadcast_from(atom, pid, binary, term) :: :ok | {:error, term}
  def broadcast_from(server, from_pid, topic, message) when is_atom(server) and is_pid(from_pid),
    do: call(server, :broadcast, [from_pid, topic, message])

  @doc """
  Broadcasts message to all but `from_pid` on given topic, to a single node.
  See `Phoenix.PubSub.broadcast/3` for usage details.
  """
  @spec direct_broadcast_from(node_name, atom, pid, binary, term) :: :ok | {:error, term}
  def direct_broadcast_from(node_name, server, from_pid, topic, message)
    when is_atom(server) and is_pid(from_pid),
    do: call(server, :direct_broadcast, [node_name, from_pid, topic, message])

  @doc """
  Broadcasts message to all but `from_pid` on given topic.

  Raises `Phoenix.PubSub.BroadcastError` if broadcast fails.
  See `Phoenix.PubSub.broadcast/3` for usage details.
  """
  @spec broadcast_from!(atom | {atom, atom}, pid, binary, term) :: :ok | no_return
  def broadcast_from!(server, from_pid, topic, message) when is_atom(server) and is_pid(from_pid) do
    case broadcast_from(server, from_pid, topic, message) do
      :ok -> :ok
      {:error, reason} -> raise BroadcastError, message: reason
    end
  end

  @doc """
  Broadcasts message to all but `from_pid` on given topic, to a single node.

  Raises `Phoenix.PubSub.BroadcastError` if broadcast fails.
  See `Phoenix.PubSub.broadcast/3` for usage details.
  """
  @spec direct_broadcast_from!(node_name, atom, pid, binary, term) :: :ok | no_return
  def direct_broadcast_from!(node_name, server, from_pid, topic, message)
    when is_atom(server) and is_pid(from_pid) do

    case direct_broadcast_from(node_name, server, from_pid, topic, message) do
      :ok -> :ok
      {:error, reason} -> raise BroadcastError, message: reason
    end
  end

  @doc """
  Returns the node name of the PubSub server.
  """
  @spec node_name(atom) :: atom :: binary
  def node_name(server) do
    call(server, :node_name, [])
  end

  defp call(server, kind, args) do
    [{^kind, module, head}] = :ets.lookup(server, kind)
    apply(module, kind, head ++ args)
  end
end
