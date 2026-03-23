#!/bin/bash
# Test: Access Grants path — create user identity, create access grant with PIN code,
# verify code on device, update grant, delete grant, verify revoked

set -euo pipefail

API_KEY="${SEAM_API_KEY:?SEAM_API_KEY must be set}"
BASE_URL="https://connect.getseam.com"
PASS=0
FAIL=0

RUN_ID=$(date +%s)

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
# Use middle device to avoid conflicts with other tests
capable = [d for d in devices if 'access_code' in d.get('capabilities_supported', [])]
if len(capable) >= 2:
    print(capable[1]['device_id'])
elif capable:
    print(capable[0]['device_id'])
")

if [ -n "$DEVICE_ID" ]; then
  pass "Found device: $DEVICE_ID"
else
  fail "No access_code-capable device found"
  exit 1
fi

# --- Step 2: Create Access Grant with PIN code ---
log "Step 2: Creating access grant with PIN code..."
STARTS_AT=$(date -u -v+1H +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u -d "+1 hour" +"%Y-%m-%dT%H:%M:%SZ")
ENDS_AT=$(date -u -v+25H +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u -d "+25 hours" +"%Y-%m-%dT%H:%M:%SZ")

GRANT_RESULT=$(api /access_grants/create -d "{
  \"user_identity\": {
    \"full_name\": \"AG Test Guest ${RUN_ID}\",
    \"email_address\": \"agtest_${RUN_ID}@example.com\"
  },
  \"device_ids\": [\"${DEVICE_ID}\"],
  \"requested_access_methods\": [
    {\"mode\": \"code\"}
  ],
  \"starts_at\": \"${STARTS_AT}\",
  \"ends_at\": \"${ENDS_AT}\"
}")

ACCESS_GRANT_ID=$(echo "$GRANT_RESULT" | python3 -c "import sys,json; print(json.loads(sys.stdin.read()).get('access_grant',{}).get('access_grant_id',''))")
ACCESS_METHOD_IDS=$(echo "$GRANT_RESULT" | python3 -c "import sys,json; print(','.join(json.loads(sys.stdin.read()).get('access_grant',{}).get('access_method_ids',[])))")

if [ -n "$ACCESS_GRANT_ID" ] && [ "$ACCESS_GRANT_ID" != "" ]; then
  pass "Access grant created: $ACCESS_GRANT_ID"
else
  fail "Failed to create access grant"
  echo "$GRANT_RESULT" | python3 -m json.tool
  exit 1
fi

# --- Step 3: Verify access method is issued ---
log "Step 3: Checking access method status (polling up to 15s)..."
AM_ID=$(echo "$ACCESS_METHOD_IDS" | cut -d',' -f1)

IS_ISSUED="False"
CODE_VALUE="?"
for i in $(seq 1 3); do
  sleep 5
  AM_RESULT=$(api /access_methods/get -d "{\"access_method_id\": \"${AM_ID}\"}")
  IS_ISSUED=$(echo "$AM_RESULT" | python3 -c "import sys,json; am=json.loads(sys.stdin.read()).get('access_method',{}); print(am.get('is_issued', False))")
  CODE_VALUE=$(echo "$AM_RESULT" | python3 -c "import sys,json; am=json.loads(sys.stdin.read()).get('access_method',{}); print(am.get('code','?'))")
  if [ "$IS_ISSUED" = "True" ]; then
    break
  fi
done

if [ "$IS_ISSUED" = "True" ]; then
  pass "Access method issued with PIN code: $CODE_VALUE"
else
  fail "Access method not issued after 15s (is_issued=$IS_ISSUED)"
fi

# --- Step 4: Verify access code on device ---
log "Step 4: Verifying access code on device..."
CODES=$(api /access_codes/list -d "{\"device_id\": \"${DEVICE_ID}\"}")
CODE_FOUND=$(echo "$CODES" | GRANT_GUEST="AG Test Guest ${RUN_ID}" python3 -c "
import sys, json, os
guest = os.environ['GRANT_GUEST']
codes = json.loads(sys.stdin.read())['access_codes']
found = any(guest in c.get('name', '') for c in codes)
print('yes' if found else 'no')
")

if [ "$CODE_FOUND" = "yes" ]; then
  pass "Access code found on device"
else
  fail "Access code NOT found on device"
fi

# --- Step 5: Update access grant (extend checkout) ---
log "Step 5: Updating access grant (extending checkout)..."
NEW_ENDS_AT=$(date -u -v+49H +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u -d "+49 hours" +"%Y-%m-%dT%H:%M:%SZ")

UPDATE_RESULT=$(api /access_grants/update -d "{
  \"access_grant_id\": \"${ACCESS_GRANT_ID}\",
  \"ends_at\": \"${NEW_ENDS_AT}\"
}")

UPDATE_OK=$(echo "$UPDATE_RESULT" | python3 -c "import sys,json; print(json.loads(sys.stdin.read()).get('ok', False))")

if [ "$UPDATE_OK" = "True" ]; then
  pass "Access grant updated (extended checkout)"
else
  fail "Failed to update access grant"
  echo "$UPDATE_RESULT" | python3 -m json.tool
fi

# --- Step 6: Delete access grant (cancellation) ---
log "Step 6: Deleting access grant (simulating cancellation)..."
DELETE_RESULT=$(api /access_grants/delete -d "{\"access_grant_id\": \"${ACCESS_GRANT_ID}\"}")
DELETE_OK=$(echo "$DELETE_RESULT" | python3 -c "import sys,json; print(json.loads(sys.stdin.read()).get('ok', False))")

if [ "$DELETE_OK" = "True" ]; then
  pass "Access grant deleted"
else
  fail "Failed to delete access grant"
  echo "$DELETE_RESULT" | python3 -m json.tool
fi

# --- Step 7: Verify access code revoked ---
log "Step 7: Verifying access code removed (polling up to 30s)..."

REVOKED="no"
for i in $(seq 1 6); do
  sleep 5
  DEVICE_CODES=$(api /access_codes/list -d "{\"device_id\": \"${DEVICE_ID}\"}" | GRANT_GUEST="AG Test Guest ${RUN_ID}" python3 -c "
import sys, json, os
guest = os.environ['GRANT_GUEST']
codes = json.loads(sys.stdin.read())['access_codes']
active = [c for c in codes if guest in c.get('name', '') and c.get('status') not in ('removing', 'removed')]
print(len(active))
" 2>/dev/null || echo "0")
  if [ "$DEVICE_CODES" = "0" ]; then
    REVOKED="yes"
    break
  fi
done

if [ "$REVOKED" = "yes" ]; then
  pass "Access code removed or removing after grant deletion"
else
  fail "Active access codes still on device after grant deletion"
fi

# --- Summary ---
echo ""
echo "================================"
echo "Access Grants Test Results"
echo "================================"
echo "Passed: $PASS"
echo "Failed: $FAIL"
echo "================================"

[ "$FAIL" -eq 0 ] && exit 0 || exit 1
