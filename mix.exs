defmodule Modkit.MixProject do
  use Mix.Project

  def project do
    [
      app: :modkit,
      version: "0.6.1",
      description: "A set of tool to work with Elixir modules files.",
      elixir: "~> 1.13",
      consolidate_protocols: Mix.env() != :test,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      package: package(),
      modkit: modkit(),
      dialyzer: dialyzer(),
      versioning: versioning(),
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
      {:cli_mate, "~> 0.6", runtime: false},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev, :test], runtime: false},
      {:ex_doc, ">= 0.0.0", only: [:dev, :test], runtime: false}
    ]
  end

  defp docs do
    [
      filter_modules: fn mod, _ -> "Sample" not in Module.split(mod) end
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

  defp modkit do
    [
      mount: [
        {Modkit, "lib/modkit"},
        {Mix.Tasks, "lib/mix/tasks", flavor: :mix_task},
        {Samples, :ignore}
      ]
    ]
  end

  defp versioning do
    [
      annotate: true,
      before_commit: [
        fn vsn ->
          case System.cmd("git", ["cliff", "--tag", vsn, "-o", "CHANGELOG.md"],
                 stderr_to_stdout: true
               ) do
            {_, 0} -> IO.puts("Updated CHANGELOG.md with #{vsn}")
            {out, _} -> {:error, "Could not update CHANGELOG.md:\n\n #{out}"}
          end
        end,
        add: "CHANGELOG.md"
      ]
    ]
  end

  defp dialyzer do
    [
      flags: [:unmatched_returns, :error_handling, :unknown, :extra_return],
      list_unused_filters: true,
      plt_add_apps: [:mix],
      plt_local_path: "_build/plts"
    ]
  end

  def cli do
    [
      preferred_envs: [dialyzer: :test]
    ]
  end
end
