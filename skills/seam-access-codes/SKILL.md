---
name: seam-access-codes
description: >-
  Integrate Seam's lower-level Access Codes API for direct, manual control over smart lock access codes.
  Create, update, and delete individual time-bound access codes on specific devices. Use this skill when
  someone manages their own credential lifecycle and just needs Seam for device communication, wants full
  control over individual access codes, or their use case doesn't fit the reservation model.
  Common use cases: coworking room booking, gym access, office visitor codes, custom access management.
  Works with August, Yale, Schlage, Kwikset, and other smart locks.
version: 0.5.0
---

# Seam Access Codes (Lower-level API)

You are an expert Seam integration engineer. Write the integration code directly into the developer's existing codebase.

## Approach

1. **Move fast.** Glob for key files (booking/reservation handlers, routes, models), read them, start writing code.
2. **Write code in existing files.** Add Seam calls directly into existing service/handler functions. Don't create wrapper services.
3. **Minimize changes.** Only touch files that need Seam calls + webhook route. Install SDK, add import, add calls.

## How Access Codes works

You create time-bound access codes directly on specific devices. Each code has a `starts_at` and `ends_at` window. You must store the `access_code_id` to update or delete it later. Seam programs the code onto the lock and removes it when it expires or you delete it.

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

Access Codes targets a specific device by `device_id`. **Each room/door must map to its own device ID** — never use a single global device for all rooms.

Look for device IDs in:
- Environment variables per room: `SEAM_DEVICE_ROOM_A1`, `SEAM_DEVICE_ID_ROOM_101`, etc.
- The app's data model (e.g., `room.seamDeviceId`, `unit.deviceId`)

**If the mapping is missing, fail the operation** — do not fall back to a global device.

## 3. Create access code on booking creation

Add directly inside the create function. **Store the `access_code_id` on the booking object.**

```typescript
// Inside createBooking(), after saving the booking:
const deviceId = getDeviceIdForRoom(room);  // Must resolve per-room
if (!deviceId) {
  throw new Error(`No Seam device configured for room ${room.id}`);
}
try {
  const accessCode = await seam.accessCodes.create({
    device_id: deviceId,
    name: `${member.name} - ${room.name}`,
    starts_at: booking.startTime,
    ends_at: booking.endTime
  });
  booking.seamAccessCodeId = accessCode.access_code_id;
  booking.accessCode = accessCode.code;  // The actual PIN
} catch (err) {
  console.error("Seam access code creation failed:", err);
  // Consider: should this fail the booking? If access is required, throw.
}
```

```python
# Inside create_booking(), after saving:
device_id = get_device_id_for_room(room)  # Must resolve per-room
if not device_id:
    raise ValueError(f"No Seam device configured for room {room.id}")
try:
    access_code = seam.access_codes.create(
        device_id=device_id,
        name=f"{member.name} - {room.name}",
        starts_at=booking.start_time,
        ends_at=booking.end_time
    )
    booking.seam_access_code_id = access_code.access_code_id
    booking.access_code = access_code.code
except Exception as e:
    print(f"Seam access code failed: {e}")
    # Consider: should this fail the booking? If access is required, raise.
```

## Gotchas

- **Store `access_code_id`** — you need it for update and delete. Add a field to the booking model if one doesn't exist. If it's `null`/`undefined`, the code failed and needs retry.
- **Never use a global device fallback** — each room must map to its specific device.
- **`device_id`** is a single string (one device per code), not an array.
- **Don't hardcode the `code`** value unless you need a specific PIN — Seam generates a random code by default.
- **`name`** is optional but recommended — it appears in the Seam Console for identification.
- **Code slot limits** — some locks have a max number of codes. Check `device.properties.max_active_codes_supported`.
- **Decide your failure mode**: if the room booking requires access (e.g., locked meeting room), throw on Seam failure. If access is optional, log and continue.

## 4. Update access code on booking changes

```typescript
if (booking.seamAccessCodeId) {
  await seam.accessCodes.update({
    access_code_id: booking.seamAccessCodeId,
    starts_at: booking.startTime,
    ends_at: booking.endTime
  });
}
```

```python
if booking.seam_access_code_id:
    seam.access_codes.update(
        access_code_id=booking.seam_access_code_id,
        starts_at=booking.start_time,
        ends_at=booking.end_time
    )
```

## 5. Delete access code on cancellation

```typescript
if (booking.seamAccessCodeId) {
  await seam.accessCodes.delete({
    access_code_id: booking.seamAccessCodeId
  });
}
```

```python
if booking.seam_access_code_id:
    seam.access_codes.delete(
        access_code_id=booking.seam_access_code_id
    )
```

## 6. Add webhook endpoint

Follow the existing webhook pattern in the codebase:

```typescript
router.post("/seam", (req, res) => {
  const { event_type, ...data } = req.body;
  switch (event_type) {
    case "access_code.set_on_device":
      // Code is on the lock — safe to share with the user
      console.log("Code set:", data.access_code_id);
      break;
    case "access_code.failed_to_set_on_device":
      console.log("Code failed:", data.access_code_id);
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
