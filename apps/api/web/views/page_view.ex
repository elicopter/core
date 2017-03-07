defmodule Api.PageView do
  use Api.Web, :view

  def render("index.json", _) do
    %{
      name: "Elicopter"
    }
  end
end
