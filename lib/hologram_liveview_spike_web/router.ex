defmodule HologramLiveviewSpikeWeb.Router do
  use HologramLiveviewSpikeWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {HologramLiveviewSpikeWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    # Lets the CodeMySpec preview pane embed this app, and nothing else. A no-op
    # until a preview is configured, so having it here is not itself a loosening.
    #
    # After :put_secure_browser_headers deliberately. That sets
    # `frame-ancestors 'self'`, which refuses the pane — and refuses it
    # silently: the iframe looks healthy and renders nothing, which reads as
    # this application being broken rather than as a header saying no.
    plug ClientUtils.PreviewFraming, otp_app: :hologram_liveview_spike
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  # Health check for the deploy proxy. Deliberately outside every pipeline:
  # the proxy probes the app port directly over plain HTTP, with no session,
  # no X-Forwarded-Proto header and no expectation of a database. A health
  # route inside :browser would carry session and CSRF plugs and could fail
  # the probe for reasons unrelated to whether the app is up.
  #
  # `config/runtime.exs` excludes this path from force_ssl for the same
  # reason: otherwise the probe is redirected and the traffic swap never
  # completes.
  scope "/", HologramLiveviewSpikeWeb do
    get "/health", HealthController, :show
  end

  # Ask an integration to prove itself, on demand.
  #
  # Separate from `/health` deliberately, and for that route's own stated
  # reason: the proxy gates the traffic swap on it, so it stays shallow. These
  # actions reach a dependency for real — the widget's socket, its credential,
  # its origin — which is exactly what must not decide whether traffic moves.
  #
  # Under `/_cms` so it cannot collide with the application's own routes, and
  # behind the project's deploy key, which this app already holds. Each action
  # can only make its integration *speak*; none of them can take the app down.
  scope "/_cms", HologramLiveviewSpikeWeb do
    pipe_through :api

    post "/verify/widget", VerifyController, :widget

    # Down by construction, so a monitor can be proven to notice something
    # without anything real being broken. Unauthenticated: a monitor will not
    # carry a credential, and a constant reveals nothing.
    get "/verify/always-failing", VerifyController, :always_failing

    # Mints the token the preview pane's own frame redeems to sign in,
    # bypassing Google/GitHub's own refusal to render their sign-in pages
    # inside any iframe — see PreviewLoginController's moduledoc.
    post "/preview_login", PreviewLoginController, :create
  end

  # Inbound mail webhook (Resend Receiving API). Present from generation,
  # not installed alongside inbound mail setup: a domain whose MX already
  # points here before that setup has run should get a real answer rather
  # than a 404, and `ResendWebhookController` degrades gracefully when
  # `RESEND_WEBHOOK_SECRET` isn't configured yet.
  #
  # Unauthenticated like `/health` — Resend cannot carry this app's deploy
  # key — and outside `/_cms` because Resend, not setup, decides the path.
  # The Svix signature is what proves a request is genuinely from Resend.
  scope "/webhooks", HologramLiveviewSpikeWeb do
    pipe_through :api

    post "/resend", ResendWebhookController, :inbound
  end

  scope "/", HologramLiveviewSpikeWeb do
    pipe_through :browser

    get "/", PageController, :home

    live "/items_filter", FilterLive
    live "/components", ComponentLive
    live "/components_server", ComponentServerLive
    live "/items", ItemLive.Index, :index
    live "/items/new", ItemLive.Form, :new
    live "/items/:id", ItemLive.Show, :show
    live "/items/:id/edit", ItemLive.Form, :edit
  end

  # Other scopes may use custom stacks.
  # scope "/api", HologramLiveviewSpikeWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:hologram_liveview_spike, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: HologramLiveviewSpikeWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
