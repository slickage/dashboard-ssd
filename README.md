# DashboardSSD

[![CI](https://github.com/akinsey/dashboard-ssd/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/akinsey/dashboard-ssd/actions/workflows/ci.yml)
[![Coverage Status](https://coveralls.io/repos/github/akinsey/dashboard-ssd/badge.svg?branch=main)](https://coveralls.io/github/akinsey/dashboard-ssd?branch=main)
[![Credo](https://img.shields.io/badge/style-credo-4B32C3.svg)](https://github.com/rrrene/credo)
[![Dialyzer](https://img.shields.io/badge/typecheck-dialyzer-306998.svg)](https://hexdocs.pm/dialyxir/readme.html)
[![Sobelow](https://img.shields.io/badge/security-sobelow-EB4C2F.svg)](https://github.com/nccgroup/sobelow)
[![License: MIT](https://img.shields.io/badge/license-MIT-yellow.svg)](LICENSE)

To start your Phoenix server:

  * Run `mix setup` to install and setup dependencies
  * Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

### Local Tooling

This project depends on several CLI tools that are not Hex packages. Install
them locally so `mix check` and the Git hooks succeed:

```bash
brew install gitleaks
```

`scripts/secret_scan.sh` automatically falls back to the official Docker image
(`zricethezav/gitleaks`) if the binary is unavailable.

Copy the provided sample environment file and populate it with your own
credentials:

```bash
cp .env.sample .env
# edit .env with local secrets (file is gitignored)
```

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## Learn more

  * Official website: https://www.phoenixframework.org/
  * Guides: https://hexdocs.pm/phoenix/overview.html
  * Docs: https://hexdocs.pm/phoenix
  * Forum: https://elixirforum.com/c/phoenix-forum
  * Source: https://github.com/phoenixframework/phoenix
