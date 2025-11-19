defmodule Pricarr.Repo do
  use Ecto.Repo,
    otp_app: :pricarr,
    adapter: Ecto.Adapters.SQLite3
end
