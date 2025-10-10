# Data Model: Prepare Repo for CD with ArgoCD

**Date**: Fri Oct 10 2025
**Feature**: Prepare Repo for CD with ArgoCD

## Overview

This feature adds configuration entities for ArgoCD deployment without introducing new database tables. All entities are represented as Kubernetes manifests and configuration files.

## Entities

### ArgoCD Application

**Purpose**: Defines how the application should be deployed to a Kubernetes cluster.

**Attributes**:
- `metadata.name`: Unique application identifier (e.g., "dashboard-ssd-prod")
- `metadata.namespace`: ArgoCD namespace
- `spec.project`: ArgoCD project name
- `spec.source.repoURL`: Source repository URL
- `spec.source.path`: Path to manifests in repo
- `spec.source.targetRevision`: Git branch/tag to deploy
- `spec.destination.server`: Target Kubernetes cluster
- `spec.destination.namespace`: Target namespace
- `spec.syncPolicy.automated`: Enable automated syncing

**Relationships**: References GitOps Repository for centralized management.

**Validation Rules**:
- repoURL must be valid HTTPS URL
- targetRevision must exist in repository
- destination server must be accessible

### Deployment Manifests

**Purpose**: Kubernetes manifests defining the application's infrastructure and services.

**Attributes**:
- `apiVersion`: Kubernetes API version
- `kind`: Resource type (Deployment, Service, ConfigMap, etc.)
- `metadata.name`: Resource name
- `metadata.labels`: Identification labels
- `spec`: Resource specification (varies by kind)

**Relationships**: Referenced by ArgoCD Application.

**Validation Rules**:
- Must be valid Kubernetes YAML
- Must include required labels for ArgoCD tracking
- Must use ENV vars for configurable values

### GitOps Repository

**Purpose**: Centralized repository managing deployment configurations across applications.

**Attributes**:
- Repository URL
- Branch structure (main, environments)
- Directory layout (apps/, base/, overlays/)
- Access credentials (scoped tokens)

**Relationships**: Contains ArgoCD Applications and shared manifests.

**Validation Rules**:
- Must support Git operations
- Must have proper RBAC for CI/CD systems
- Must encrypt secrets at rest

## State Transitions

### Deployment States
1. **Pending**: Application created in ArgoCD, waiting for sync
2. **Syncing**: ArgoCD applying manifests to cluster
3. **Synced**: All resources deployed successfully
4. **Degraded**: One or more resources failed to deploy
5. **Suspended**: Manual pause of automated syncing

### Rollback Process
1. **Initiate**: Manual or automatic trigger
2. **Validate**: Check previous revision health
3. **Apply**: Revert to previous manifests
4. **Monitor**: Ensure application stability