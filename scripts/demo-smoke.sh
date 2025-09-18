#!/usr/bin/env bash
set -euo pipefail

command -v curl >/dev/null 2>&1 || { echo "curl is required" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "jq is required" >&2; exit 1; }

BASE_URL=${BASE_URL:-http://localhost:8080}
AUTH_TOKEN=${DEMO_AUTH_TOKEN:-local-token}
HEALTH_ENDPOINT="${BASE_URL}/healthz"
WIDGET_ENDPOINT="${BASE_URL}/api/v1/widgets"

log() {
  printf '[demo-smoke] %s\n' "$1"
}

log "Waiting for application at ${HEALTH_ENDPOINT}..."
for attempt in {1..30}; do
  if curl --silent --fail "${HEALTH_ENDPOINT}" >/dev/null 2>&1; then
    log "Service is responsive."
    break
  fi
  sleep 2
  if [[ $attempt -eq 30 ]]; then
    log "Timed out waiting for service." >&2
    exit 1
  fi
done

log "Creating widget..."
CREATE_RESPONSE=$(curl --silent --fail \
  -H "Content-Type: application/json" \
  -H "X-Demo-Auth: ${AUTH_TOKEN}" \
  -X POST \
  -d '{"name":"smoke widget","description":"created via demo-smoke"}' \
  "${WIDGET_ENDPOINT}")

WIDGET_ID=$(echo "${CREATE_RESPONSE}" | jq -r '.id')
if [[ -z "${WIDGET_ID}" || "${WIDGET_ID}" == "null" ]]; then
  log "Failed to parse widget id from response: ${CREATE_RESPONSE}" >&2
  exit 1
fi
log "Created widget ${WIDGET_ID}."

log "Listing widgets..."
LIST_RESPONSE=$(curl --silent --fail "${WIDGET_ENDPOINT}")
COUNT=$(echo "${LIST_RESPONSE}" | jq 'length')
log "Widget count: ${COUNT}."

log "Deleting widget ${WIDGET_ID}..."
curl --silent --fail -H "X-Demo-Auth: ${AUTH_TOKEN}" -X DELETE "${WIDGET_ENDPOINT}/${WIDGET_ID}" >/dev/null
log "Widget ${WIDGET_ID} deleted."

log "Smoke test complete."
