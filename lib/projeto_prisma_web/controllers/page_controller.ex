defmodule ProjetoPrismaWeb.PageController do
  use ProjetoPrismaWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
