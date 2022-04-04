defmodule Modkit.PathTool do
  def list_create_dirs(path) when is_binary(path) do
    list_create_dirs([path])
  end

  def list_create_dirs(paths) when is_list(paths) do
    paths
    |> Enum.reduce(MapSet.new(), &dir_to_create/2)
    |> MapSet.to_list()
  end

  defp dir_to_create(".", acc), do: acc

  defp dir_to_create(path, acc) do
    cond do
      File.dir?(path) ->
        acc

      File.regular?(path) ->
        raise ArgumentError, "cannot create directory #{path}, file exists"

      MapSet.member?(acc, path) ->
        acc

      :_ ->
        acc = dir_to_create(Path.dirname(path), acc)
        MapSet.put(acc, path)
    end
  end
end
