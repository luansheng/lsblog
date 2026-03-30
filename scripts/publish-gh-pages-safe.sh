#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

if [[ $# -eq 0 ]]; then
  quarto render --cache-refresh
else
  quarto render "$1" --cache-refresh
fi

printf 'Y\n' | quarto publish gh-pages
