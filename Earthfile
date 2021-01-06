# release:
#   ARG billing_version=0.1.0
#   RUN wget -qO - "https://github.com/elielhaouzi/billing/archive/$billing_version.tar.gz" > /tmp/billing.tar.gz

# all:
#   BUILD +all-test
#   BUILD +npm

# all-test:
#   BUILD --build-arg ELIXIR=1.11.3 --build-arg OTP=23.1.1 +test

# test:
#   FROM +test-setup
#   COPY --dir assets config lib priv test ./
#   RUN mix test

# docker:
#   COPY +build/releases/billing .
#   ENTRYPOINT ["/_releases/billing start"]
#   SAVE IMAGE billing:latest

# npm:
#   ARG ELIXIR=1.11.2
#   ARG OTP=23.1.1
#   FROM node:12
#   COPY +npm-setup/assets /assets
#   WORKDIR assets
#   RUN npm install && npm test

# npm-setup:
#   FROM +test-setup
#   COPY assets assets
#   RUN mix deps.get
#   SAVE ARTIFACT assets

# setup-base:
#   ARG ELIXIR=1.11.2
#   ARG OTP=23.1.1
#   FROM hexpm/elixir:$ELIXIR-erlang-$OTP-alpine-3.12.0
#   RUN apk add --no-progress --update git build-base
#   ENV ELIXIR_ASSERT_TIMEOUT=10000
#   WORKDIR /src

# test-setup:
#   FROM +setup-base
#   COPY mix.exs .
#   COPY mix.lock .
#   COPY .formatter.exs .
#   RUN mix local.rebar --force
#   RUN mix local.hex --force
#   RUN mix deps.get

# build:
#   FROM +npm-setup
#   COPY --dir assets config lib priv test ./
#   RUN MIX_ENV=prod mix compile
#   RUN npm install --prefix ./assets
#   RUN npm run deploy --prefix ./assets
#   RUN mix phx.digest
#   RUN MIX_ENV=prod mix release
#   SAVE ARTIFACT _build/prod/rel/billing AS LOCAL ./releases/billing