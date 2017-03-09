defmodule Phoenix.Router do
  defmodule NoRouteError do
    @moduledoc """
    Exception raised when no route is found.
    """
    defexception plug_status: 404, message: "no route found", conn: nil, router: nil

    def exception(opts) do
      conn   = Keyword.fetch!(opts, :conn)
      router = Keyword.fetch!(opts, :router)
      path   = "/" <> Enum.join(conn.path_info, "/")

      %NoRouteError{message: "no route found for #{conn.method} #{path} (#{inspect router})",
                    conn: conn, router: router}
    end
  end

  @moduledoc """
  Defines a Phoenix router.

  The router provides a set of macros for generating routes
  that dispatch to specific controllers and actions. Those
  macros are named after HTTP verbs. For example:

      defmodule MyApp.Router do
        use Phoenix.Router

        get "/pages/:page", PageController, :show
      end

  The `get/3` macro above accepts a request of format `"/pages/VALUE"` and
  dispatches it to the show action in the `PageController`.

  Routes can also match glob-like patterns, routing any path with a common
  base to the same controller. For example:

      get "/dynamic*anything", DynamicController, :show

  Phoenix's router is extremely efficient, as it relies on Elixir
  pattern matching for matching routes and serving requests.

  ### Helpers

  Phoenix automatically generates a module `Helpers` inside your router
  which contains named helpers to help developers generate and keep
  their routes up to date.

  Helpers are automatically generated based on the controller name.
  For example, the route:

      get "/pages/:page", PageController, :show

  will generate the following named helper:

      MyApp.Router.Helpers.page_path(conn_or_endpoint, :show, "hello")
      "/pages/hello"

      MyApp.Router.Helpers.page_path(conn_or_endpoint, :show, "hello", some: "query")
      "/pages/hello?some=query"

      MyApp.Router.Helpers.page_url(conn_or_endpoint, :show, "hello")
      "http://example.com/pages/hello"

      MyApp.Router.Helpers.page_url(conn_or_endpoint, :show, "hello", some: "query")
      "http://example.com/pages/hello?some=query"

  If the route contains glob-like patterns, parameters for those have to be given as
  list:

      MyApp.Router.Helpers.dynamic_path(conn_or_endpoint, :show, ["dynamic", "something"])
      "/dynamic/something"

  The url generated in the named url helpers is based on the configuration for
  `:url`, `:http` and `:https`.

  The named helper can also be customized with the `:as` option. Given
  the route:

      get "/pages/:page", PageController, :show, as: :special_page

  the named helper will be:

      MyApp.Router.Helpers.special_page_path(conn, :show, "hello")
      "/pages/hello"

  ### Scopes and Resources

  The router also supports scoping of routes:

      scope "/api/v1", as: :api_v1 do
        get "/pages/:id", PageController, :show
      end

  For example, the route above will match on the path `"/api/v1/pages/:id"`
  and the named route will be `api_v1_page_path`, as expected from the
  values given to `scope/2` option.

  Phoenix also provides a `resources/4` macro that allows developers
  to generate "RESTful" routes to a given resource:

      defmodule MyApp.Router do
        use Phoenix.Router

        resources "/pages", PageController, only: [:show]
        resources "/users", UserController, except: [:delete]
      end

  Finally, Phoenix ships with a `mix phoenix.routes` task that nicely
  formats all routes in a given router. We can use it to verify all
  routes included in the router above:

      $ mix phoenix.routes
      page_path  GET    /pages/:id       PageController.show/2
      user_path  GET    /users           UserController.index/2
      user_path  GET    /users/:id/edit  UserController.edit/2
      user_path  GET    /users/new       UserController.new/2
      user_path  GET    /users/:id       UserController.show/2
      user_path  POST   /users           UserController.create/2
      user_path  PATCH  /users/:id       UserController.update/2
                 PUT    /users/:id       UserController.update/2

  One can also pass a router explicitly as an argument to the task:

      $ mix phoenix.routes MyApp.Router

  Check `scope/2` and `resources/4` for more information.

  ## Pipelines and plugs

  Once a request arrives at the Phoenix router, it performs
  a series of transformations through pipelines until the
  request is dispatched to a desired end-point.

  Such transformations are defined via plugs, as defined
  in the [Plug](http://github.com/elixir-lang/plug) specification.
  Once a pipeline is defined, it can be piped through per scope.

  For example:

      defmodule MyApp.Router do
        use Phoenix.Router

        pipeline :browser do
          plug :fetch_session
          plug :accepts, ["html"]
        end

        scope "/" do
          pipe_through :browser

          # browser related routes and resources
        end
      end

  `Phoenix.Router` imports functions from both `Plug.Conn` and `Phoenix.Controller`
  to help define plugs. In the example above, `fetch_session/2`
  comes from `Plug.Conn` while `accepts/2` comes from `Phoenix.Controller`.

  Note that router pipelines are only invoked after a route is found.
  No plug is invoked in case no matches were found.

  """

  alias Phoenix.Router.Resource
  alias Phoenix.Router.Scope
  alias Phoenix.Router.Route
  alias Phoenix.Router.Helpers

  @http_methods [:get, :post, :put, :patch, :delete, :options, :connect, :trace, :head]

  @doc false
  defmacro __using__(_) do
    quote do
      unquote(prelude())
      unquote(defs())
      unquote(match_dispatch())
    end
  end

  defp prelude() do
    quote do
      Module.register_attribute __MODULE__, :phoenix_routes, accumulate: true
      @phoenix_forwards %{}

      import Phoenix.Router
      import Plug.Conn
      import Phoenix.Controller

      # Set up initial scope
      @phoenix_pipeline nil
      Phoenix.Router.Scope.init(__MODULE__)
      @before_compile unquote(__MODULE__)
    end
  end

  # Because those macros are executed multiple times,
  # we end-up generating a huge scope that drastically
  # affects compilation. We work around it by defining
  # those functions only once and calling it over and
  # over again.
  defp defs() do
    quote unquote: false do
      var!(add_resources, Phoenix.Router) = fn resource ->
        path = resource.path
        ctrl = resource.controller
        opts = resource.route

        if resource.singleton do
          Enum.each resource.actions, fn
            :show    -> get    path,            ctrl, :show, opts
            :new     -> get    path <> "/new",  ctrl, :new, opts
            :edit    -> get    path <> "/edit", ctrl, :edit, opts
            :create  -> post   path,            ctrl, :create, opts
            :delete  -> delete path,            ctrl, :delete, opts
            :update  ->
              patch path, ctrl, :update, opts
              put   path, ctrl, :update, Keyword.put(opts, :as, nil)
          end
        else
          param = resource.param

          Enum.each resource.actions, fn
            :index   -> get    path,                             ctrl, :index, opts
            :show    -> get    path <> "/:" <> param,            ctrl, :show, opts
            :new     -> get    path <> "/new",                   ctrl, :new, opts
            :edit    -> get    path <> "/:" <> param <> "/edit", ctrl, :edit, opts
            :create  -> post   path,                             ctrl, :create, opts
            :delete  -> delete path <> "/:" <> param,            ctrl, :delete, opts
            :update  ->
              patch path <> "/:" <> param, ctrl, :update, opts
              put   path <> "/:" <> param, ctrl, :update, Keyword.put(opts, :as, nil)
          end
        end
      end
    end
  end

  defp match_dispatch() do
    quote location: :keep do
      @behaviour Plug

      @doc """
      Callback required by Plug that initializes the router
      for serving web requests.
      """
      def init(opts) do
        opts
      end

      @doc """
      Callback invoked by Plug on every request.
      """
      def call(conn, opts), do: do_call(conn, opts)

      defp match_route(conn, []) do
        match_route(conn, conn.method, Enum.map(conn.path_info, &URI.decode/1), conn.host)
      end

      defp dispatch(conn, []) do
        try do
          conn.private.phoenix_route.(conn)
        catch
          kind, reason ->
            Plug.Conn.WrapperError.reraise(conn, kind, reason)
        end
      end

      defoverridable [init: 1, call: 2]
    end
  end

  @anno (if :erlang.system_info(:otp_release) >= '19' do
    [generated: true]
  else
    [line: -1]
  end)

  @doc false
  defmacro __before_compile__(env) do
    routes = env.module |> Module.get_attribute(:phoenix_routes) |> Enum.reverse
    routes_with_exprs = Enum.map(routes, &{&1, Route.exprs(&1)})

    Helpers.define(env, routes_with_exprs)
    matches = Enum.map(routes_with_exprs, &build_match/1)

    plugs = [{:dispatch, [], true}, {:match_route, [], true}]
    {conn, pipeline} = Plug.Builder.compile(env, plugs, [])

    call =
      quote do
        unquote(conn) =
          update_in unquote(conn).private,
            &(&1 |> Map.put(:phoenix_pipelines, [])
                 |> Map.put(:phoenix_router, __MODULE__)
                 |> Map.put(__MODULE__, {unquote(conn).script_name, @phoenix_forwards}))
        unquote(pipeline)
      end

    # @anno is used here to avoid warnings if forwarding to root path
    match_404 =
      quote @anno do
        defp match_route(conn, _method, _path_info, _host) do
          raise NoRouteError, conn: conn, router: __MODULE__
        end
      end

    quote do
      defp do_call(%Plug.Conn{private: %{phoenix_bypass: {__MODULE__, pipes}}} = conn, _opts) do
        Phoenix.Router.__bypass__(conn, __MODULE__, pipes)
      end
      defp do_call(%Plug.Conn{private: %{phoenix_bypass: :all}} = conn, _opts) do
        conn
      end
      defp do_call(unquote(conn), opts) do
        unquote(call)
      end

      @doc false
      def __routes__,  do: unquote(Macro.escape(routes))

      @doc false
      def __helpers__, do: __MODULE__.Helpers

      unquote(matches)
      unquote(match_404)
    end
  end

  defp build_match({_route, exprs}) do
    quote do
      defp match_route(var!(conn), unquote(exprs.verb_match), unquote(exprs.path),
                 unquote(exprs.host)) do
        unquote(exprs.dispatch)
      end
    end
  end

  @doc """
  Generates a route match based on an arbitrary HTTP method

  Useful for defining routes not included in the builtin macros:

  #{Enum.map_join(@http_methods, ", ", &"`#{&1}`")}

  ## Examples

      match(:move, "/events/:id", EventController, :move)

  """
  defmacro match(verb, path, plug, plug_opts, options \\ []) do
    add_route(:match, verb, path, plug, plug_opts, options)
  end

  for verb <- @http_methods do
    @doc """
    Generates a route to handle a #{verb} request to the given path.
    """
    defmacro unquote(verb)(path, plug, plug_opts, options \\ []) do
      verb = unquote(verb)
      quote bind_quoted: binding() do
        match(verb, path, plug, plug_opts, options)
      end
    end
  end

  defp add_route(kind, verb, path, plug, plug_opts, options) do
    quote do
      @phoenix_routes Scope.route(__MODULE__, unquote(kind), unquote(verb), unquote(path),
                                  unquote(plug), unquote(plug_opts), unquote(options))
    end
  end

  @doc """
  Defines a plug pipeline.

  Pipelines are defined at the router root and can be used
  from any scope.

  ## Examples

      pipeline :api do
        plug :token_authentication
        plug :dispatch
      end

  A scope may then use this pipeline as:

      scope "/" do
        pipe_through :api
      end

  Every time `pipe_through/1` is called, the new pipelines
  are appended to the ones previously given.
  """
  defmacro pipeline(plug, do: block) do
    block =
      quote do
        plug = unquote(plug)
        @phoenix_pipeline []
        unquote(block)
      end

    compiler =
      quote unquote: false do
        Scope.pipeline(__MODULE__, plug)
        {conn, body} = Plug.Builder.compile(__ENV__, @phoenix_pipeline, [])
        def unquote(plug)(unquote(conn), _) do
          try do
            unquote(body)
          catch
            kind, reason ->
              Plug.Conn.WrapperError.reraise(unquote(conn), kind, reason)
          end
        end
        @phoenix_pipeline nil
      end

    quote do
      try do
        unquote(block)
        unquote(compiler)
      after
        :ok
      end
    end
  end

  @doc """
  Defines a plug inside a pipeline.

  See `pipeline/2` for more information.
  """
  defmacro plug(plug, opts \\ []) do
    quote do
      if pipeline = @phoenix_pipeline do
        @phoenix_pipeline [{unquote(plug), unquote(opts), true}|pipeline]
      else
        raise "cannot define plug at the router level, plug must be defined inside a pipeline"
      end
    end
  end

  @doc """
  Defines a pipeline to send the connection through.

  See `pipeline/2` for more information.
  """
  defmacro pipe_through(pipes) do
    quote do
      if pipeline = @phoenix_pipeline do
        raise "cannot pipe_through inside a pipeline"
      else
        Scope.pipe_through(__MODULE__, unquote(pipes))
      end
    end
  end

  @doc """
  Defines "RESTful" routes for a resource.

  The given definition:

      resources "/users", UserController

  will include routes to the following actions:

    * `GET /users` => `:index`
    * `GET /users/new` => `:new`
    * `POST /users` => `:create`
    * `GET /users/:id` => `:show`
    * `GET /users/:id/edit` => `:edit`
    * `PATCH /users/:id` => `:update`
    * `PUT /users/:id` => `:update`
    * `DELETE /users/:id` => `:delete`

  ## Options

  This macro accepts a set of options:

    * `:only` - a list of actions to generate routes for, for example: `[:show, :edit]`
    * `:except` - a list of actions to exclude generated routes from, for example: `[:delete]`
    * `:param` - the name of the parameter for this resource, defaults to `"id"`
    * `:name` - the prefix for this resource. This is used for the named helper
      and as the prefix for the parameter in nested resources. The default value
      is automatically derived from the controller name, i.e. `UserController` will
      have name `"user"`
    * `:as` - configures the named helper exclusively
    * `:singleton` - defines routes for a singleton resource that is looked up by
      the client without referencing an ID. Read below for more information

  ## Singleton resources

  When a resource needs to be looked up without referencing an ID, because
  it contains only a single entry in the given context, the `:singleton`
  option can be used to generate a set of routes that are specific to
  such single resource:

    * `GET /user` => `:show`
    * `GET /user/new` => `:new`
    * `POST /user` => `:create`
    * `GET /user/edit` => `:edit`
    * `PATCH /user` => `:update`
    * `PUT /user` => `:update`
    * `DELETE /user` => `:delete`

    Usage example:

      `resources "/account", AccountController, only: [:show], singleton: true`

  """
  defmacro resources(path, controller, opts, do: nested_context) do
    add_resources path, controller, opts, do: nested_context
  end

  @doc """
  See `resources/4`.
  """
  defmacro resources(path, controller, do: nested_context) do
    add_resources path, controller, [], do: nested_context
  end

  @doc """
  See `resources/4`.
  """
  defmacro resources(path, controller, opts) do
    add_resources path, controller, opts, do: nil
  end

  @doc """
  See `resources/4`.
  """
  defmacro resources(path, controller) do
    add_resources path, controller, [], do: nil
  end

  defp add_resources(path, controller, options, do: context) do
    scope =
      if context do
        quote do
          scope resource.member, do: unquote(context)
        end
      end

    quote do
      resource = Resource.build(unquote(path), unquote(controller), unquote(options))
      var!(add_resources, Phoenix.Router).(resource)
      unquote(scope)
    end
  end

  @doc """
  Defines a scope in which routes can be nested.

  ## Examples

      scope "/api/v1", as: :api_v1, alias: API.V1 do
        get "/pages/:id", PageController, :show
      end

  The generated route above will match on the path `"/api/v1/pages/:id"`
  and will dispatch to `:show` action in `API.V1.PageController`. A named
  helper `api_v1_page_path` will also be generated.

  ## Options

  The supported options are:

    * `:path` - a string containing the path scope
    * `:as` - a string or atom containing the named helper scope
    * `:alias` - an alias (atom) containing the controller scope
    * `:host` - a string containing the host scope, or prefix host scope,
      ie `"foo.bar.com"`, `"foo."`
    * `:private` - a map of private data to merge into the connection when a route matches
    * `:assigns` - a map of data to merge into the connection when a route matches

  """
  defmacro scope(options, do: context) do
    do_scope(options, context)
  end

  @doc """
  Define a scope with the given path.

  This function is a shortcut for:

      scope path: path do
        ...
      end

  """
  defmacro scope(path, options, do: context) do
    options = quote do
      path = unquote(path)
      case unquote(options) do
        alias when is_atom(alias) -> [path: path, alias: alias]
        options when is_list(options) -> Keyword.put(options, :path, path)
      end
    end
    do_scope(options, context)
  end

  @doc """
  Defines a scope with the given path and alias.

  This function is a shortcut for:

      scope path: path, alias: alias do
        ...
      end

  """
  defmacro scope(path, alias, options, do: context) do
    options = quote do
      unquote(options)
      |> Keyword.put(:path, unquote(path))
      |> Keyword.put(:alias, unquote(alias))
    end
    do_scope(options, context)
  end

  defp do_scope(options, context) do
    quote do
      Scope.push(__MODULE__, unquote(options))
      try do
        unquote(context)
      after
        Scope.pop(__MODULE__)
      end
    end
  end

  @doc """
  Forwards a request at the given path to a plug.

  All paths that matches the forwarded prefix will be sent to
  the forwarded plug. This is useful to share router between
  applications or even break a big router into smaller ones.
  The router pipelines will be invoked prior to forwarding the
  connection.

  The forwarded plug will be initialized at compile time.

  Note, however, that we don't advise forwarding to another
  endpoint. The reason is that plugs defined by your app
  and the forwarded endpoint would be invoked twice, which
  may lead to errors.

  ## Examples

      scope "/", MyApp do
        pipe_through [:browser, :admin]

        forward "/admin", SomeLib.AdminDashboard
        forward "/api", ApiRouter
      end

  """
  defmacro forward(path, plug, plug_opts \\ [], router_opts \\ []) do
    router_opts = Keyword.put(router_opts, :as, nil)

    quote unquote: true, bind_quoted: [path: path, plug: plug] do
      path_segments = Route.forward_path_segments(path, plug, @phoenix_forwards)
      @phoenix_forwards Map.put(@phoenix_forwards, plug, path_segments)
      unquote(add_route(:forward, :*, path, plug, plug_opts, router_opts))
    end
  end

  @doc false
  def __bypass__(conn, router, pipes) do
    Enum.reduce(pipes, conn, fn pipe, acc -> apply(router, pipe, [acc, []]) end)
  end
end
