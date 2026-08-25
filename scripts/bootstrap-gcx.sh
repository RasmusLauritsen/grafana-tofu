#!/usr/bin/env bash
set -Eeuo pipefail

grafana_url='http://localhost:3000'
admin_auth='admin:password'
service_account_name='gcx-admin'
token_name='gcx-local'

service_account_id="$({
  curl -fsS -u "$admin_auth" \
    "$grafana_url/api/serviceaccounts/search?query=$service_account_name"
} | jq -r --arg name "$service_account_name" '.serviceAccounts[]? | select(.name == $name) | .id' | head -n1)"

if [[ -z "$service_account_id" ]]; then
  service_account_id="$({
    curl -fsS -u "$admin_auth" \
      -H 'Content-Type: application/json' \
      -d "{\"name\":\"$service_account_name\",\"role\":\"Admin\"}" \
      "$grafana_url/api/serviceaccounts"
  } | jq -r '.id')"
fi

existing_token_id="$({
  curl -fsS -u "$admin_auth" \
    "$grafana_url/api/serviceaccounts/$service_account_id/tokens"
} | jq -r --arg name "$token_name" '.[]? | select(.name == $name) | .id' | head -n1)"

if [[ -n "$existing_token_id" ]] && gcx --context local config check >/dev/null 2>&1; then
  exit 0
fi

if [[ -n "$existing_token_id" ]]; then
  curl -fsS -u "$admin_auth" -X DELETE \
    "$grafana_url/api/serviceaccounts/$service_account_id/tokens/$existing_token_id" \
    >/dev/null
fi

token="$({
  curl -fsS -u "$admin_auth" \
    -H 'Content-Type: application/json' \
    -d "{\"name\":\"$token_name\",\"secondsToLive\":0}" \
    "$grafana_url/api/serviceaccounts/$service_account_id/tokens"
} | jq -r '.key')"

gcx config set stacks.local.grafana.server "$grafana_url" >/dev/null
gcx config set stacks.local.grafana.token "$token" >/dev/null
gcx config set stacks.local.grafana.org-id 1 >/dev/null
gcx config set contexts.local.stack local >/dev/null
gcx config use-context local >/dev/null
gcx config check
