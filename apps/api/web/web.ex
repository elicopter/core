defmodule Api.Web do
  def model do
    quote do
    end
  end

  def controller do
    quote do
      use Phoenix.Controller

      import Api.Router.Helpers
    end
  end

  def view do
    quote do
      use Phoenix.View, root: "web/templates"

      import Phoenix.Controller, only: [get_csrf_token: 0, view_module: 1]

      import Api.Router.Helpers
      import Api.ErrorHelpers
    end
  end

  def router do
    quote do
      use Phoenix.Router
    end
  end

  def channel do
    quote do
      use Phoenix.Channel
    end
  end

  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
