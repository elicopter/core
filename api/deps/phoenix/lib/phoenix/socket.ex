defmodule Phoenix.Socket do
  @moduledoc ~S"""
  Defines a socket and its state.

  `Phoenix.Socket` is used as a module for establishing and maintaining
  the socket state via the `Phoenix.Socket` struct.

  Once connected to a socket, incoming and outgoing events are routed to
  channels. The incoming client data is routed to channels via transports.
  It is the responsibility of the socket to tie transports and channels
  together.

  By default, Phoenix supports both websockets and longpoll transports.
  For example:

      transport :websocket, Phoenix.Transports.WebSocket

  The command above means incoming socket connections can be done via
  the WebSocket transport. Events are routed by topic to channels:

      channel "room:lobby", MyApp.LobbyChannel

  See `Phoenix.Channel` for more information on channels. Check each
  transport module to check the options specific to each transport.

  ## Socket Behaviour

  Socket handlers are mounted in Endpoints and must define two callbacks:

    * `connect/2` - receives the socket params and authenticates the connection.
      Must return a `Phoenix.Socket` struct, often with custom assigns.
    * `id/1` - receives the socket returned by `connect/2` and returns the
      id of this connection as a string. The `id` is used to identify socket
      connections, often to a particular user, allowing us to force disconnections.
      For sockets requiring no authentication, `nil` can be returned.

  ## Examples

      defmodule MyApp.UserSocket do
        use Phoenix.Socket

        transport :websocket, Phoenix.Transports.WebSocket
        channel "room:*", MyApp.RoomChannel

        def connect(params, socket) do
          {:ok, assign(socket, :user_id, params["user_id"])}
        end

        def id(socket), do: "users_socket:#{socket.assigns.user_id}"
      end

      # Disconnect all user's socket connections and their multiplexed channels
      MyApp.Endpoint.broadcast("users_socket:" <> user.id, "disconnect", %{})

  ## Socket Fields

    * `id` - The string id of the socket
    * `assigns` - The map of socket assigns, default: `%{}`
    * `channel` - The current channel module
    * `channel_pid` - The channel pid
    * `endpoint` - The endpoint module where this socket originated, for example: `MyApp.Endpoint`
    * `handler` - The socket module where this socket originated, for example: `MyApp.UserSocket`
    * `joined` - If the socket has effectively joined the channel
    * `pubsub_server` - The registered name of the socket's pubsub server
    * `ref` - The latest ref sent by the client
    * `topic` - The string topic, for example `"room:123"`
    * `transport` - The socket's transport, for example: `Phoenix.Transports.WebSocket`
    * `transport_pid` - The pid of the socket's transport process
    * `transport_name` - The socket's transport, for example: `:websocket`
    * `serializer` - The serializer for socket messages,
      for example: `Phoenix.Transports.WebSocketSerializer`

  ## Custom transports

  See the `Phoenix.Socket.Transport` documentation for more information on
  writing your own transports.
  """

  alias Phoenix.Socket

  @doc """
  Receives the socket params and authenticates the connection.

  ## Socket params and assigns

  Socket params are passed from the client and can
  be used to verify and authenticate a user. After
  verification, you can put default assigns into
  the socket that will be set for all channels, ie

      {:ok, assign(socket, :user_id, verified_user_id)}

  To deny connection, return `:error`.

  See `Phoenix.Token` documentation for examples in
  performing token verification on connect.
  """
  @callback connect(params :: map, Socket.t) :: {:ok, Socket.t} | :error

  @doc ~S"""
  Identifies the socket connection.

  Socket id's are topics that allow you to identify all sockets for a given user:

      def id(socket), do: "users_socket:#{socket.assigns.user_id}"

  Would allow you to broadcast a "disconnect" event and terminate
  all active sockets and channels for a given user:

      MyApp.Endpoint.broadcast("users_socket:" <> user.id, "disconnect", %{})

  Returning `nil` makes this socket anonymous.
  """
  @callback id(Socket.t) :: String.t | nil

  defmodule InvalidMessageError do
    @moduledoc """
    Raised when the socket message is invalid.
    """
    defexception [:message]
  end

  @type t :: %Socket{id: nil,
                     assigns: %{},
                     channel: atom,
                     channel_pid: pid,
                     endpoint: atom,
                     handler: atom,
                     joined: boolean,
                     pubsub_server: atom,
                     ref: term,
                     topic: String.t,
                     transport: atom,
                     transport_name: atom,
                     serializer: atom,
                     transport_pid: pid}

  defstruct id: nil,
            assigns: %{},
            channel: nil,
            channel_pid: nil,
            endpoint: nil,
            handler: nil,
            joined: false,
            pubsub_server: nil,
            ref: nil,
            topic: nil,
            transport: nil,
            transport_pid: nil,
            transport_name: nil,
            serializer: nil

  defmacro __using__(_) do
    quote do
      @behaviour Phoenix.Socket
      import unquote(__MODULE__)
      Module.register_attribute(__MODULE__, :phoenix_channels, accumulate: true)
      @phoenix_transports %{}
      @before_compile unquote(__MODULE__)
    end
  end

  defmacro __before_compile__(env) do
    transports = Module.get_attribute(env.module, :phoenix_transports)
    channels   = Module.get_attribute(env.module, :phoenix_channels)

    transport_defs =
      for {name, {mod, conf}} <- transports do
        quote do
          def __transport__(unquote(name)) do
            {unquote(mod), unquote(conf)}
          end
        end
      end

    channel_defs =
      for {topic_pattern, module, opts} <- channels do
        topic_pattern
        |> to_topic_match
        |> defchannel(module, opts[:via])
      end

    quote do
      def __transports__, do: unquote(Macro.escape(transports))
      unquote(transport_defs)
      unquote(channel_defs)
      def __channel__(_topic, _transport), do: nil
    end
  end

  defp to_topic_match(topic_pattern) do
    case String.split(topic_pattern, "*") do
      [prefix, ""] -> quote do: <<unquote(prefix) <> _rest>>
      [bare_topic] -> bare_topic
      _            -> raise ArgumentError, "channels using splat patterns must end with *"
    end
  end

  defp defchannel(topic_match, channel_module, nil) do
    quote do
      def __channel__(unquote(topic_match), _transport), do: unquote(channel_module)
    end
  end

  defp defchannel(topic_match, channel_module, transports) do
    quote do
      def __channel__(unquote(topic_match), transport)
          when transport in unquote(List.wrap(transports)), do: unquote(channel_module)
    end
  end

  @doc """
  Adds key/value pair to socket assigns.

  ## Examples

      iex> socket.assigns[:token]
      nil
      iex> socket = assign(socket, :token, "bar")
      iex> socket.assigns[:token]
      "bar"

  """
  def assign(socket = %Socket{}, key, value) do
    put_in socket.assigns[key], value
  end

  @doc """
  Defines a channel matching the given topic and transports.

    * `topic_pattern` - The string pattern, for example "room:*", "users:*", "system"
    * `module` - The channel module handler, for example `MyApp.RoomChannel`
    * `opts` - The optional list of options, see below

  ## Options

    * `:via` - the transport adapters to accept on this channel.
      Defaults `[:websocket, :longpoll]`

  ## Examples

      channel "topic1:*", MyChannel
      channel "topic2:*", MyChannel, via: [:websocket]
      channel "topic",    MyChannel, via: [:longpoll]

  ## Topic Patterns

  The `channel` macro accepts topic patterns in two flavors. A splat argument
  can be provided as the last character to indicate a "topic:subtopic" match. If
  a plain string is provied, only that topic will match the channel handler.
  Most use-cases will use the "topic:*" pattern to allow more versatile topic
  scoping.

  See `Phoenix.Channel` for more information
  """
  defmacro channel(topic_pattern, module, opts \\ []) do
    # Tear the alias to simply store the root in the AST.
    # This will make Elixir unable to track the dependency
    # between endpoint <-> socket and avoid recompiling the
    # endpoint (alongside the whole project ) whenever the
    # socket changes.
    module = tear_alias(module)

    quote do
      @phoenix_channels {unquote(topic_pattern), unquote(module), unquote(opts)}
    end
  end

  defp tear_alias({:__aliases__, meta, [h|t]}) do
    alias = {:__aliases__, meta, [h]}
    quote do
      Module.concat([unquote(alias)|unquote(t)])
    end
  end
  defp tear_alias(other), do: other

  @doc """
  Defines a transport with configuration.

  ## Examples

      # customize default `:websocket` transport options
      transport :websocket, Phoenix.Transports.WebSocket,
        timeout: 10_000

      # define separate transport, using websocket handler
      transport :websocket_slow_clients, Phoenix.Transports.WebSocket,
        timeout: 60_000

  """
  defmacro transport(name, module, config \\ []) do
    quote do
      @phoenix_transports Phoenix.Socket.__transport__(
        @phoenix_transports, unquote(name), unquote(module), unquote(config))
    end
  end

  @doc false
  def __transport__(transports, name, module, config) do
    config = Keyword.merge(module.default_config() , config)

    Map.update(transports, name, {module, config}, fn {dup_module, _} ->
      raise ArgumentError,
        "duplicate transports (#{inspect dup_module} and #{inspect module}) defined for #{inspect name}."
    end)
  end
end
