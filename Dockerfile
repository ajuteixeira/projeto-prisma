FROM elixir:1.18.3-alpine

RUN apk add --no-cache build-base git inotify-tools

WORKDIR /app

COPY mix.exs mix.lock ./
RUN mix local.hex --force && \
    mix local.rebar --force && \
    mix deps.get

COPY . .

CMD ["mix", "phx.server"]
