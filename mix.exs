defmodule EctoBootMigration.Mixfile do
  use Mix.Project

  def project do
    [app: :ecto_boot_migration,
     version: "0.1.2",
     elixir: "~> 1.4",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps(),
     description: description(),
     package: package(),
    ]
  end

  def application do
    # Specify extra applications you'll use from Erlang/Elixir
    [extra_applications: [:logger]]
  end


  defp deps do
    [
      {:ecto, ">= 0.0.0"},
      {:ex_doc, ">= 0.0.0", only: :dev},
    ]
  end

  defp description do
    """
    Tool for running Ecto migrations upon boot of the Elixir application.
    """
  end

  defp package do
    [
     files: ["lib", "mix.exs", "README*"],
     maintainers: ["Marcin Lewandowski"],
     licenses: ["MIT"],
     links: %{"GitHub" => "https://github.com/mspanc/ecto_boot_migration"},
   ]
  end
end
