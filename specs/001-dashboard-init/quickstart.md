# Quickstart for Slickage Dashboard MVP

This guide provides instructions on how to set up and run the Slickage Dashboard MVP.

## Prerequisites

- Elixir 1.15+
- Phoenix 1.7+
- PostgreSQL

## Setup

1.  **Clone the repository**:
    ```bash
    git clone <repository-url>
    cd dashboard-ssd
    ```

2.  **Install dependencies**:
    ```bash
    mix deps.get
    ```

3.  **Create and migrate the database**:
    ```bash
    mix ecto.create
    mix ecto.migrate
    ```

4.  **Configure environment variables**:
    -   Create a `.env` file based on `.env.example`.
    -   Fill in the required credentials for Google OAuth, Linear, Slack, etc.

## Running the application

1.  **Start the Phoenix server**:
    ```bash
    mix phx.server
    ```

2.  **Access the application**:
    -   Open your browser and navigate to `http://localhost:4000`.

## Running tests

-   Run all tests:
    ```bash
    mix test
    ```
