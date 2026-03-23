# Design: Seam PMS Integration Skill

## Context

PMS (property management system) companies are one of Seam's most common integration partners. They need to automate access codes, credentials, and climate settings around guest reservations. Today, the developer journey requires reading through 600+ docs pages to understand which API path to take and how to wire everything together.

We want to build an AI-powered integration skill that acts as an expert Seam consultant inside the developer's editor — guiding PMS developers step-by-step from zero to a production integration, with verification at every step.

This complements the existing Seam docs MCP server (which provides documentation search) by adding guided workflow orchestration on top.

## Audience

Developers at PMS companies (e.g., Guesty, Hostaway, Lodgify, or custom PMS platforms) who are building Seam into their product to automate access for guest reservations.

## Skill Format

The skill is a **SKILL.md** file following the [skills.sh specification](https://agentskills.io/specification):

- Markdown file with YAML frontmatter (`name`, `description`, `version`)
- Body contains structured instructions for the AI assistant
- Not executable code — it's a prompt document that teaches the AI how to guide the developer
- Under 500 lines, using progressive disclosure (name/description loaded first, full content on activation)

The skill is instruction-based: it tells the AI assistant what to ask, what to recommend, and how to verify each step. It cannot programmatically enforce gates — instead, verification steps are instructions like "ask the user to run `seam devices list` and confirm devices appear before proceeding."

## Skill Content

The skill acts as a guided integration consultant. When invoked (e.g., `/seam-integration`), it walks the developer through the full integration.

### Step 1: Understand Their Integration

- What does your PMS do? (short-term rentals, hotels, coworking, etc.)
- What's your tech stack / language? (Node.js, Python, Ruby, PHP, etc.)
- What devices are you working with? (smart locks, thermostats, ACS, etc.)
- Do you need full credential lifecycle control, or just push reservation data and let Seam handle the rest?

Based on answers, recommend one of three API paths:

| Path | When to use | Example | Complexity |
|------|------------|---------|------------|
| **Reservation Automations** (`push_data`) | You just want to send check-in/check-out times and guest info and let Seam handle access + climate automatically | "Our PMS has reservation data and we want codes created automatically at check-in" | Lowest |
| **Access Grants** | You need per-entrance control over credentials, support for multiple access methods (PIN, mobile key, card), or reservation override/joiner behavior | "We need to issue mobile keys and PIN codes for specific doors, and handle multi-guest scenarios" | Medium |
| **Lower-level API** (direct `access_codes.create`, etc.) | You need full manual control over individual API resources, or your use case doesn't fit the reservation model | "We manage our own credential lifecycle and just need Seam for device communication" | Highest |

The skill should tailor all code examples to the developer's chosen language from this point forward.

### Step 2: Set Up Seam (Sandbox First)

1. Create Seam account at console.seam.co
2. Use the default **sandbox workspace** to explore the API safely
3. Get API key from Developer > API Keys
4. Connect sandbox device (August lock: `jane@example.com` / `1234`)
5. **Verify:** Ask the developer to run `seam devices list` (CLI) or equivalent SDK/API call. Confirm devices appear before proceeding.

### Step 3: Build the Integration (path-dependent)

#### If Reservation Automations:
1. Enable automations in Console > Developer > Automations
2. Set up customers, spaces, and device assignments
3. Push reservation data via `POST /customers/push_data`
4. **Verify:** Ask the developer to check Console — does the access code appear on the device?

#### If Access Grants:
1. Create user identity for the guest
2. Identify entrances (or spaces) to grant access to
3. Create access grant with requested access methods (PIN code, mobile key, etc.)
4. **Verify:** Ask the developer to check access method status via API/CLI. Is the credential set?

#### If Lower-level API:
1. Create access code with time bounds matching reservation
2. Set up webhook listener for `access_code.set_on_device` events
3. **Verify:** Ask the developer to run `seam access-codes list`. Is the code set on the device?

### Step 4: Handle the Full Lifecycle (path-dependent)

#### If Reservation Automations:
- Reservation modified → push updated data with same `reservation_key`
- Reservation cancelled → call `delete_data` to roll back
- **Verify:** Confirm access is revoked after deletion

#### If Access Grants:
- Reservation modified → update access grant (change `starts_at`/`ends_at`, add/remove entrances)
- Reservation cancelled → delete access grant
- Multi-guest check-in → create additional access grants with same `reservation_key` (joiner behavior)
- **Verify:** Confirm credentials are updated/revoked

#### If Lower-level API:
- Reservation modified → update access code time bounds
- Reservation cancelled → delete access code
- Handle conflicts (code slot limits, overlapping reservations)
- **Verify:** Confirm code is removed from device

### Step 5: Go to Production

1. Create a production workspace in Console
2. Get production API key
3. Connect real devices via Connect Webview
4. Re-run the integration against real devices
5. **Verify:** End-to-end test — create a reservation, confirm code appears on real lock, cancel reservation, confirm code is removed

### Step 6: Production Hardening

- Error handling: device offline, code slot limits, concurrent guests
- Webhook setup for real-time status notifications (don't poll)
- Connect Webview integration for end-user (property manager) device onboarding
- Monitoring: watch for `device.disconnected` and `access_code.failed_to_set_on_device` events

### Error Handling

If verification fails at any step, the skill should:
1. Ask the developer what error or unexpected result they're seeing
2. Use the MCP `search_docs` tool to find relevant troubleshooting docs
3. Guide through common fixes (wrong API key, device not connected, etc.)
4. If the developer realizes they chose the wrong API path, offer to restart from Step 1

If the developer's lock brand is not supported by Seam, direct them to the [supported devices page](https://docs.seam.co/latest/device-guides/) and suggest contacting support@seam.co.

### Verification Philosophy

Every step includes a verification checkpoint. The skill instructs the AI to:
1. Tell the developer what command to run or what to check
2. Ask them to confirm the result
3. Only proceed to the next step after confirmation

Verification options (developer's choice):
- `seam` CLI commands (simplest for quick checks)
- SDK/API calls in their language
- Console UI (visual confirmation)

## MCP Integration

The skill works alongside the existing Seam docs MCP server (`https://mcp.seam.co/mcp`). The skill includes instructions like:

- "If the developer asks about a specific API endpoint, use `search_docs` to find the relevant documentation"
- "When showing code examples, use `get_doc` to fetch the latest examples from the docs"
- "If unsure which devices support a feature, use `search_docs` to check device compatibility"

**If the MCP is not installed:** The skill degrades gracefully — instead of MCP tool calls, it references docs URLs directly (e.g., "See https://docs.seam.co/latest/capability-guides/access-grants/"). The skill should recommend installing the MCP for a better experience but should not require it.

## Distribution

The core content is a single SKILL.md file. It gets packaged for multiple channels:

### Phase 1: Core (ship first)

| Channel | Format | Install method |
|---------|--------|---------------|
| **skills.sh** | SKILL.md in public repo | `npx skills add seamapi/seam-integration-skill` |
| **GitHub** | Same repo, tagged releases | Clone or download |

### Phase 2: Marketplaces (tentative — packaging formats may evolve)

| Channel | Format | Install method |
|---------|--------|---------------|
| **Claude Code Plugin Directory** | `.claude-plugin/` with `plugin.json` | Browse and install from Claude Code UI |
| **Cursor Marketplace** | Cursor plugin package | Browse and install from Cursor marketplace |

Note: Phase 2 packaging formats depend on marketplace requirements at time of submission. The SKILL.md content is the source of truth; marketplace packaging wraps it.

### Phase 3: Complementary

| Channel | Action |
|---------|--------|
| **MCP Registries** (Smithery, Glama) | List the docs MCP server (already built) |
| **Docs page** | Update seam-mcp docs page to link to the skill |

### Repository Structure

```
seamapi/seam-integration-skill/
  SKILL.md                    # Core skill content (skills.sh compatible)
  .claude-plugin/
    plugin.json               # Claude Code plugin metadata (Phase 2)
  README.md                   # Install instructions for all channels
```

All channels point to the same core SKILL.md. Updates to the file propagate everywhere.

### Maintenance

The SKILL.md references Seam API patterns and docs structure. When Seam's API changes:
- The MCP server automatically picks up docs changes (embeddings rebuild on docs repo push)
- The SKILL.md only needs updating if the high-level integration patterns or API paths change (rare)
- The skill avoids hardcoding specific API details — it delegates to the MCP for current reference material

## Key Docs References

These existing docs pages contain the API details the skill will reference:

- Reservation Automations: `capability-guides/reservation-automations.md`
- Access Grants overview: `capability-guides/access-grants/README.md`
- Access Grant Quick Start: `capability-guides/access-grants/access-grant-quick-start.md`
- Reservation Access Grants: `capability-guides/access-grants/reservation-access-grants.md`
- Access Codes: `products/smart-locks/access-codes/README.md`
- Connect Webviews: `core-concepts/connect-webviews/README.md`
- Seam CLI: `developer-tools/seam-cli.md`
- Go Live: `go-live.md`

## Success Criteria

- A PMS developer can go from "I want to integrate Seam" to a working sandbox demo in under 2 hours using the Reservation Automations path
- Every step has a verification checkpoint — no "trust me, it worked"
- The skill correctly routes developers to the right API path based on their needs
- The skill is discoverable on skills.sh and at least one marketplace (Claude Code or Cursor)

## Out of Scope (for now)

- Skills for non-PMS use cases (ACS, thermostats, etc.) — future work, same pattern
- Single property manager audience — different skill, different effort
- VS Code extensions — skill marketplaces (skills.sh, Claude Code, Cursor) are the priority
- Bundling the Seam API into an MCP server — AI assistants can use SDK/CLI/curl directly
- Changes to the existing seam-mcp server — this is a new repo (`seamapi/seam-integration-skill`)
