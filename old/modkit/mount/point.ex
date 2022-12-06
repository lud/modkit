defmodule Modkit.Mount.Point do
  alias __MODULE__

  @flavors [:elixir, :phoenix, :mix_task]

  @enforce_keys [
    # This is the atom prefix name given in configuration
    :prefix,

    # This is the splitted version of the prefix, containing binaries
    :pre_split,

    # This is the mount path for the prefix.
    :path,

    # This is the used flavor
    :flavor
  ]
  defstruct @enforce_keys

  @type flavor :: unquote(Enum.reduce(@flavors, &quote(do: unquote(&1) | unquote(&2))))

  @type path_spec :: binary | {flavor, binary}
  @type point_spec :: {module, path_spec}
  @type t :: %__MODULE__{
          prefix: module,
          pre_split: [binary],
          path: binary,
          flavor: flavor
        }

  @spec new(point_spec) :: t
  def new(point_spec)

  def new({prefix, path}) when is_atom(prefix) and is_binary(path) do
    new({prefix, {:elixir, path}})
  end

  def new({prefix, {flavor, path}})
      when is_atom(prefix) and flavor in @flavors and is_binary(path) do
    _new(prefix, flavor, path)
  end

  def new(other) do
    raise ArgumentError, """
    invalid mount point: #{inspect(other)}

    Valid mount points are:
     * {My.Namespace, "path/to/code"}
     * {My.Namespace, {:phoenix, "path/to/code"}}
    """
  end

  defp _new(prefix, flavor, path)
       when is_atom(prefix) and flavor in @flavors and is_binary(path) do
    %__MODULE__{prefix: prefix, flavor: flavor, pre_split: Module.split(prefix), path: path}
  end

  @spec prefix_of?(t, [binary]) :: boolean()
  def prefix_of?(%Point{pre_split: pre_split}, modsplit) when is_list(modsplit) do
    List.starts_with?(modsplit, pre_split)
  end
end
