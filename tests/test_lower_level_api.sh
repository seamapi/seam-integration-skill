#!/bin/bash
# Test: Lower-level API path — create, verify, update, delete access codes
# This verifies the exact flow the skill teaches for Path C

set -euo pipefail

API_KEY="${SEAM_API_KEY:?SEAM_API_KEY must be set}"
BASE_URL="https://connect.getseam.com"
PASS=0
FAIL=0

log() { echo "[$(date +%H:%M:%S)] $*"; }
pass() { log "✓ $*"; PASS=$((PASS + 1)); }
fail() { log "✗ $*"; FAIL=$((FAIL + 1)); }

api() {
  local endpoint="$1"
  shift
  curl -s -X POST "${BASE_URL}${endpoint}" \
    -H "Authorization: Bearer ${API_KEY}" \
    -H "Content-Type: application/json" \
    "$@"
}

# --- Step 1: List devices (skill Step 2e verification) ---
log "Step 1: Listing devices..."
DEVICES=$(api /devices/list)
DEVICE_COUNT=$(echo "$DEVICES" | python3 -c "import sys,json; print(len(json.loads(sys.stdin.read())['devices']))")

if [ "$DEVICE_COUNT" -gt 0 ]; then
  pass "Found $DEVICE_COUNT device(s)"
  DEVICE_ID=$(echo "$DEVICES" | python3 -c "
import sys, json
devices = json.loads(sys.stdin.read())['devices']
# Pick first device that supports access codes
for d in devices:
    if 'access_code' in d.get('capabilities_supported', []):
        print(d['device_id'])
        break
")
  log "Using device: $DEVICE_ID"
else
  fail "No devices found"
  exit 1
fi

# --- Step 2: Create a time-bound access code (skill Step 3C.1) ---
log "Step 2: Creating time-bound access code..."
STARTS_AT=$(date -u -v+1H +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u -d "+1 hour" +"%Y-%m-%dT%H:%M:%SZ")
ENDS_AT=$(date -u -v+25H +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u -d "+25 hours" +"%Y-%m-%dT%H:%M:%SZ")

CREATE_RESULT=$(api /access_codes/create -d "{
  \"device_id\": \"${DEVICE_ID}\",
  \"name\": \"Test Guest: Integration Test\",
  \"starts_at\": \"${STARTS_AT}\",
  \"ends_at\": \"${ENDS_AT}\"
}")

ACCESS_CODE_ID=$(echo "$CREATE_RESULT" | python3 -c "import sys,json; print(json.loads(sys.stdin.read()).get('access_code',{}).get('access_code_id',''))")
CODE_VALUE=$(echo "$CREATE_RESULT" | python3 -c "import sys,json; print(json.loads(sys.stdin.read()).get('access_code',{}).get('code',''))")

if [ -n "$ACCESS_CODE_ID" ] && [ "$ACCESS_CODE_ID" != "None" ]; then
  pass "Created access code: $ACCESS_CODE_ID (code: $CODE_VALUE)"
else
  fail "Failed to create access code"
  echo "$CREATE_RESULT" | python3 -m json.tool
  exit 1
fi

# --- Step 3: Verify access code exists on device (skill Step 3C.3) ---
log "Step 3: Verifying access code on device..."
CODES_ON_DEVICE=$(api /access_codes/list -d "{\"device_id\": \"${DEVICE_ID}\"}")
FOUND=$(echo "$CODES_ON_DEVICE" | python3 -c "
import sys, json
codes = json.loads(sys.stdin.read())['access_codes']
found = any(c['access_code_id'] == '${ACCESS_CODE_ID}' for c in codes)
print('yes' if found else 'no')
")

if [ "$FOUND" = "yes" ]; then
  pass "Access code found on device"
else
  fail "Access code NOT found on device"
fi

# --- Step 4: Update access code (skill Step 4C - reservation modified) ---
log "Step 4: Updating access code (simulating reservation change)..."
NEW_ENDS_AT=$(date -u -v+49H +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u -d "+49 hours" +"%Y-%m-%dT%H:%M:%SZ")

UPDATE_RESULT=$(api /access_codes/update -d "{
  \"access_code_id\": \"${ACCESS_CODE_ID}\",
  \"name\": \"Test Guest: Extended Stay\",
  \"ends_at\": \"${NEW_ENDS_AT}\"
}")

UPDATE_OK=$(echo "$UPDATE_RESULT" | python3 -c "import sys,json; print(json.loads(sys.stdin.read()).get('ok', False))")

if [ "$UPDATE_OK" = "True" ]; then
  pass "Access code updated (extended checkout)"
else
  fail "Failed to update access code"
  echo "$UPDATE_RESULT" | python3 -m json.tool
fi

# --- Step 5: Delete access code (skill Step 4C - reservation cancelled) ---
log "Step 5: Deleting access code (simulating cancellation)..."
DELETE_RESULT=$(api /access_codes/delete -d "{\"access_code_id\": \"${ACCESS_CODE_ID}\"}")
DELETE_OK=$(echo "$DELETE_RESULT" | python3 -c "import sys,json; print(json.loads(sys.stdin.read()).get('ok', False))")

if [ "$DELETE_OK" = "True" ]; then
  pass "Access code deleted"
else
  fail "Failed to delete access code"
  echo "$DELETE_RESULT" | python3 -m json.tool
fi

# --- Step 6: Verify access code is being removed (skill Step 4C verification) ---
log "Step 6: Verifying access code is removed or removing..."
sleep 1
CODE_STATUS=$(api /access_codes/get -d "{\"access_code_id\": \"${ACCESS_CODE_ID}\"}" 2>/dev/null)
# Poll for removal — code transitions through 'removing' before disappearing
REMOVED="no"
for i in $(seq 1 4); do
  sleep 2
  STATUS=$(api /access_codes/get -d "{\"access_code_id\": \"${ACCESS_CODE_ID}\"}" 2>/dev/null | python3 -c "
import sys, json
data = json.loads(sys.stdin.read())
if 'error' in data:
    print('not_found')
else:
    print(data.get('access_code', {}).get('status', 'unknown'))
" 2>/dev/null || echo "not_found")
  if [ "$STATUS" = "removing" ] || [ "$STATUS" = "not_found" ]; then
    REMOVED="yes"
    break
  fi
done

if [ "$REMOVED" = "yes" ]; then
  pass "Access code is removed or removing (status: $STATUS)"
else
  fail "Access code still active after deletion (status: $STATUS)"
fi

# --- Summary ---
echo ""
echo "================================"
echo "Lower-level API Test Results"
echo "================================"
echo "Passed: $PASS"
echo "Failed: $FAIL"
echo "================================"

[ "$FAIL" -eq 0 ] && exit 0 || exit 1
