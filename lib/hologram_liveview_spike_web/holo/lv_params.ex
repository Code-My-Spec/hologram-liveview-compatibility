defmodule HologramLiveviewSpikeWeb.Holo.LvParams do
  # Rebuilds nested params from the [key, value] pairs of a urlencoded form: "a[b]" => %{"a" => %{"b" => v}}, "t[]" => list.
  # shortcut: one level of nesting plus [] lists; no deeper nesting. Upgrade by porting Plug.Conn.Query.decode.
  def decode(pairs), do: Enum.reduce(pairs, %{}, fn [k, v], acc -> put(acc, path(k), v) end)

  defp path(k) do
    case String.split(k, "[") do
      [head] -> [head]
      [head | rest] -> [head | Enum.map(rest, &String.trim_trailing(&1, "]"))]
    end
  end

  defp put(map, [key], v), do: Map.put(map, key, v)
  defp put(map, [key, ""], v), do: Map.update(map, key, [v], &(&1 ++ [v]))
  defp put(map, [key | rest], v), do: Map.put(map, key, put(Map.get(map, key, %{}), rest, v))
end
