---
name: seam-access-grants
description: >-
  Integrate Seam Access Grants for per-entrance, per-credential control over smart lock access.
  Create access grants specifying who gets access to which doors, when, and how (PIN code, mobile key,
  Instant Key). Use this skill when someone needs to control which access methods each guest or member
  gets, issue both PIN codes and mobile keys, manage access per-door (room + lobby + gym), or deliver
  Instant Key links. Works with August, Yale, Schlage, Kwikset, and other smart locks.
  Common use cases: hotel guest apps, gym/fitness access, office visitor management.
version: 0.5.0
---

# Seam Access Grants

You are an expert Seam integration engineer. Write the integration code directly into the developer's existing codebase.

## Approach

1. **Move fast.** Glob for key files (booking/reservation handlers, routes, models), read them, start writing code.
2. **Write code in existing files.** Add Seam calls directly into existing service/handler functions. Don't create wrapper services.
3. **Minimize changes.** Only touch files that need Seam calls + webhook route. Install SDK, add import, add calls.

## How Access Grants works

You create an access grant specifying a user identity, target devices, requested access methods (PIN, mobile key), and a time window. Seam provisions the credentials on the locks. You must store the `access_grant_id` to update or delete it later.

## 1. Install SDK + initialize

**Do NOT pin to a specific version.**

```bash
npm install seam        # Node.js
pip install seam        # Python
bundle add seam         # Ruby
```

**CRITICAL for Next.js:** `new Seam()` at module scope BREAKS `next build`. Use a lazy getter:

```typescript
import { Seam } from "seam";
let _seam: Seam;
function getSeam() {
  if (!_seam) _seam = new Seam({ apiKey: process.env.SEAM_API_KEY! });
  return _seam;
}
```

For Express / standard Node.js:

```typescript
import { Seam } from "seam";
const seam = new Seam({ apiKey: process.env.SEAM_API_KEY });
```

```python
from seam import Seam
seam = Seam(api_key=os.environ["SEAM_API_KEY"])
```

## 2. Get the device ID

Access Grants targets specific devices by `device_id`. Look for device IDs in:
- Environment variables: `SEAM_DEVICE_ID`, `SEAM_DEVICE_ROOM_101`, `SEAM_DEVICE_ID_ROOM_101`
- The app's data model (e.g., `room.seamDeviceId`, `unit.deviceId`)

If the app doesn't have device IDs yet, read from `process.env.SEAM_DEVICE_ID` — device IDs are configured when locks are connected to Seam.

## 3. Create access grant on booking creation

Add directly inside the create function. **Store the `access_grant_id` on the booking object.**

```typescript
// Inside createBooking(), after saving the booking:
try {
  const accessGrant = await seam.accessGrants.create({
    user_identity: {
      full_name: guest.name,
      email_address: guest.email
    },
    device_ids: [room.seamDeviceId || process.env.SEAM_DEVICE_ID],
    requested_access_methods: [
      { mode: "code" }           // PIN code
      // { mode: "mobile_key" }  // Add for mobile key + Instant Key
    ],
    starts_at: booking.checkIn,
    ends_at: booking.checkOut
  });
  booking.seamAccessGrantId = accessGrant.access_grant_id;
} catch (err) {
  console.error("Seam access grant failed:", err);
}
```

```python
# Inside create_booking(), after saving:
try:
    access_grant = seam.access_grants.create(
        user_identity={"full_name": guest.name, "email_address": guest.email},
        device_ids=[room.seam_device_id or os.environ.get("SEAM_DEVICE_ID")],
        requested_access_methods=[{"mode": "code"}],
        starts_at=booking.check_in,
        ends_at=booking.check_out
    )
    booking.seam_access_grant_id = access_grant.access_grant_id
except Exception as e:
    print(f"Seam access grant failed: {e}")
```

## Gotchas

- **Store `access_grant_id`** — you need it for update and delete. Add a field to the booking model if one doesn't exist.
- **`user_identity`** takes `full_name` and `email_address`, NOT `name` and `email`.
- **`device_ids`** is an array — you can grant access to multiple doors in one call.
- **`requested_access_methods`** — `"code"` for PIN, `"mobile_key"` for mobile key + Instant Key.
- Wrap all Seam calls in try/catch — Seam errors shouldn't break the booking flow.

## 4. Update access grant on booking changes

```typescript
if (booking.seamAccessGrantId) {
  await seam.accessGrants.update({
    access_grant_id: booking.seamAccessGrantId,
    starts_at: booking.checkIn,
    ends_at: booking.checkOut
  });
}
```

## 5. Delete access grant on cancellation

```typescript
if (booking.seamAccessGrantId) {
  await seam.accessGrants.delete({
    access_grant_id: booking.seamAccessGrantId
  });
}
```

```python
if booking.seam_access_grant_id:
    seam.access_grants.delete(
        access_grant_id=booking.seam_access_grant_id
    )
```

## 6. Add webhook endpoint

Follow the existing webhook pattern in the codebase:

```typescript
router.post("/seam", (req, res) => {
  const { event_type, ...data } = req.body;
  switch (event_type) {
    case "access_code.set_on_device":
      console.log("PIN set on lock:", data.access_code_id);
      break;
    case "access_code.failed_to_set_on_device":
      console.log("PIN failed:", data.access_code_id);
      break;
    case "device.disconnected":
      console.log("Lock offline:", data.device_id);
      break;
  }
  res.json({ received: true });
});
```

## 7. Make functions async

Make service functions async and update callers to await them.

If something goes wrong, read `references/troubleshooting.md`. For production readiness, read `references/production-checklist.md`.
