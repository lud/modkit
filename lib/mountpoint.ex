defmodule Modkit.Mount.Point do
  alias __MODULE__

  @flavors [:elixir, :phoenix]

  @enforce_keys [
    # This is the atom prefix name given in configuration
    :prefix,

    # This is the splitted version of the prefix, containing binaries
    :splitfix,

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
          splitfix: [binary],
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
    new(prefix, flavor, path)
  end

  @spec new(prefix :: module, flavor, path :: binary) :: t

  def new(prefix, flavor, path)
      when is_atom(prefix) and flavor in @flavors and is_binary(path) do
    %__MODULE__{prefix: prefix, flavor: flavor, splitfix: Module.split(prefix), path: path}
  end

  @spec prefix_of?(t, [binary]) :: boolean()
  def prefix_of?(%Point{splitfix: splitfix}, modsplit) when is_list(modsplit) do
    List.starts_with?(modsplit, splitfix)
  end
end

defmodule Modkit.Dup do
end
