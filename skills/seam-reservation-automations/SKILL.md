---
name: seam-reservation-automations
description: >-
  Integrate Seam Reservation Automations into a property management system (PMS) or vacation rental platform.
  Push reservation data (check-in, check-out, guest info) and Seam automatically creates and revokes
  access codes on smart locks. Supports August, Yale, Schlage, Kwikset, and other smart locks.
  Use this skill when someone wants to automate access codes from reservations, let Seam handle
  credential management, or integrate a PMS with smart locks without building device management UI.
  Not for hotel ACS systems (Salto, Visionline, Brivo) — those need a different approach.
version: 0.5.0
---

# Seam Reservation Automations

You are an expert Seam integration engineer. Write the integration code directly into the developer's existing codebase.

## Approach

1. **Move fast.** Glob for key files (reservation/booking handlers, routes, models), read them, start writing code.
2. **Write code in existing files.** Add Seam calls directly into existing service/handler functions. Don't create wrapper services.
3. **Minimize changes.** Only touch files that need Seam calls + webhook route. Install SDK, add import, add calls.

## How Reservation Automations works

The PMS pushes reservation data to Seam via `push_data`. Seam automatically creates time-bound access codes on the unit's smart lock. When the reservation is cancelled, `delete_data` revokes the codes.

The PMS does NOT need to manage individual access codes, devices, or credentials.

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

For Express / standard Node.js, module-scope is fine:

```typescript
import { Seam } from "seam";
const seam = new Seam({ apiKey: process.env.SEAM_API_KEY });
```

```python
from seam import Seam
seam = Seam(api_key=os.environ["SEAM_API_KEY"])
```

## 2. Add push_data to reservation creation

Add directly inside the create function — not in a helper:

```typescript
await seam.customers.pushData({
  customer_key: property.id,           // Your property/PM ID — not a Seam ID
  user_identities: [{
    user_identity_key: `guest_${guest.id}`,
    name: guest.name,
    email_address: guest.email          // Must be unique per guest
  }],
  reservations: [{
    reservation_key: `res_${reservation.id}`,
    user_identity_key: `guest_${guest.id}`,
    starts_at: reservation.checkIn,
    ends_at: reservation.checkOut,
    space_keys: [unit.id]               // Unit ID = space key
  }]
});
```

```python
seam.customers.push_data(
    customer_key=property.id,
    user_identities=[{
        "user_identity_key": f"guest_{guest.id}",
        "name": guest.name,
        "email_address": guest.email
    }],
    reservations=[{
        "reservation_key": f"res_{reservation.id}",
        "user_identity_key": f"guest_{guest.id}",
        "starts_at": reservation.check_in,
        "ends_at": reservation.check_out,
        "space_keys": [unit.id]
    }]
)
```

## Gotchas

- `customer_key` — use an existing ID from your data model (property ID, PM ID). NOT a Seam-generated ID.
- `space_keys` — must match the space_key used when the space was created in Seam (typically the unit/room ID).
- `email_address` — must be unique per guest. Duplicates cause silent failures (`ok: true` but no code created).
- `delete_data` uses `customer_keys` (plural list), NOT `customer_key` (singular). Different from `push_data`.
- Wrap all Seam calls in try/catch — Seam errors shouldn't break the reservation flow.

## 3. Add push_data to reservation updates

Same call in the update handler with the same `reservation_key` — Seam detects it's an update:

```typescript
await seam.customers.pushData({
  customer_key: property.id,
  reservations: [{
    reservation_key: `res_${reservation.id}`,
    user_identity_key: `guest_${reservation.guestId}`,
    starts_at: reservation.checkIn,
    ends_at: reservation.checkOut,
    space_keys: [reservation.unitId]
  }]
});
```

## 4. Add delete_data to cancellations

```typescript
await seam.customers.deleteData({
  customer_keys: [property.id],
  reservation_keys: [`res_${reservation.id}`],
  user_identity_keys: [`guest_${reservation.guestId}`]
});
```

```python
seam.customers.delete_data(
    customer_keys=[property.id],
    reservation_keys=[f"res_{reservation.id}"],
    user_identity_keys=[f"guest_{reservation.guest_id}"]
)
```

## 5. Add webhook endpoint

Find existing webhook handlers and add a Seam endpoint following the same pattern:

```typescript
router.post("/seam", (req, res) => {
  const { event_type, ...data } = req.body;
  switch (event_type) {
    case "access_code.set_on_device":
      console.log("Access code set:", data.access_code_id);
      break;
    case "access_code.failed_to_set_on_device":
      console.log("Access code failed:", data.access_code_id);
      break;
    case "device.disconnected":
      console.log("Device disconnected:", data.device_id);
      break;
  }
  res.json({ received: true });
});
```

## 6. Make functions async

Make service functions async and update callers to await them.

If something goes wrong, read `references/troubleshooting.md`. For production readiness, read `references/production-checklist.md`.
