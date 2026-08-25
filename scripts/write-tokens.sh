#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

tokens="$(tofu output -json team_tokens)"

{
  printf '# Grafana Team Service Account Tokens\n\n'
  printf '> Generated locally. This file is intentionally ignored by Git.\n\n'
  jq -r 'to_entries[] | "## \(.key | ascii_upcase)\n\n```text\n\(.value)\n```\n"' <<<"$tokens"
} > tokens.md
