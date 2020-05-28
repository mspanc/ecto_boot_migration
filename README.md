# EctoBootMigration

[![Hex.pm](https://img.shields.io/hexpm/v/ecto_boot_migration.svg)](https://hex.pm/packages/ecto_boot_migration)
[![Hex.pm](https://img.shields.io/hexpm/dt/ecto_boot_migration.svg)](https://hex.pm/packages/ecto_boot_migration)

Helper module for Elixir that can be used to easily ensure that Ecto database
was migrated before rest of the application was started.

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

By default if any migrations have happened it will kill the application.
It should be then restarted by any sort of supervisor. It is to avoid cases
in which some internal Ecto caches are populated with pre-migration data
or some processes are started due to migration process that will later
cause issues. This feature can be disabled by passing an argument to
the migration-related functions.

Currently it works only with PostgreSQL databases but that will be easy to
extend.

## Installation

The package can be installed by adding `ecto_boot_migration` to your list of
dependencies in `mix.exs`:

```elixir
def deps do
  [{:ecto_boot_migration, "~> 0.2.0"}]
end
```



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


To see verbose debug output, configure `debug: true`:

```elixir
## in config/config.exs
config :ecto_boot_migration,
  debug: true
```


## Credits

Inspired by https://hexdocs.pm/distillery/guides/running_migrations.html


## License

MIT


## Author

Marcin Lewandowski
