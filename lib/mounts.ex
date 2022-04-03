defmodule Modkit.Mount do
  alias __MODULE__
  alias Modkit.Mount.Point
  @enforce_keys [:points]
  defstruct @enforce_keys

  def new() do
    %__MODULE__{points: []}
  end

  @type t :: %__MODULE__{points: [Point.t()]}

  @spec add(t, Point.t() | Point.point_spec()) :: t
  def add(%Mount{points: points} = mount, %Point{} = point) do
    %Mount{mount | points: insert(points, point)}
  end

  def add(mount, point_spec) do
    add(mount, Point.new(point_spec))
  end

  defp insert([p | _] = ps, p),
    # ignore exact duplicates
    do: ps

  defp insert([%Point{prefix: pref, path: pset} | _] = ps, %Point{prefix: pref, path: pwant}) do
    raise ArgumentError,
          "cannot mount #{inspect(pref)} at #{inspect(pwant)} as it is already mounted at #{inspect(pset)}"
  end

  defp insert([], p), do: [p]

  defp insert(
         [%Point{splitfix: more_precise} = candidate | ps],
         %Point{splitfix: less_precise} = p
       )
       when less_precise < more_precise,
       do: [candidate | insert(ps, p)]

  defp insert(ps, p), do: [p | ps]
end
