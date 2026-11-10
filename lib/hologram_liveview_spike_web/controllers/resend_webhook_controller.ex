defmodule HologramLiveviewSpikeWeb.ResendWebhookController do
  @moduledoc """
  Inbound mail webhook for the Resend Receiving API.

  Resend POSTs an `email.received` event here once inbound mail setup has
  pointed the domain's MX at this application. This is a scaffold, not a
  mail feature: it verifies the request genuinely came from Resend and logs
  what arrived. Storing messages, routing by address, or replying is the
  application's own concern to build on top of it.

  Signatures are verified against `RESEND_WEBHOOK_SECRET` (Svix `whsec_...`).
  When no secret is configured — before inbound mail setup has minted one,
  or in dev/test — verification is skipped so the route stays reachable
  rather than crashing the request, the same graceful degradation
  `VerifyController` uses for a missing deploy key. Once a secret is set, a
  bad or missing signature is rejected with 400. We always answer 200 on an
  accepted event so the provider doesn't retry a message there is nowhere
  to put.
  """

  use HologramLiveviewSpikeWeb, :controller

  require Logger

  def inbound(conn, %{"type" => "email.received", "data" => data} = _params) when is_map(data) do
    case verify_signature(conn) do
      :ok ->
        log_received(data)
        send_resp(conn, 200, "ok")

      {:error, :invalid_signature} ->
        Logger.warning("[ResendWebhook] rejected event with invalid signature")
        send_resp(conn, 400, "bad signature")
    end
  end

  def inbound(conn, _params) do
    case verify_signature(conn) do
      :ok -> send_resp(conn, 200, "ok")
      {:error, :invalid_signature} -> send_resp(conn, 400, "bad signature")
    end
  end

  defp log_received(data) do
    preview =
      (data["text"] || data["html"] || "")
      |> to_string()
      |> String.slice(0, 200)

    Logger.info(
      "[ResendWebhook] received from=#{inspect(data["from"])} to=#{inspect(data["to"])} " <>
        "subject=#{inspect(data["subject"])} preview=#{inspect(preview)}"
    )
  end

  # --- Signature verification (Svix) ---

  defp verify_signature(conn) do
    case webhook_secret() do
      secret when is_binary(secret) and secret != "" -> do_verify(conn, secret)
      _ -> :ok
    end
  end

  defp do_verify(conn, secret) do
    with [svix_id] <- get_req_header(conn, "svix-id"),
         [svix_timestamp] <- get_req_header(conn, "svix-timestamp"),
         [svix_signature] <- get_req_header(conn, "svix-signature"),
         {:ok, key} <- decode_secret(secret) do
      signed = "#{svix_id}.#{svix_timestamp}.#{raw_body(conn)}"
      expected = :crypto.mac(:hmac, :sha256, key, signed) |> Base.encode64()

      provided =
        svix_signature
        |> String.split(" ", trim: true)
        |> Enum.map(fn
          "v1," <> sig -> sig
          sig -> sig
        end)

      if Enum.any?(provided, &Plug.Crypto.secure_compare(&1, expected)),
        do: :ok,
        else: {:error, :invalid_signature}
    else
      _ -> {:error, :invalid_signature}
    end
  end

  defp decode_secret(secret) do
    case secret |> String.replace_prefix("whsec_", "") |> Base.decode64() do
      {:ok, key} -> {:ok, key}
      :error -> :error
    end
  end

  defp raw_body(conn) do
    case conn.assigns[:raw_body] do
      nil -> ""
      chunks -> chunks |> Enum.reverse() |> IO.iodata_to_binary()
    end
  end

  defp webhook_secret, do: Application.get_env(:hologram_liveview_spike, :resend_webhook_secret)
end
