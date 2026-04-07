# Troubleshooting

## push_data returns OK but no access code appears

1. **Space must exist** with a matching `space_key` and have a device assigned (`device_count` > 0). Create via `/spaces/create` or use Customer Portal.
2. **Guest email must be unique** — duplicates cause silent `user_identity_email_or_phone_conflict`. The API returns `ok: true` but no code is created.
3. **Check Console → Automation Runs** for detailed error messages.
4. **Wait 10-30 seconds** — automations are async.

## Access code status stays "unset"

The code is scheduled but not yet programmed on the lock. This is normal for future-dated codes. The lock will accept the code when `starts_at` arrives.

## access_code.failed_to_set_on_device

The lock rejected the code. Common causes:
- Lock is offline or disconnected
- Code slot limit reached — check `device.properties.max_active_codes_supported`
- Battery too low on the lock

## Access code not removed after delete_data

Revocation is async — the lock needs time to clear the code. Status goes through `removing` before `removed`. Can take 5-60 seconds.

## "Invalid API key"

Check that the environment variable matches the workspace (sandbox vs production). Sandbox keys start with `seam_test`, production keys start with `seam_`.

## "Device not found"

Verify the device is connected to Seam and you're using the correct workspace. Check with `seam.devices.list()`.
