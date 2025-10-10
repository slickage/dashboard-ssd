# Quickstart: Prepare Repo for CD with ArgoCD

**Date**: Fri Oct 10 2025
**Feature**: Prepare Repo for CD with ArgoCD

## Prerequisites

- ArgoCD installed and configured
- Access to existing GitOps repository
- Kubernetes cluster access
- Docker registry access

## Setup Steps

### 1. Configure Environment Variables

Update your deployment environment with required ENV variables:

```bash
# Database
DATABASE_URL=postgresql://user:pass@host:5432/db

# Phoenix
SECRET_KEY_BASE=your-secret-key
PHX_HOST=your-domain.com

# ArgoCD
ARGOCD_SERVER=your-argocd-server
```

### 2. Build and Push Docker Image

```bash
# Build the image
docker build -t your-registry/dashboard-ssd:latest .

# Push to registry
docker push your-registry/dashboard-ssd:latest
```

### 3. Deploy via ArgoCD

1. Commit the ArgoCD Application manifest to your GitOps repository
2. ArgoCD will automatically detect and sync the application
3. Monitor deployment status in ArgoCD UI

### 4. Verify Deployment

```bash
# Check pod status
kubectl get pods -n dashboard-ssd

# Check application health
curl https://your-domain.com/health
```

## Troubleshooting

- **Sync fails**: Check ArgoCD logs and manifest validity
- **App not starting**: Verify ENV variables and database connectivity
- **Image pull errors**: Ensure registry credentials are configured

## Rollback

Use ArgoCD UI or CLI to rollback to previous version:
```bash
argocd app rollback dashboard-ssd
```