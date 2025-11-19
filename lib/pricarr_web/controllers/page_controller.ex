defmodule PricarrWeb.PageController do
  use PricarrWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
