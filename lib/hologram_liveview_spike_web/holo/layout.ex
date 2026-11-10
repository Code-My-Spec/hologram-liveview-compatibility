defmodule HologramLiveviewSpikeWeb.Holo.Layout do
  use Hologram.Component
  alias Hologram.UI.Runtime

  # shortcut: local_lv.js loads on every page (it idles without a data-phx-main root); upgrade by loading it only where a LiveView lives.
  def template do
    ~HOLO"""
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <link rel="stylesheet" href={asset_path("assets/css/app.css")} />
        <Runtime />
        <script defer src={asset_path("assets/js/local_lv.js")}></script>
      </head>
      <body class="min-h-screen bg-slate-50 text-slate-900 antialiased">
        <main class="mx-auto max-w-lg px-4 py-12"><slot /></main>
      </body>
    </html>
    """
  end
end
