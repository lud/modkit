defmodule Modkit.Mod do
  def current_path(module, relative_to \\ File.cwd!()) do
    source = Keyword.fetch!(module.module_info(:compile), :source) |> List.to_string()
    Path.relative_to(source, relative_to)
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

  def list_by_file(otp_app, relative_to \\ File.cwd!()) do
    otp_app
    |> list_all()
    |> Enum.group_by(&current_path(&1, relative_to))
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

  def local_root([_ | _] = list) do
    with_splits =
      list
      |> Enum.reject(&protocol_impl?/1)
      |> Enum.map(&{&1, Module.split(&1)})

    found =
      Enum.find(with_splits, nil, fn {_, parent_split} ->
        Enum.all?(with_splits, fn {_, child_split} ->
          List.starts_with?(child_split, parent_split)
        end)
      end)

    case found do
      {mod, _} -> mod
      _ -> nil
    end
  end

  def local_root([]) do
    nil
  end

  defp protocol_impl?(mod) do
    # If we cannot load we bail. Maybe someone is trying to compare atoms and
    # not actual modules.
    case Code.ensure_loaded(mod) do
      {:module, ^mod} -> function_exported?(mod, :__impl__, 1)
      _ -> false
    end
  end
end
