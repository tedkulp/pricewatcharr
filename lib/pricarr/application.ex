defmodule Pricarr.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      PricarrWeb.Telemetry,
      Pricarr.Repo,
      {Ecto.Migrator,
       repos: Application.fetch_env!(:pricarr, :ecto_repos), skip: skip_migrations?()},
      {DNSCluster, query: Application.get_env(:pricarr, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Pricarr.PubSub},
      # Start Oban for background job processing
      {Oban, Application.fetch_env!(:pricarr, Oban)},
      # Start a worker by calling: Pricarr.Worker.start_link(arg)
      # {Pricarr.Worker, arg},
      # Start to serve requests, typically the last entry
      PricarrWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Pricarr.Supervisor]

    case Supervisor.start_link(children, opts) do
      {:ok, pid} ->
        # Schedule price checks for any URLs that are overdue
        # Small delay to ensure Repo is ready
        Task.start(fn ->
          Process.sleep(1000)

          try do
            IO.puts(">>> Starting scheduler...")
            result = Pricarr.Workers.Scheduler.schedule_due_checks()
            IO.puts(">>> Scheduler result: #{inspect(result)}")
          rescue
            e ->
              IO.puts(">>> Scheduler error: #{inspect(e)}")
              IO.puts(">>> Stacktrace: #{inspect(__STACKTRACE__)}")
          end
        end)
        {:ok, pid}

      error ->
        error
    end
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    PricarrWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp skip_migrations?() do
    # By default, sqlite migrations are run when using a release
    System.get_env("RELEASE_NAME") == nil
  end
end
