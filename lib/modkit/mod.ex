defmodule Modkit.Mod do
  def current_path(module, relative_to \\ File.cwd!()) do
    if Code.ensure_loaded?(module) do
      source = Keyword.fetch!(module.module_info(:compile), :source) |> List.to_string()
      Path.relative_to(source, relative_to)
    else
      raise ArgumentError, "could not find module #{inspect(module)}"
    end
  end

  def list_all(otp_app) do
    case :application.get_key(otp_app, :modules) do
      {:ok, mods} ->
        mods

      :undefined ->
        raise ArgumentError, """
        could not list modules from application #{inspect(otp_app)}.

        Are you in a mix project?
        """
    end
  end

  def group_by_file(modules, relative_to \\ File.cwd!()) do
    Enum.group_by(modules, &current_path(&1, relative_to))
  end

  @doc """
  Given two module names, returns the module name that is a prefix of the other,
  or `nil` if the two names are disjoint.

  See `local_root/1`.

  ### Examples

      iex> local_root(A, A.B)
      A

      iex> local_root(A.B, A.C)
      nil
  """
  @spec local_root(module, module) :: module | nil
  def local_root(a, b) do
    local_root([a, b])
  end

  @doc """
  Returns the module that is a local root of all given modules. That is a common
  prefix of all given modules that is also a module from the list.

  For instance, modules `A` and `A.B` have a common prefix that is `A`, and `A`
  is provided as an argument, so it will be returned.

  But if only `A.B` and `A.C` are provided, the common prefix `A` will not be
  returned since it is not one of the arguments.

  ### Examples

      iex> local_root([A, A.B])
      A

      iex> local_root([A.B, A.C, A])
      A

      iex> local_root([A.B, A.C])
      nil

      iex> local_root([])
      nil
  """
  @spec local_root([module]) :: module | nil
  def local_root([_ | _] = mods) do
    case local_roots(mods) do
      [single] -> single
      _ -> nil
    end
  end

  def local_root([]) do
    nil
  end

  @doc """
  Returns the top module namespaces that are prefix to all other modules and
  that is also a module from the list.

  See `local_root/1`

  ### Examples

      iex> local_roots([A, A.B, X.Y, X])
      [A, X]

      iex> local_roots([A.B, A.C, A, X, X, X.Y, X.Y.Z])
      [A,X]

      iex> local_roots([A.B, A.C])
      [A.B, A.C]

      iex> local_roots([A.B.C1, A.B.C2])
      [A.B.C1, A.B.C2]

      iex> local_roots([A.B.C1, A.B.C2, A.B])
      [A.B]
  """
  def local_roots([_ | _] = mods) do
    with_splits =
      mods
      |> Enum.reject(&protocol_impl?/1)
      |> Enum.map(&{&1, Module.split(&1)})

    roots = reduce_roots(with_splits)

    Enum.map(roots, fn {mod, _split} -> mod end)
  end

  defp reduce_roots(with_splits, acc \\ [])

  defp reduce_roots([h | t], acc) do
    # insert a candidate root to the acc.
    # * If it is a root from mods in acc, they are deleted from acc
    # * If it is a children of a mod in acc, it is not added
    # so acc always contains pure roots
    reduce_roots(t, insert_root(h, acc))
  end

  defp reduce_roots([], acc) do
    acc
  end

  defp insert_root(root, []) do
    [root]
  end

  defp insert_root({_, candidate_split} = cand, [{_, h_split} = h | t]) do
    cond do
      # candidate is a new root, remove h and continue
      child_split?(candidate_split, h_split) -> insert_root(cand, t)
      # h is root of candidate, stop inserting candidate
      child_split?(h_split, candidate_split) -> [h | t]
      # no match between those two modules, keep h and continue
      true -> [h | insert_root(cand, t)]
    end
  end

  defp child_split?(parent, child) do
    List.starts_with?(child, parent)
  end

  defp protocol_impl?(mod) do
    # If we cannot load we bail. Maybe someone is trying to compare atoms and
    # not actual modules.

    if mod == Jason.Encoder.GenMCP.MCP.Root do
      case Code.ensure_loaded(mod) do
        {:module, ^mod} -> function_exported?(mod, :__impl__, 1)
        _ -> false
      end
    else
      case Code.ensure_loaded(mod) do
        {:module, ^mod} -> function_exported?(mod, :__impl__, 1)
        _ -> false
      end
    end
  end

  def as_test(module) when is_atom(module) do
    Module.concat([inspect(module) <> "Test"])
  end
end
