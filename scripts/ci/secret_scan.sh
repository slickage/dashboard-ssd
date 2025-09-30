#!/usr/bin/env bash
set -euo pipefail

if [[ "${SKIP_SECRET_SCAN:-false}" == "true" ]]; then
  echo "Skipping secret scan (SKIP_SECRET_SCAN=true)."
  exit 0
fi

CONFIG_PATH=${GITLEAKS_CONFIG:-".gitleaks.toml"}
COMMON_ARGS=(detect --source . --no-git --exit-code 1 --config "$CONFIG_PATH")

if command -v gitleaks >/dev/null 2>&1; then
  echo "Running gitleaks (local binary)..."
  exec gitleaks "${COMMON_ARGS[@]}"
fi

if command -v docker >/dev/null 2>&1; then
  echo "Running gitleaks via Docker..."
  exec docker run --rm -v "$PWD:/workspace" zricethezav/gitleaks:latest detect --source=/workspace --no-git --exit-code 1 --config /workspace/${CONFIG_PATH}
fi

echo "gitleaks (binary or docker) is required for secret scanning." >&2
exit 1
