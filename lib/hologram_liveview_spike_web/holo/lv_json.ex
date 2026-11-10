defmodule HologramLiveviewSpikeWeb.Holo.LvJson do
  # shortcut: encodes only what a LiveView diff contains (maps, lists, binaries, ints, atoms);
  # escapes \ " \n \r \t only. Upgrade to the real :json port if Hologram grows one.
  def enc(m) when is_map(m) do
    "{" <> (m |> Enum.map_join(",", fn {k, v} -> enc(to_string(k)) <> ":" <> enc(v) end)) <> "}"
  end

  def enc(l) when is_list(l), do: "[" <> Enum.map_join(l, ",", &enc/1) <> "]"
  def enc(nil), do: "null"
  def enc(true), do: "true"
  def enc(false), do: "false"
  def enc(a) when is_atom(a), do: enc(Atom.to_string(a))
  def enc(i) when is_integer(i), do: Integer.to_string(i)

  def enc(b) when is_binary(b) do
    escaped =
      b
      |> String.replace("\\", "\\\\")
      |> String.replace("\"", "\\\"")
      |> String.replace("\n", "\\n")
      |> String.replace("\r", "\\r")
      |> String.replace("\t", "\\t")

    "\"" <> escaped <> "\""
  end
end
