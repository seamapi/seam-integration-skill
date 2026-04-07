# Production Checklist

## Before going live

1. **Create production workspace** in Seam Console
2. **Get production API key** and add to production environment variables
3. **Set up device onboarding** — Customer Portal for property managers, or Connect Webviews for custom UI
4. **Register webhook URL** in Console → Developer → Webhooks
5. **Test end-to-end** with a real device: create reservation → verify code on lock → cancel → verify code removed

## Production hardening

- **Code slot limits** — some locks have a max number of codes. Check `device.properties.max_active_codes_supported` and handle gracefully.
- **Unique emails** — each guest must have a unique email. If guests don't have unique emails, use a synthetic email like `guest_{id}@yourplatform.internal`.
- **Error monitoring** — watch for `access_code.failed_to_set_on_device` webhooks and alert your ops team.
- **Guest notifications** — only send the door code to the guest AFTER receiving the `access_code.set_on_device` webhook. Don't send immediately after creation — it may not be on the lock yet.
- **Device disconnection** — monitor `device.disconnected` events and alert property managers.

## Setup (if not already done)

1. Create account at https://console.seam.co/ (sandbox by default)
2. Get API key from Developer > API Keys
3. Add to environment variables (`.env` or config)
4. Connect sandbox device: Add Devices → August → `jane@example.com` / `1234` → 2FA: `123456`
