defmodule Api.ErrorView do
  use Api.Web, :view

  def render("404.json", _assigns) do
    %{}
  end

  def render("500.json", _assigns) do
    %{}
  end

  def template_not_found(_template, assigns) do
    render "500.json", assigns
  end
end
