# Installed skills

## Replica (app/website clone)

Eleven Claude skills that reverse-engineer an existing app or website and
rebuild it clean-room style (behavior and flows, never the original's code,
logo, copy or content).

- **Source:** https://github.com/Jakeschincariol/replica-skill
- **License:** MIT (see `LICENSE`)
- **Installed:** 2026-11-08

These are project-local skills. In a Claude Code session on this repo they are
available as `/replica-recon`, `/replica-architect`, `/replica-build`, and so
on. Start with `/replica-recon` to map the target app.

| command | what it does |
| --- | --- |
| `/replica-recon` | Reverse-engineers any app: screens, flows, components, data model. |
| `/replica-architect` | Plans the stack, database schema and API for your clone. |
| `/replica-design` | Rebuilds the design system: colours, type, spacing, components. |
| `/replica-build` | Rebuilds the app screen by screen from the recon map. |
| `/replica-backend` | Auth, database, payments and integrations. |
| `/replica-test` | Tests the clone for bugs. |
| `/replica-diff` | Scores the clone against the original for parity. |
| `/replica-entrepreneur` | Reads what the app's users dislike and improves on it. |
| `/replica-brand` | Gives the clone its own name and brand. |
| `/replica-launch` | Writes the landing page and store listing. |
| `/replica-deploy` | Puts it live, with a pre-flight check. |

The Python helpers need Python 3.8+ and have no pip dependencies.
