# Payload blueprint

For a Payload 3 app (on Next.js) with pnpm. Two files: `.relay/blueprint.yaml` tells Relay how to install, test, lint and build the project, and `AGENTS.md` tells the agent how the project is written.

## Use it

From your project's root:

```bash
curl -fsSL https://raw.githubusercontent.com/Relay-harness/relay/main/blueprints/payload/.relay/blueprint.yaml --create-dirs -o .relay/blueprint.yaml
curl -fsSL https://raw.githubusercontent.com/Relay-harness/relay/main/blueprints/payload/AGENTS.md -o AGENTS.md
relay blueprint verify
```

If the project already has an `AGENTS.md`, add this one's lines to it instead of replacing it.

`relay blueprint verify` runs every command in a clean checkout of your base branch and says which pass. When they all do, `relay blueprint commit` commits the file on its own. From then on, a task is done only when every check passes.

## What Relay runs

- `pnpm install --frozen-lockfile`
- `pnpm generate:types` and `pnpm generate:importmap` before every attempt
- `pnpm test:int`
- `pnpm exec tsc --noEmit`
- `pnpm build`

## Checked on

`create-payload-app` with the blank template and SQLite (Payload 3.91.0, Next.js 16.3.3), Node 22. Every command above passed under `relay blueprint verify` (Relay 0.6.118) on 17 October 2026.

## Adjust it

- Relay needs `PAYLOAD_SECRET` and `DATABASE_URI` in its environment, as your own shell has them. The blueprint names them; their values never go in the file.
- `pnpm lint` is not a check yet: the blank template's ESLint config (FlatCompat over eslint-config-next 16) does not load as created, so it fails on a fresh project. Once your config loads, add `pnpm lint` under `lint`.
- `pnpm test:e2e` (Playwright) is listed under `browser_tests`: recorded, not run. Put it under `test` too to make it a check.
- On Postgres or MongoDB, uncomment the `services` entry and name the database service from your compose file. Relay starts it for the tests and stops it after; this needs Docker.
