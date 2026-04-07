# Seam Integration Skills

Three focused AI skills for integrating [Seam](https://seam.co) smart lock access code automation into any application.

## Skills

| Skill | Use case | Description |
|-------|----------|-------------|
| **seam-reservation-automations** | PMS, vacation rentals | Push reservation data, Seam handles access codes automatically |
| **seam-access-grants** | Hotels, gyms, offices | Per-door credential control — PIN codes, mobile keys, Instant Keys |
| **seam-access-codes** | Coworking, custom access | Direct manual control over individual access codes |

Each skill guides the AI through exploring the codebase, finding the right integration points, and writing the actual code. Works across TypeScript, Python, Ruby, PHP, and Next.js.

## Install

### Claude Code (recommended — includes Seam docs MCP server)

```bash
# Add the marketplace
/plugin marketplace add seamapi/seam-integration-skill

# Install the plugin
/plugin install seam-integration@seamapi
```

This installs all three skills plus the Seam docs MCP server for real-time API documentation.

### Other AI tools (Cursor, Codex, Copilot, Gemini CLI, etc.)

```bash
# Via skills.sh
npx skills add seamapi/seam-integration-skill

# Or clone directly
git clone https://github.com/seamapi/seam-integration-skill.git
```

## Usage

Describe your integration needs and the right skill activates automatically:

> "We have reservations and want Seam to handle access codes automatically"
> → **seam-reservation-automations**

> "We want to give each hotel guest a PIN code for their specific room"
> → **seam-access-grants**

> "We manage our own member access and just need to create/delete codes on locks"
> → **seam-access-codes**

## Eval system

Each skill is tested against 5 synthetic fixture apps across different languages and business domains:

| API Path | Fixtures | Combined Score |
|----------|----------|---------------|
| **Reservation Automations** | express-ts, flask-py, nextjs-ts, rails-rb, php-laravel | 94-99 |
| **Access Grants** | hotel-express-ts, hotel-flask-py, hotel-nextjs-ts, hotel-rails-rb, hotel-php-laravel | 95-98 |
| **Lower-level API** | cowork-express-ts, cowork-flask-py, cowork-nextjs-ts, cowork-rails-rb, cowork-php-laravel | 95-98 |

### Running evals

```bash
# Rubric only (fast, no API key needed)
bash evals/run_evals.sh --fixtures express-ts --layers rubric

# Full pipeline with sandbox validation
SEAM_API_KEY=<sandbox_key> bash evals/run_evals.sh --layers both

# Specific API path
SEAM_API_KEY=<key> bash evals/run_evals.sh --api-path access_grants --runs 1
```

**Requirements:** Docker, Python 3, Claude CLI, Seam sandbox API key (for Layer 2)

## Docs

- [Design spec](docs/2026-03-23-quantitative-evals-design.md) — eval system architecture
- [Implementation plan](docs/2026-03-23-quantitative-evals-plan.md) — eval build plan
- [Original design](docs/design.md) — skill design document

## Links

- [Seam docs](https://docs.seam.co)
- [Seam Console](https://console.seam.co)
- [Seam MCP server](https://mcp.seam.co/mcp) — docs search for AI assistants
- [Agent Skills spec](https://agentskills.io/specification) — the open standard these skills follow
