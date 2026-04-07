# Seam PMS Integration Skill

## Project overview

An AI skill that guides developers through integrating Seam smart lock access code automation into their property management system (PMS). Includes a quantitative eval system that tests the skill against synthetic fixture apps across 5 languages/frameworks.

## Key files

- `skills/seam-reservation-automations/SKILL.md` — Reservation Automations skill (PMS, vacation rentals)
- `skills/seam-access-grants/SKILL.md` — Access Grants skill (hotels, gyms, offices)
- `skills/seam-access-codes/SKILL.md` — Access Codes skill (coworking, custom access)
- `skills/*/references/` — shared troubleshooting and production checklist (loaded on demand)
- `.claude-plugin/plugin.json` — Claude Code plugin manifest. Bundles all 3 skills + Seam MCP docs server.
- Root `SKILL.md` is a symlink to seam-reservation-automations (backwards compat for non-plugin consumers).
- `evals/run_evals.sh` — eval orchestrator. Invokes the skill against fixtures, runs rubric + sandbox scoring.
- `evals/rubric_checker.py` — Layer 1: structural scoring (0-100) against answer keys.
- `evals/sandbox_validator.sh` — Layer 2: Docker build + Seam sandbox validation (0-100).
- `evals/fixtures/` — 5 fixture apps (express-ts, flask-py, nextjs-ts, rails-rb, php-laravel).

## Running evals

```bash
# Rubric only (no API key needed)
bash evals/run_evals.sh --fixtures express-ts --layers rubric --runs 1

# Full pipeline (requires Seam sandbox API key)
SEAM_API_KEY=<key> bash evals/run_evals.sh --fixtures express-ts,flask-py --layers both --runs 1

# All fixtures, 3 runs each
SEAM_API_KEY=<key> bash evals/run_evals.sh --runs 3
```

## Fixture apps

Each fixture is a minimal PMS app with reservation CRUD, an existing webhook handler, and no Seam integration. The skill's job is to add Seam SDK calls.

Fixture apps must have:
- `GET /health` returning `{"status":"ok"}`
- `POST /api/reservations` (create)
- `PUT /api/reservations/:id` (update)
- `DELETE /api/reservations/:id` (cancel)
- Response shape: `{"reservation":{"id":"...","status":"..."}}`
- Seed data: property "prop-1", units "unit-101" and "unit-202"

## Sandbox notes

- Evals use the Seam sandbox API (`connect.getseam.com`)
- The sandbox validator creates a space with key `unit-101` and assigns a device
- Orphaned access codes are auto-cleaned before each run
- Cancel validation tracks the specific access code created during the test
- Seam automation timing is variable (5-60s for code creation, 5-60s for revocation)

## Code conventions

- Eval infrastructure is Bash (orchestrator, validator) + Python (rubric checker)
- Fixture apps use their native language/framework conventions
- Rubric checker handles cross-language syntax: JS dot notation, PHP arrow (`->`), URL paths (`/customers/push_data`), camelCase/snake_case SDK methods
- The `_normalize_content()` function in rubric_checker.py converts PHP `->` to `.` for uniform matching
