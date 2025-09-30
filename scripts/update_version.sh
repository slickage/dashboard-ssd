#!/usr/bin/env bash
set -euo pipefail

if [ $# -ne 1 ]; then
  echo "Usage: $0 NEW_VERSION" >&2
  exit 1
fi

NEW_VERSION="$1"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${PROJECT_ROOT}"

export NEW_VERSION

elixir -e "
new_version = System.fetch_env!(\"NEW_VERSION\")
content = File.read!(\"mix.exs\")
pattern = ~r/(version:\\s*\")\\d+\\.\\d+\\.\\d+(\")/

unless Regex.match?(pattern, content) do
  raise \"Could not find version declaration in mix.exs\"
end

updated =
  Regex.replace(
    pattern,
    content,
    fn _match, prefix, suffix -> \"#{prefix}#{new_version}#{suffix}\" end,
    global: false
  )

File.write!(\"mix.exs\", updated)
"
