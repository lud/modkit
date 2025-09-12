defmodule ModkitDemo.MixProject do
  use Mix.Project

  def project do
    [
      app: :modkit_demo,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:modkit, path: Path.expand("../..")}
    ]
  end
end
