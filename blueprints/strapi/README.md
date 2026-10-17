# Strapi blueprint

For a Strapi 5 app in TypeScript with npm. Two files: `.relay/blueprint.yaml` tells Relay how to install, test, lint and build the project, and `AGENTS.md` tells the agent how the project is written.

## Use it

From your project's root:

```bash
curl -fsSL https://raw.githubusercontent.com/Relay-harness/relay/main/blueprints/strapi/.relay/blueprint.yaml --create-dirs -o .relay/blueprint.yaml
curl -fsSL https://raw.githubusercontent.com/Relay-harness/relay/main/blueprints/strapi/AGENTS.md -o AGENTS.md
relay blueprint verify
```

If the project already has an `AGENTS.md`, add this one's lines to it instead of replacing it.

`relay blueprint verify` runs every command in a clean checkout of your base branch and says which pass. When they all do, `relay blueprint commit` commits the file on its own. From then on, a task is done only when every check passes.

## What Relay runs

- `npm ci`
- `npx tsc --noEmit`
- `npm run build`

## Checked on

`create-strapi` with TypeScript and SQLite (Strapi 5.58.0), Node 22. Every command above passed under `relay blueprint verify` (Relay 0.6.118) on 17 October 2026.

## Adjust it

- Relay needs Strapi's secrets in its environment (`APP_KEYS`, `API_TOKEN_SALT`, `ADMIN_JWT_SECRET`, `TRANSFER_TOKEN_SALT`, `JWT_SECRET`), as your own shell has them. The blueprint names them; their values never go in the file.
- A new Strapi project has no tests, so `test` is empty. Add yours (for example Jest with Supertest) under `test` when you write them.
