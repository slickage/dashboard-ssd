# DashboardSSD

A modern, dark-themed dashboard for managing software development projects, clients, deployments, and integrations with tools like Linear, Slack, Notion, and Google Drive.

[![CI](https://github.com/slickage/dashboard-ssd/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/slickage/dashboard-ssd/actions/workflows/ci.yml)
[![Coverage Status](https://coveralls.io/repos/github/slickage/dashboard-ssd/badge.svg?branch=main)](https://coveralls.io/github/slickage/dashboard-ssd?branch=main)
[![Credo](https://img.shields.io/badge/style-credo-4B32C3.svg)](https://github.com/rrrene/credo)
[![Dialyzer](https://img.shields.io/badge/typecheck-dialyzer-306998.svg)](https://hexdocs.pm/dialyxir/readme.html)
[![Sobelow](https://img.shields.io/badge/security-sobelow-EB4C2F.svg)](https://github.com/nccgroup/sobelow)
[![License: MIT](https://img.shields.io/badge/license-MIT-yellow.svg)](LICENSE)

## Features

- **User Authentication**: Google OAuth integration with role-based access control (Admin, Employee, Client)
- **Project Management**: Track projects, clients, deployments, and health checks
- **Integrations**: Connect with Linear (issues), Slack (notifications), Notion (knowledge base), Google Drive (documents) and emit telemetry for each integration so alerts can be configured
- **Real-time Dashboard**: Live updates for project status, workload, and metrics
- **Dark Theme**: Modern, responsive UI with dark mode
- **Contracts & Docs**: Repository-managed workspace templates, client portal downloads, Drive ACL automation, and telemetry (see `docs/contracts-and-docs.md`)

## Prerequisites

- Elixir 1.18+
- Phoenix 1.8+
- PostgreSQL
- Node.js 20+

## Quick Start

1. **Clone and setup**:
   ```bash
   git clone https://github.com/slickage/dashboard-ssd.git
   cd dashboard-ssd
   mix setup
   ```

2. **Configure environment**:
   ```bash
   cp .env.example .env
   # Edit .env with your API keys and secrets
   ```

3. **Run the application**:
   ```bash
   mix phx.server
   ```

4. **Visit** [`localhost:4000`](http://localhost:4000)

### Contracts & Docs

- Workspace templates are defined in `priv/workspace_templates/**` and wired through the
  blueprint config in `config/*.exs`. See `docs/contracts-and-docs.md` for the full playbook.
- Drive/Notion artifacts are bootstrapped automatically during project/client creation and
  can be regenerated from Projects → Contracts with per-section toggles.
- Drive ACL automation runs whenever client assignments change and emits telemetry events
  (`[:dashboard_ssd, :drive_acl, :sync]`, `[:dashboard_ssd, :documents, :download]`,
  `[:dashboard_ssd, :documents, :visibility_toggle]`) so alerting rules can enforce
  SC-001–SC-003.

## Development

- **Run tests**: `mix test`
- **Check code quality**: `mix check` (format + lint + dialyzer + test + docs)
- **Live reload**: Assets are compiled automatically with esbuild

### Local Tooling

Install required CLI tools:

```bash
brew install gitleaks
```

The secret scan script falls back to Docker if the binary is unavailable.

### Environment Configuration

Required environment variables in `.env`:

- `GOOGLE_CLIENT_ID` / `GOOGLE_CLIENT_SECRET`: Google OAuth
- `LINEAR_TOKEN`: Linear API access
- `SLACK_API_KEY`: Slack API access
- `SLACK_CHANNEL`: Slack channel for notifications
- `NOTION_TOKEN`: Notion API access
- `ENCRYPTION_KEY`: Base64-encoded encryption key for sensitive data
- `SLICKAGE_ALLOWED_DOMAINS`: Comma-separated list of Google Workspace domains that should be treated as internal Slickage users (e.g., `slickage.com,subsidiary.com`)

Drive service account (for Contracts → Regenerate / workspace bootstrap):

- `DRIVE_ROOT_FOLDER_ID`: Drive folder ID shared with the service account (Editor). The app creates `Clients/<Client>/<Project>` under this root.
- `DRIVE_SERVICE_ACCOUNT_JSON`: Absolute path to the service account JSON key (e.g., `/Users/kkid/secrets/slickage-dashboard-472000-e85feaabee6c.json`). The app mints a Drive access token at runtime from this file; you do NOT need `GOOGLE_DRIVE_TOKEN`.

Example (local):
```bash
export DRIVE_ROOT_FOLDER_ID="<your-root-folder-id>"
export DRIVE_SERVICE_ACCOUNT_JSON="/absolute/path/to/drive-service-account.json"
mix phx.server
```

### Testing

- Run all tests: `mix test`
- Run with coverage: `mix coveralls`
- Run specific test: `mix test path/to/test.exs`

### Deployment

#### Docker Deployment

1. **Build the image**:
   ```bash
   docker build -t dashboard-ssd .
   ```

2. **Run the container**:
   ```bash
   docker run -p 4000:4000 -e DATABASE_URL=... -e SECRET_KEY_BASE=... dashboard-ssd
   ```

3. **Environment variables** (see config/runtime.exs for full list):
   - `DATABASE_URL`: PostgreSQL connection string
   - `SECRET_KEY_BASE`: Phoenix secret key
   - `PHX_HOST`: Domain name
   - `GOOGLE_CLIENT_ID` / `GOOGLE_CLIENT_SECRET`: OAuth
   - Integration tokens: `LINEAR_TOKEN`, `SLACK_API_KEY`, `NOTION_TOKEN`
   - `SLACK_CHANNEL`: Slack channel for notifications
   - `ENCRYPTION_KEY`: Encryption key for sensitive data

#### CI/CD

The repository includes GitHub Actions for automated testing and Docker image publishing to GHCR on main branch pushes.

For full deployment guides, see Phoenix documentation: https://hexdocs.pm/phoenix/deployment.html

## Architecture

- **Backend**: Elixir/Phoenix with PostgreSQL
- **Frontend**: LiveView with Tailwind CSS
- **Authentication**: Google OAuth 2.0
- **Integrations**: REST APIs for external services
- **Real-time**: Phoenix Channels for live updates

## Contributing

1. Follow the code style: `mix format`, `mix credo --strict`
2. Write tests for new features
3. Ensure `mix check` passes
4. Update documentation as needed

## License

MIT License - see [LICENSE](LICENSE) file.

## Learn more

- [Phoenix Framework](https://www.phoenixframework.org/)
- [Elixir Documentation](https://hexdocs.pm/elixir/)
- [LiveView Guides](https://hexdocs.pm/phoenix_live_view/)
- [Contracts & Docs Playbook](docs/contracts-and-docs.md)

## Integrations

### Linear
- Configure `LINEAR_TOKEN` in environment.
- To re-run Linear sync on demand, use the Projects page -> Sync button.

### Notion
- Configure `NOTION_API_TOKEN` and `NOTION_DATABASE_ID` in environment for the knowledge base.
- To re-run Notion sync on demand, use the KB page -> Sync button.

### Google Drive
- Enable **Google Drive API** and **Google Docs API** in your GCP project.
- Create a service account (IAM & Admin → Service Accounts) and generate a JSON key; point `DRIVE_SERVICE_ACCOUNT_JSON` to this file.
- Add the service account as a member of the target **Shared Drive** with at least Content Manager access.
- Set `DRIVE_ROOT_FOLDER_ID` to the Shared Drive ID (from the Drive URL: `https://drive.google.com/drive/folders/<ID>`).
- Start the app with these env vars exported; Regenerate/Sync in Contracts will create/update Drive docs under that Shared Drive.
