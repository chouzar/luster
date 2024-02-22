defmodule Luster.Store do
  def start() do
    CubDB.start_link(data_dir: "store/", name: __MODULE__)
    nil
  end

  def all() do
    CubDB.select(__MODULE__)
    |> Enum.map(fn {_key, value} -> value end)
  end

  def put(key, value) do
    CubDB.put(__MODULE__, key, value)
    nil
  end

  def get(key) do
    case CubDB.fetch(__MODULE__, key) do
      {:ok, value} -> {:ok, value}
      :error -> {:error, nil}
    end
  end

  def dump() do
    CubDB.clear(__MODULE__)
    nil
  end
end
