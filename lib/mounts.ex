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
    %Mount{mount | points: [point | points]}
  end

  def add(mount, point_spec) do
    add(mount, Point.new(point_spec))
  end
end
