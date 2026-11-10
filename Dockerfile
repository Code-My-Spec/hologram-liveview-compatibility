# Build stage.
#
# ARG-driven versions so the image can be rebuilt reproducibly and so the
# same Dockerfile serves amd64 and arm64 — the deploy box may be either
# (Hetzner's cax line is ARM64, the cx/cpx lines are amd64). An image built
# for the wrong architecture fails at container start, after a deploy that
# otherwise looked healthy.
ARG ELIXIR_VERSION=1.20.3
ARG OTP_VERSION=28.4.3
ARG DEBIAN_VERSION=bookworm-20260803-slim

ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="debian:${DEBIAN_VERSION}"

FROM ${BUILDER_IMAGE} AS builder

RUN apt-get update -y && \
    apt-get install -y build-essential git curl && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# sops, fetched here so the runtime stage needs no download tooling of its own.
# The container decrypts its own environment at boot (rel/overlays/bin/boot),
# which is what makes SOPS_AGE_KEY the only secret the deploy has to carry.
#
# `dpkg --print-architecture` prints amd64/arm64, which is exactly how sops
# names its release assets — so this follows the image's own architecture
# rather than assuming whichever one the deploy box happens to be.
ARG SOPS_VERSION=3.9.4
RUN curl -fsSL -o /usr/local/bin/sops \
      "https://github.com/getsops/sops/releases/download/v${SOPS_VERSION}/sops-v${SOPS_VERSION}.linux.$(dpkg --print-architecture)" && \
    chmod +x /usr/local/bin/sops && \
    sops --version --disable-version-check

RUN mix local.hex --force && mix local.rebar --force

ENV MIX_ENV="prod"

COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV
RUN mkdir config

# Compile dependencies before copying application code so a code-only change
# does not invalidate the dependency layer.
COPY config/config.exs config/${MIX_ENV}.exs config/
RUN mix deps.compile

COPY priv priv
COPY lib lib
COPY assets assets

# Compile BEFORE building assets. Phoenix 1.8 extracts colocated hooks and CSS
# during compilation, into `phoenix-colocated/<app>/`, and `assets/css/app.css`
# imports `phoenix-colocated/<app>/colocated.css` from there. Built the other
# way round, tailwind cannot resolve that import and the build fails with
#
#   Error: Can't resolve 'phoenix-colocated/<app>/colocated.css'
#
# which names a file nobody wrote and no template contains.
RUN mix compile

# `mix assets.deploy` downloads tailwind/esbuild binaries on first run, and
# that download is the flakiest step in the whole build. One retry turns a
# transient network blip into a slower build instead of a failed deploy.
RUN mix assets.deploy || (echo "assets.deploy failed, retrying once" && mix assets.deploy)

# runtime.exs is read at boot, not compile time, so it is copied after
# compilation.
COPY config/runtime.exs config/

COPY rel rel

# The encrypted environment files, which the boot wrapper decrypts on the host.
# Ciphertext only — the private half of the age key never enters the image and
# arrives as SOPS_AGE_KEY at run time, so an image sitting in a registry
# discloses nothing.
#
# Copied before `mix release` so the release's own overlay pass carries them
# into the release root alongside `bin/`, which is what the runtime stage then
# takes wholesale.
COPY envs rel/overlays/envs

RUN mix release

# Runtime stage — no build tooling, no source.
FROM ${RUNNER_IMAGE}

RUN apt-get update -y && \
    apt-get install -y libstdc++6 openssl libncurses5 locales ca-certificates && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen

ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

WORKDIR /app
RUN chown nobody /app

ENV MIX_ENV="prod"

# sops, to decrypt that environment at boot. No download tooling in this
# stage — the builder fetched it.
COPY --from=builder /usr/local/bin/sops /usr/local/bin/sops

# The release, which carries `envs/` with it via the overlay pass above. The
# directory is created unconditionally so a release built without any
# encrypted files still starts far enough to report a missing *secret* rather
# than dying on a missing directory.
COPY --from=builder --chown=nobody:root /app/_build/${MIX_ENV}/rel/hologram_liveview_spike ./
RUN mkdir -p /app/envs && chown -R nobody:root /app/envs

USER nobody

CMD ["/app/bin/server"]
