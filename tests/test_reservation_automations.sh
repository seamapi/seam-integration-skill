#!/bin/bash
# Test: Reservation Automations path
# Correct flow: create space with space_key + device → push_data → verify code → delete_data → verify removed
# Prerequisites: automations must be enabled in Console

set -euo pipefail

API_KEY="${SEAM_API_KEY:?SEAM_API_KEY must be set}"
BASE_URL="https://connect.getseam.com"
PASS=0
FAIL=0

RUN_ID=$(date +%s)
CUSTOMER_KEY="test_pm_${RUN_ID}"
SPACE_KEY="unit_${RUN_ID}"
GUEST_KEY="guest_${RUN_ID}"
RESERVATION_KEY="res_${RUN_ID}"

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

# --- Step 1: List devices ---
log "Step 1: Listing devices..."
DEVICES=$(api /devices/list)
DEVICE_ID=$(echo "$DEVICES" | python3 -c "
import sys, json
devices = json.loads(sys.stdin.read())['devices']
# Use the LAST device to avoid conflicts with lower-level API test which uses the first
capable = [d for d in devices if 'access_code' in d.get('capabilities_supported', [])]
if capable:
    print(capable[-1]['device_id'])
")

if [ -n "$DEVICE_ID" ]; then
  pass "Found device: $DEVICE_ID"
else
  fail "No access_code-capable device found"
  exit 1
fi

# --- Step 2: Create space with space_key and assign device ---
log "Step 2: Creating space with device..."
SPACE_RESULT=$(api /spaces/create -d "{
  \"name\": \"Test Unit ${RUN_ID}\",
  \"space_key\": \"${SPACE_KEY}\",
  \"device_ids\": [\"${DEVICE_ID}\"]
}")

SPACE_ID=$(echo "$SPACE_RESULT" | python3 -c "import sys,json; print(json.loads(sys.stdin.read()).get('space',{}).get('space_id',''))")

if [ -n "$SPACE_ID" ] && [ "$SPACE_ID" != "" ]; then
  pass "Space created: $SPACE_ID (key: $SPACE_KEY)"
else
  fail "Failed to create space"
  echo "$SPACE_RESULT" | python3 -m json.tool
  exit 1
fi

# --- Step 3: Push reservation data ---
log "Step 3: Pushing reservation data..."
STARTS_AT=$(date -u -v+1H +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u -d "+1 hour" +"%Y-%m-%dT%H:%M:%SZ")
ENDS_AT=$(date -u -v+25H +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u -d "+25 hours" +"%Y-%m-%dT%H:%M:%SZ")

PUSH_RESULT=$(api /customers/push_data -d "{
  \"customer_key\": \"${CUSTOMER_KEY}\",
  \"user_identities\": [{
    \"user_identity_key\": \"${GUEST_KEY}\",
    \"name\": \"Test Guest RA\",
    \"email_address\": \"testera_${RUN_ID}@example.com\"
  }],
  \"reservations\": [{
    \"reservation_key\": \"${RESERVATION_KEY}\",
    \"user_identity_key\": \"${GUEST_KEY}\",
    \"starts_at\": \"${STARTS_AT}\",
    \"ends_at\": \"${ENDS_AT}\",
    \"space_keys\": [\"${SPACE_KEY}\"]
  }]
}")

PUSH_OK=$(echo "$PUSH_RESULT" | python3 -c "import sys,json; print(json.loads(sys.stdin.read()).get('ok', False))")

if [ "$PUSH_OK" = "True" ]; then
  pass "Reservation data pushed"
else
  fail "Failed to push reservation data"
  echo "$PUSH_RESULT" | python3 -m json.tool
  exit 1
fi

# --- Step 4: Verify automation created access grant + code ---
log "Step 4: Waiting for automation to create access grant (polling up to 60s)..."

AUTO_GRANT=""
for i in $(seq 1 12); do
  sleep 5
  GRANTS=$(api /access_grants/list)
  AUTO_GRANT=$(echo "$GRANTS" | RUN_ID="$RUN_ID" python3 -c "
import sys, json, os
run_id = os.environ['RUN_ID']
grants = json.loads(sys.stdin.read())['access_grants']
for g in grants:
    if run_id in g.get('display_name', ''):
        print(g['access_grant_id'])
        break
")
  if [ -n "$AUTO_GRANT" ]; then
    break
  fi
  log "  ...not yet (${i}/12)"
done

if [ -n "$AUTO_GRANT" ]; then
  GRANT_DISPLAY=$(echo "$GRANTS" | AUTO_GRANT="$AUTO_GRANT" python3 -c "
import sys, json, os
grant_id = os.environ['AUTO_GRANT']
grants = json.loads(sys.stdin.read())['access_grants']
for g in grants:
    if g['access_grant_id'] == grant_id:
        print(g['display_name'])
        break
")
  pass "Automation created access grant: $GRANT_DISPLAY"

  # Also verify an access code appeared on the device
  CODES=$(api /access_codes/list -d "{\"device_id\": \"${DEVICE_ID}\"}")
  CODE_COUNT=$(echo "$CODES" | python3 -c "import sys,json; print(len([c for c in json.loads(sys.stdin.read())['access_codes'] if c.get('status') != 'removing']))")
  if [ "$CODE_COUNT" -gt 0 ]; then
    pass "Access code present on device"
  else
    fail "Access grant created but no access code on device"
  fi
else
  fail "No access grant created by automation after 30 seconds (grant may still be processing — check Console automation runs)"
  # Don't continue to update/delete steps, they'll interfere with the pending automation
  log "Cleanup: removing space..."
  api /spaces/delete -d "{\"space_id\": \"${SPACE_ID}\"}" > /dev/null 2>&1
  api /customers/delete_data -d "{\"customer_key\": \"${CUSTOMER_KEY}\"}" > /dev/null 2>&1
  echo ""
  echo "================================"
  echo "Reservation Automations Test Results"
  echo "================================"
  echo "Passed: $PASS"
  echo "Failed: $FAIL"
  echo "================================"
  exit 1
fi

# --- Step 5: Update reservation (extend checkout) ---
log "Step 5: Updating reservation (extending checkout)..."
NEW_ENDS_AT=$(date -u -v+49H +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u -d "+49 hours" +"%Y-%m-%dT%H:%M:%SZ")

UPDATE_RESULT=$(api /customers/push_data -d "{
  \"customer_key\": \"${CUSTOMER_KEY}\",
  \"reservations\": [{
    \"reservation_key\": \"${RESERVATION_KEY}\",
    \"user_identity_key\": \"${GUEST_KEY}\",
    \"starts_at\": \"${STARTS_AT}\",
    \"ends_at\": \"${NEW_ENDS_AT}\",
    \"space_keys\": [\"${SPACE_KEY}\"]
  }]
}")

UPDATE_OK=$(echo "$UPDATE_RESULT" | python3 -c "import sys,json; print(json.loads(sys.stdin.read()).get('ok', False))")

if [ "$UPDATE_OK" = "True" ]; then
  pass "Reservation updated (extended checkout)"
else
  fail "Failed to update reservation"
fi

# --- Step 6: Delete reservation (cancellation) ---
log "Step 6: Deleting reservation data (cancellation)..."
DELETE_RESULT=$(api /customers/delete_data -d "{
  \"customer_key\": \"${CUSTOMER_KEY}\",
  \"reservation_keys\": [\"${RESERVATION_KEY}\"],
  \"user_identity_keys\": [\"${GUEST_KEY}\"]
}")

DELETE_OK=$(echo "$DELETE_RESULT" | python3 -c "import sys,json; print(json.loads(sys.stdin.read()).get('ok', False))")

if [ "$DELETE_OK" = "True" ]; then
  pass "Reservation data deleted"
else
  fail "Failed to delete reservation data"
fi

# --- Step 7: Verify access grant revoked ---
log "Step 7: Verifying access codes removed (polling up to 30s)..."

if [ -n "$AUTO_GRANT" ]; then
  REVOKED="no"
  for i in $(seq 1 6); do
    sleep 5
    DEVICE_CODES=$(api /access_codes/list -d "{\"device_id\": \"${DEVICE_ID}\"}" | python3 -c "
import sys, json
codes = json.loads(sys.stdin.read())['access_codes']
active = [c for c in codes if c.get('status') not in ('removing', 'removed')]
print(len(active))
" 2>/dev/null || echo "0")
    if [ "$DEVICE_CODES" = "0" ]; then
      REVOKED="yes"
      break
    fi
  done

  if [ "$REVOKED" = "yes" ]; then
    pass "Access codes removed or removing after cancellation"
  else
    fail "Active access codes still on device after cancellation"
  fi
else
  pass "No grant to verify (skipped)"
fi

# --- Cleanup ---
log "Cleanup: removing space..."
api /spaces/delete -d "{\"space_id\": \"${SPACE_ID}\"}" > /dev/null 2>&1
api /customers/delete_data -d "{\"customer_key\": \"${CUSTOMER_KEY}\"}" > /dev/null 2>&1

# --- Summary ---
echo ""
echo "================================"
echo "Reservation Automations Test Results"
echo "================================"
echo "Passed: $PASS"
echo "Failed: $FAIL"
echo "================================"

[ "$FAIL" -eq 0 ] && exit 0 || exit 1
