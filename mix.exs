defmodule Modkit.MixProject do
  use Mix.Project

  def project do
    [
      app: :modkit,
      version: "0.1.0",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      modkit: modkit()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.28.0", only: [:dev, :test], runtime: false},
      {:mix_version, "~> 1.3", runtime: false},
      {:mix_test_watch, "~> 1.0", only: [:dev, :test], runtime: false}
    ]
  end

  defp modkit do
    [mount: [{Modkit, "lib/modkit"}, {Mix.Tasks.Mod, "lib/mix/tasks/mod"}]]
  end
end
