# Research Findings: Prepare Repo for CD with ArgoCD

**Date**: Fri Oct 10 2025
**Feature**: Prepare Repo for CD with ArgoCD

## Scale/Scope Clarification

**Decision**: Support 3 environments (dev, staging, prod) with deployment frequency of 10-20 per week, handling up to 5 concurrent deployments.

**Rationale**: Based on typical Phoenix project scales and ArgoCD capabilities. Allows for CI/CD pipelines without overwhelming the system.

**Alternatives Considered**:
- Single environment: Too limiting for proper testing cycles
- 5+ environments: Unnecessary complexity for current project size
- Unlimited concurrent deployments: Could cause resource contention

## ArgoCD Best Practices for Phoenix Apps

**Decision**: Use ArgoCD Application CRDs with Helm charts for deployment manifests, leveraging Phoenix's built-in release features.

**Rationale**: Provides declarative deployments, easy rollbacks, and integrates well with Phoenix's OTP-based architecture and hot upgrades.

**Alternatives Considered**:
- Kustomize: Less flexible for environment-specific configs
- Raw YAML: More maintenance overhead
- Manual deployments: Violates CD principles

## ENV Variable Configuration in Phoenix

**Decision**: Use Phoenix's built-in config/runtime.exs for runtime ENV configuration, with compile-time secrets handled via build args.

**Rationale**: Phoenix natively supports ENV vars through config providers, ensuring security and flexibility for containerized deployments.

**Alternatives Considered**:
- Config files: Less secure for secrets
- System env only: Harder to manage defaults
- Custom config loader: Unnecessary complexity

## Dockerfile Best Practices for Phoenix

**Decision**: Multi-stage Dockerfile with Elixir base image, using distillery/edeliver for releases, exposing port 4000 for web and 4001 for live reload.

**Rationale**: Optimizes image size, follows Elixir community standards, and supports both production and development modes.

**Alternatives Considered**:
- Single stage: Larger images
- Alpine base: Potential compatibility issues with NIFs
- Custom base image: Maintenance burden

## GitOps Repository Structure

**Decision**: Structure GitOps repo with apps/ directory containing ArgoCD Applications, overlays/ for environment-specific configs, and base/ for shared manifests.

**Rationale**: Standard ArgoCD pattern that supports multi-environment deployments and keeps configurations DRY.

**Alternatives Considered**:
- Flat structure: Harder to manage environments
- App-per-repo: Overkill for this scale
- Monorepo with everything: Too coupled