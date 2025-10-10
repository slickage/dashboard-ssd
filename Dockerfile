# Build stage
FROM hexpm/elixir:1.18.0-erlang-27.1-debian-bullseye-slim AS build

# Install build dependencies
RUN apt-get update -y && apt-get install -y build-essential git curl \
    && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

# Prepare build dir
WORKDIR /app

# Install hex + rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Set build ENV
ENV MIX_ENV=prod

# Copy mix files
COPY mix.exs mix.lock ./

# Install dependencies
RUN mix deps.get --only prod

# Copy config files
COPY config config

# Compile dependencies
RUN mix deps.compile

# Copy assets
COPY assets assets

# Install assets dependencies
RUN cd assets && npm install

# Build assets
RUN mix assets.deploy

# Copy source code
COPY lib lib
COPY priv priv

# Compile and build release
RUN mix compile
RUN mix release

# Runtime stage
FROM debian:bullseye-20231009-slim

# Install runtime dependencies
RUN apt-get update -y && apt-get install -y libstdc++6 openssl libncurses5 locales \
    && apt-get clean && rm -f /var/lib/apt/lists/*_* \
    && localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8

ENV LANG en_US.utf8

WORKDIR /app

# Create non-root user
RUN groupadd -r dashboard && useradd -r -g dashboard dashboard

# Copy release from build stage
COPY --from=build /app/_build/prod/rel/dashboard_ssd ./

# Change ownership
RUN chown -R dashboard:dashboard /app

USER dashboard

# Expose ports
EXPOSE 4000 4001

# Health check
HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:4000/health || exit 1

# Start the application
CMD ["bin/dashboard_ssd", "start"]