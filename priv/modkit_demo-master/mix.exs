defmodule ModkitDemo.MixProject do
  use Mix.Project

  def project do
    [
      app: :modkit_demo,
      version: "0.1.0",
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "dev", "test/support"]
  defp elixirc_paths(_), do: ["lib", "dev"]

  defp deps do
    [
      {:modkit, path: System.fetch_env!("MODKIT_DEP_ROOT")}
    ]
  end
end
