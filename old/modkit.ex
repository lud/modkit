defmodule Modkit do
  def load_current_project do

  end

def main_module_from_project do


  Mix.Project.get!()
  |> Module.split()
  |> :lists.reverse()
  |> then(fn ["MixProject" | rest] -> rest end)
  |> :lists.reverse()
  |> Module.concat()
end
end
