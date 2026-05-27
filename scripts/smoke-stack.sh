#!/usr/bin/env bash
# SPEC-010 — full-stack smoke: health, SPA shell, GraduateProgram API CRUD via Nginx
set -euo pipefail

BASE_URL="${SMOKE_BASE_URL:-http://localhost}"
API_URL="${BASE_URL}/api"
AUTH_USER="${SMOKE_AUTH_USER:-coordinator}"
AUTH_PASS="${SMOKE_COORDINATOR_PASSWORD:-changeme}"
PROGRAM_NAME="${SMOKE_PROGRAM_NAME:-Smoke Program $(date +%s)}"
DIVISION="${SMOKE_DIVISION:-CBI}"

fail() {
  echo "SMOKE FAILED: $*" >&2
  exit 1
}

echo "==> Health (proxied actuator)"
HEALTH_BODY="$(curl -sf "${API_URL}/actuator/health" || fail "actuator health unreachable at ${API_URL}/actuator/health")"
echo "${HEALTH_BODY}" | grep -q '"status":"UP"' || fail "actuator status is not UP"

echo "==> SPA shell"
HTML="$(curl -sf "${BASE_URL}/" || fail "edge unreachable at ${BASE_URL}/")"
echo "${HTML}" | grep -qE '<app-root|data-testid="app-shell"' || fail "SPA root marker not found in HTML"

echo "==> POST /api/programs"
CREATE_FILE="$(mktemp)"
HTTP_CODE="$(curl -s -u "${AUTH_USER}:${AUTH_PASS}" \
  -H "Content-Type: application/json" \
  -d "{\"name\":\"${PROGRAM_NAME}\",\"division\":\"${DIVISION}\"}" \
  -o "${CREATE_FILE}" \
  -w "%{http_code}" \
  -X POST "${API_URL}/programs")"
[ "${HTTP_CODE}" = "201" ] || fail "POST /api/programs returned ${HTTP_CODE}: $(cat "${CREATE_FILE}")"

if command -v jq >/dev/null 2>&1; then
  PROGRAM_ID="$(jq -r '.id' "${CREATE_FILE}")"
else
  PROGRAM_ID="$(grep -oE '"id"[[:space:]]*:[[:space:]]*[0-9]+' "${CREATE_FILE}" | head -1 | grep -oE '[0-9]+')"
fi
[ -n "${PROGRAM_ID}" ] && [ "${PROGRAM_ID}" != "null" ] || fail "could not parse program id from create response"
rm -f "${CREATE_FILE}"

echo "==> GET /api/programs"
LIST_BODY="$(curl -sf -u "${AUTH_USER}:${AUTH_PASS}" "${API_URL}/programs" \
  || fail "GET /api/programs failed")"
echo "${LIST_BODY}" | grep -q "${PROGRAM_NAME}" || fail "created program not found in list"

echo "==> GET /api/programs/${PROGRAM_ID}"
GET_BODY="$(curl -sf -u "${AUTH_USER}:${AUTH_PASS}" "${API_URL}/programs/${PROGRAM_ID}" \
  || fail "GET /api/programs/${PROGRAM_ID} failed")"
echo "${GET_BODY}" | grep -q "${PROGRAM_NAME}" || fail "program name mismatch on GET by id"

echo "SMOKE OK"
