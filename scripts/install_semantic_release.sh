#!/usr/bin/env bash
set -euo pipefail

npm install --no-audit --no-fund --silent \
  semantic-release@22.0.12 \
  @semantic-release/changelog@6.0.3 \
  @semantic-release/git@10.0.1 \
  @semantic-release/exec@6.0.3 \
  @semantic-release/commit-analyzer@10.0.3 \
  @semantic-release/release-notes-generator@11.0.3 \
  @semantic-release/github@9.2.3
