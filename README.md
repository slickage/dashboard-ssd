# DashboardSSD

A modern, dark-themed dashboard for managing software development projects, clients, deployments, and integrations with tools like Linear, Slack, Notion, and Google Drive.

[![CI](https://github.com/akinsey/dashboard-ssd/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/akinsey/dashboard-ssd/actions/workflows/ci.yml)
[![Coverage Status](https://coveralls.io/repos/github/akinsey/dashboard-ssd/badge.svg?branch=main)](https://coveralls.io/github/akinsey/dashboard-ssd?branch=main)
[![Credo](https://img.shields.io/badge/style-credo-4B32C3.svg)](https://github.com/rrrene/credo)
[![Dialyzer](https://img.shields.io/badge/typecheck-dialyzer-306998.svg)](https://hexdocs.pm/dialyxir/readme.html)
[![Sobelow](https://img.shields.io/badge/security-sobelow-EB4C2F.svg)](https://github.com/nccgroup/sobelow)
[![License: MIT](https://img.shields.io/badge/license-MIT-yellow.svg)](LICENSE)

## Features

- **User Authentication**: Google OAuth integration with role-based access control (Admin, Employee, Client)
- **Project Management**: Track projects, clients, deployments, and health checks
- **Integrations**: Connect with Linear (issues), Slack (notifications), Notion (knowledge base), Google Drive (documents)
- **Real-time Dashboard**: Live updates for project status, workload, and metrics
- **Dark Theme**: Modern, responsive UI with dark mode
- **Contracts**: Manage Statements of Work (SOWs) and Change Requests (CRs)

## Prerequisites

- Elixir 1.18+
- Phoenix 1.7+
- PostgreSQL
- Node.js 20+

## Quick Start

1. **Clone and setup**:
   ```bash
   git clone https://github.com/akinsey/dashboard-ssd.git
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
