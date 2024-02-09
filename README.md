# EctoBootMigration

[![Hex.pm](https://img.shields.io/hexpm/v/ecto_boot_migration.svg)](https://hex.pm/packages/ecto_boot_migration)
[![Hex.pm](https://img.shields.io/hexpm/dt/ecto_boot_migration.svg)](https://hex.pm/packages/ecto_boot_migration)

Helper module for Elixir that can be used to easily ensure that Ecto database
was migrated before rest of the application was started.

## Rationale

In stateless environments such as Docker it is just sometimes more convenient
to perform migration upon boot. This is exactly what this library does.

Currently it works only with PostgreSQL databases but that will be easy to
extend.

## Installation

The package can be installed by adding `ecto_boot_migration` to your list of
dependencies in `mix.exs`:

```elixir
def deps do
  [{:ecto_boot_migration, "~> 0.3.0"}]
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
