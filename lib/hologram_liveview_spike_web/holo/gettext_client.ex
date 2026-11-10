defmodule HologramLiveviewSpikeWeb.Holo.GettextClient do
  @moduledoc "Browser-side stand-in for the `Gettext` module (see `client_module_overrides` in config.exs)."

  # shortcut: English only. Every msgid comes back as written (plural picked by n == 1) with %{key} bindings filled in;
  # no .po files, locales or domains ship to the client. Upgrade by translating on the server or shipping compiled catalogs.
  def dgettext(_backend, _domain, msgid, bindings), do: interpolate(msgid, bindings)
  def dpgettext(_backend, _domain, _context, msgid, bindings), do: interpolate(msgid, bindings)

  def dngettext(_backend, _domain, msgid, plural, n, bindings),
    do: interpolate(if(n == 1, do: msgid, else: plural), bindings)

  def dpngettext(_backend, _domain, _context, msgid, plural, n, bindings),
    do: interpolate(if(n == 1, do: msgid, else: plural), bindings)

  defp interpolate(msgid, bindings) do
    Enum.reduce(bindings, msgid, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", to_string(value))
    end)
  end
end
