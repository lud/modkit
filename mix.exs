defmodule Modkit.MixProject do
  use Mix.Project

  def project do
    [
      app: :modkit,
      version: "0.2.4",
      description: "A set of tool to work with Elixir modules files.",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      package: package(),
      modkit: modkit(),
      source_url: "https://github.com/lud/modkit"
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
      {:mix_test_watch, "~> 1.0", only: [:dev, :test], runtime: false}
    ]
  end

  defp docs do
    [
      filter_modules: fn mod, _ -> "Sample" not in Module.split(mod) end
    ]
  end

  defp modkit do
    [
      mount: [
        {Modkit, "lib/modkit"},
        {Modkit.Sample, "lib/modkit/sample"},
        {Mix.Tasks, {:mix_task, "lib/mix/tasks"}}
      ]
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{
        "Github" => "https://github.com/lud/modkit"
      }
    ]
  end
end
