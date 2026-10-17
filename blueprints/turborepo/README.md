# Turborepo blueprint

For a Turborepo monorepo on pnpm workspaces. Two files: `.relay/blueprint.yaml` tells Relay how to install, test, lint and build the project, and `AGENTS.md` tells the agent how the project is written.

## Use it

From your project's root:

```bash
curl -fsSL https://raw.githubusercontent.com/Relay-harness/relay/main/blueprints/turborepo/.relay/blueprint.yaml --create-dirs -o .relay/blueprint.yaml
curl -fsSL https://raw.githubusercontent.com/Relay-harness/relay/main/blueprints/turborepo/AGENTS.md -o AGENTS.md
relay blueprint verify
```

If the project already has an `AGENTS.md`, add this one's lines to it instead of replacing it.

`relay blueprint verify` runs every command in a clean checkout of your base branch and says which pass. When they all do, `relay blueprint commit` commits the file on its own. From then on, a task is done only when every check passes.

## What Relay runs

- `pnpm install --frozen-lockfile`
- `pnpm turbo run lint`
- `pnpm turbo run check-types`
- `pnpm turbo run build`

## Checked on

`create-turbo` with pnpm (Turborepo 2.10.12, two Next.js apps and shared packages), Node 24. Every command above passed under `relay blueprint verify` (Relay 0.6.118) on 17 October 2026.

## Adjust it

- Turbo runs each task in every workspace that defines it, so these commands check the whole repo. A workspace without a `lint` or `check-types` script is skipped, not failed.
- The starter has no test task. Add one to `turbo.json`, give each workspace a `test` script, and list `pnpm turbo run test` under `test`.
- The template asks for Node 24 or newer and pnpm 11. On an older Node, change `runtime` to match your `.nvmrc` or `engines`.
