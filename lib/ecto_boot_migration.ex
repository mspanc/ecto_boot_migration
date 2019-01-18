defmodule EctoBootMigration do
  @moduledoc """
  Helper module that can be used to easily ensure that Ecto database was
  migrated before rest of the application was started.

  ## Rationale

  There are many strategies how to deal with this issue,
  e.g. see https://github.com/bitwalker/distillery/blob/master/docs/Running%20Migrations.md

  However, if you have any workers that are relying on the DB schema that are
  launched upon boot with some methods, such as release post_start hooks you
  can easily enter race condition. Application may crash as these workers will
  not find tables or columns they expect and it will happen sooner than the
  post_start hook script will send the commands to the the application process.

  In stateless environments such as Docker it is just sometimes more convenient
  to perform migration upon boot. This is exactly what this library does.

  Currently it works only with PostgreSQL databases but that will be easy to
  extend.

  ## Usage

  ```elixir
  defmodule MyApp do
    use Application

    def start(_type, _args) do
      import Supervisor.Spec, warn: false

      {:ok, _} = EctoBootMigration.migrate(:my_app)

      children = [
        supervisor(MyApp.Endpoint, []),
        worker(MyApp.Repo, []),
      ]
      Supervisor.start_link(children, [strategy: :one_for_one, name: MyApp.Supervisor])
    end
  end
  ```

  ## Credits

  Inspired by https://github.com/bitwalker/distillery/blob/master/docs/Running%20Migrations.md
  ```
  """

  @apps [
    :crypto,
    :ssl,
    :postgrex,
    :ecto
  ]

  @doc """
  Tries to run migrations.

  Returns `true` if any migrations have happened.

  Returns `false` if no migrations have happened.

  Throws if error occured.
  """
  @spec migrated?(any) :: boolean
  def migrated?(app) do
    case migrate(app) do
      {:ok, :noop} ->
        false

      {:ok, {:migrated, _}} ->
        true

      {:error, reason} ->
        throw(reason)
    end
  end

  @doc """
  Tries to run migrations.

  Returns `{:ok, {:migrated, list_of_migration_ids}}` if any migrations have
  happened.

  Returns `{:ok, :noop}` if no migrations have happened.

  Returns `{:error, reason}` if error occured.
  """
  @spec migrate(any) ::
          {:ok, :noop}
          | {:ok, {:migrated, [pos_integer]}}
          | {:error, any}
  def migrate(app) do
    log("Loading application #{inspect(app)}...")

    if loaded?(app) do
      start_dependencies()
      repos = Application.get_env(app, :ecto_repos, [])
      repos_pids = start_repos(repos)
      migrations = run_migrations(repos)
      stop_repos(repos_pids)

      log("Done")
      case migrations do
        [] ->
          {:ok, :noop}

        migrations ->
          {:ok, {:migrated, migrations}}
      end
    else
      {:error, :not_loaded}
    end
  end

  def loaded?(app) do
    case Application.load(app) do
      :ok ->
        log("Loaded application #{inspect(app)}")
        true

      {:error, {:already_loaded, ^app}} ->
        log("Application #{inspect(app)} is already loaded")
        true

      {:error, reason} ->
        log("Failed to start the application: reason = #{inspect(reason)}")
        false
    end
  end

  @doc """
  Start the Repo(s) for app, returns pids
  """
  def start_repos(repos) do
    log("Starting repos...")

    repos_pids =
      repos
      |> Enum.reduce([], fn repo, acc ->
        log("Starting repo: #{inspect(repo)}")

        case repo.start_link(pool_size: 2) do
          {:ok, pid} ->
            log("Started repo: pid = #{inspect(pid)}")
            [pid | acc]

          {:error, {:already_started, pid}} ->
            log("Repo was already started: pid = #{inspect(pid)}")
            acc

          {:error, reason} ->
            log("Failed to start the repo: reason = #{inspect(reason)}")
            acc
        end
      end)

    log("Started repos, pids = #{inspect(repos_pids)}")
    repos_pids
  end

  def run_migrations(repos) do
    log("Running migrations")

    migrations =
      repos
      |> Enum.reduce([], fn repo, acc ->
        log("Running migration on repo #{inspect(repo)}")

        result = Ecto.Migrator.run(repo, migrations_path(repo), :up, all: true)
        log("Run migration on repo #{inspect(repo)}: result = #{inspect(result)}")
        acc ++ result
      end)

    log("Run migrations: count = #{length(migrations)}")
    migrations
  end

  @doc """
  Start apps necessary for executing migrations
  """
  def start_dependencies do
    log("Starting dependencies...")

    @apps
    |> Enum.each(fn app ->
      log("Starting dependency: application #{inspect(app)}")
      Application.ensure_all_started(app)
    end)

    log("Started dependencies")
  end

  def stop_repos(repos_pids) do
    log("Cleaning up...")
    log("Stopping repos...")

    repos_pids
    |> Enum.each(fn repo_pid ->
      log("Stopping repo #{inspect(repo_pid)}...")
      Process.exit(repo_pid, :normal)
      log("Stopped repo #{inspect(repo_pid)}")
    end)

    log("Stopped repos")
    log("Cleaned up")
  end

  def log(msg), do: log(msg, debug?())
  def log(msg, true), do: IO.puts("[EctoBootMigration] #{msg}")

  @doc """
  this prevents pre-mature return
  that could cause the main app to exit, because the repos were not 100% shutdown
  """
  def log(_, false), do: Process.sleep(1)

  def debug? do
    Application.get_env(:ecto_boot_migration, :debug, false)
  end

  defp priv_dir(app) do
    "#{:code.priv_dir(app)}"
  end

  defp migrations_path(repo) do
    priv_path_for(repo, "migrations")
  end

  defp priv_path_for(repo, filename) do
    app = Keyword.get(repo.config, :otp_app)
    repo_underscore = repo |> Module.split() |> List.last() |> Macro.underscore()
    Path.join([priv_dir(app), repo_underscore, filename])
  end
end
