#!/usr/bin/env bash
set -euo pipefail

command -v curl >/dev/null 2>&1 || { echo "curl is required" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "jq is required" >&2; exit 1; }

BASE_URL=${BASE_URL:-http://localhost:8080}
AUTH_TOKEN=${DEMO_AUTH_TOKEN:-local-token}
HEALTH_ENDPOINT="${BASE_URL}/actuator/health"
WIDGET_ENDPOINT="${BASE_URL}/api/v1/widgets"

log() {
  printf '[demo-smoke] %s\n' "$1"
}

log "Waiting for application at ${HEALTH_ENDPOINT}..."
STATUS=""
for attempt in {1..30}; do
  HEALTH_RESPONSE=$(curl --silent --show-error --fail "${HEALTH_ENDPOINT}" || true)
  if [[ -n "${HEALTH_RESPONSE}" ]]; then
    STATUS=$(echo "${HEALTH_RESPONSE}" | jq -r '.status // empty')
    if [[ "${STATUS}" == "UP" ]]; then
      log "Service is healthy."
      break
    fi
  fi
  sleep 2
  if [[ $attempt -eq 30 ]]; then
    log "Timed out waiting for healthy service." >&2
    exit 1
  fi
done

if [[ "${STATUS}" != "UP" ]]; then
  log "Health check did not report UP: ${HEALTH_RESPONSE}" >&2
  exit 1
fi

log "Validating unauthorized create is rejected..."
UNAUTHORIZED_STATUS=$(curl --silent --show-error --output /dev/null --write-out '%{http_code}' \
  -H "Content-Type: application/json" \
  -H "X-Demo-Auth: invalid-token" \
  -X POST \
  -d '{"name":"unauth","description":"should fail"}' \
  "${WIDGET_ENDPOINT}")

if [[ "${UNAUTHORIZED_STATUS}" != "401" ]]; then
  log "Unauthorized create did not return 401 with invalid token (was ${UNAUTHORIZED_STATUS})." >&2
  exit 1
fi
log "Unauthorized create correctly rejected."

log "Creating widget..."
CREATE_RESPONSE=$(curl --silent --show-error --fail \
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

log "Fetching created widget..."
FETCHED=$(curl --silent --show-error --fail "${WIDGET_ENDPOINT}/${WIDGET_ID}")
NAME=$(echo "${FETCHED}" | jq -r '.name')
if [[ "${NAME}" != "smoke widget" ]]; then
  log "Fetched widget name mismatch: ${FETCHED}" >&2
  exit 1
fi

log "Listing widgets..."
LIST_RESPONSE=$(curl --silent --show-error --fail "${WIDGET_ENDPOINT}")
COUNT=$(echo "${LIST_RESPONSE}" | jq 'length')
if [[ "${COUNT}" -lt 1 ]]; then
  log "Widget list unexpectedly empty: ${LIST_RESPONSE}" >&2
  exit 1
fi
log "Widget count: ${COUNT}."

log "Deleting widget ${WIDGET_ID}..."
curl --silent --show-error --fail \
  -H "X-Demo-Auth: ${AUTH_TOKEN}" \
  -X DELETE "${WIDGET_ENDPOINT}/${WIDGET_ID}" >/dev/null
log "Widget ${WIDGET_ID} deleted."

log "Verifying widget removal..."
DELETE_STATUS=$(curl --silent --show-error --output /dev/null --write-out '%{http_code}' \
  "${WIDGET_ENDPOINT}/${WIDGET_ID}" || true)
if [[ "${DELETE_STATUS}" != "404" ]]; then
  log "Deleted widget still retrievable (status ${DELETE_STATUS})." >&2
  exit 1
fi

log "Smoke test complete."
