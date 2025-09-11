# Data Model for Slickage Dashboard MVP

This document describes the data model for the Slickage Dashboard MVP.

## Entities

### users
- `id`: BIGINT (Primary Key)
- `email`: VARCHAR(255) (Unique)
- `name`: VARCHAR(255)
- `role_id`: BIGINT (Foreign Key to roles.id)
- `inserted_at`: TIMESTAMP
- `updated_at`: TIMESTAMP

### roles
- `id`: BIGINT (Primary Key)
- `name`: VARCHAR(255) (Unique, e.g., "admin", "employee", "client")
- `inserted_at`: TIMESTAMP
- `updated_at`: TIMESTAMP

### clients
- `id`: BIGINT (Primary Key)
- `name`: VARCHAR(255)
- `inserted_at`: TIMESTAMP
- `updated_at`: TIMESTAMP

### projects
- `id`: BIGINT (Primary Key)
- `name`: VARCHAR(255)
- `client_id`: BIGINT (Foreign Key to clients.id)
- `inserted_at`: TIMESTAMP
- `updated_at`: TIMESTAMP

### external_identities
- `id`: BIGINT (Primary Key)
- `user_id`: BIGINT (Foreign Key to users.id)
- `provider`: VARCHAR(255) (e.g., "google", "linear", "slack")
- `provider_id`: VARCHAR(255)
- `token`: TEXT
- `refresh_token`: TEXT
- `expires_at`: TIMESTAMP
- `inserted_at`: TIMESTAMP
- `updated_at`: TIMESTAMP

### sows (Statement of Work)
- `id`: BIGINT (Primary Key)
- `project_id`: BIGINT (Foreign Key to projects.id)
- `name`: VARCHAR(255)
- `drive_id`: VARCHAR(255)
- `inserted_at`: TIMESTAMP
- `updated_at`: TIMESTAMP

### change_requests
- `id`: BIGINT (Primary Key)
- `project_id`: BIGINT (Foreign Key to projects.id)
- `name`: VARCHAR(255)
- `drive_id`: VARCHAR(255)
- `inserted_at`: TIMESTAMP
- `updated_at`: TIMESTAMP

### deployments
- `id`: BIGINT (Primary Key)
- `project_id`: BIGINT (Foreign Key to projects.id)
- `status`: VARCHAR(255)
- `commit_sha`: VARCHAR(255)
- `inserted_at`: TIMESTAMP
- `updated_at`: TIMESTAMP

### health_checks
- `id`: BIGINT (Primary Key)
- `project_id`: BIGINT (Foreign Key to projects.id)
- `status`: VARCHAR(255)
- `inserted_at`: TIMESTAMP
- `updated_at`: TIMESTAMP

### alerts
- `id`: BIGINT (Primary Key)
- `project_id`: BIGINT (Foreign Key to projects.id)
- `message`: TEXT
- `status`: VARCHAR(255)
- `inserted_at`: TIMESTAMP
- `updated_at`: TIMESTAMP

### notification_rules
- `id`: BIGINT (Primary Key)
- `project_id`: BIGINT (Foreign Key to projects.id)
- `event_type`: VARCHAR(255)
- `channel`: VARCHAR(255)
- `inserted_at`: TIMESTAMP
- `updated_at`: TIMESTAMP

### metric_snapshots
- `id`: BIGINT (Primary Key)
- `project_id`: BIGINT (Foreign Key to projects.id)
- `type`: VARCHAR(255)
- `value`: FLOAT
- `inserted_at`: TIMESTAMP

### audits
- `id`: BIGINT (Primary Key)
- `user_id`: BIGINT (Foreign Key to users.id)
- `action`: VARCHAR(255)
- `details`: JSONB
- `inserted_at`: TIMESTAMP
