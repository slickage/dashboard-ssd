#!/usr/bin/env bash
set -euo pipefail

# usage: bump_version_field.sh <NEW_VERSION>
# replaces : "x.y.z[-prerelease]"
# with $NEW_VERSION
NEW_VERSION="$1"

# Replace: version: "x.y.z[-prerelease]"
if grep -Eq "version:\s*\"[0-9]+\.[0-9]+\.[0-9]+" "mix.exs"; then
  sed -Ei "s/(version:\s*\")[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z\.-]+)?(\")/\1${NEW_VERSION}\3/" "mix.exs"
else
  echo "❌ version field not found in mix.exs ($NEW_VERSION)" >&2
  exit 1
fi
