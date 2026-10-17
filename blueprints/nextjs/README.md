# Next.js blueprint

For a Next.js app on the App Router, TypeScript and npm. Two files: `.relay/blueprint.yaml` tells Relay how to install, test, lint and build the project, and `AGENTS.md` tells the agent how the project is written.

## Use it

From your project's root:

```bash
curl -fsSL https://raw.githubusercontent.com/Relay-harness/relay/main/blueprints/nextjs/.relay/blueprint.yaml --create-dirs -o .relay/blueprint.yaml
curl -fsSL https://raw.githubusercontent.com/Relay-harness/relay/main/blueprints/nextjs/AGENTS.md -o AGENTS.md
relay blueprint verify
```

If the project already has an `AGENTS.md`, add this one's lines to it instead of replacing it.

`relay blueprint verify` runs every command in a clean checkout of your base branch and says which pass. When they all do, `relay blueprint commit` commits the file on its own. From then on, a task is done only when every check passes.

## What Relay runs

- `npm ci`
- `npm run lint`
- `npm run build`

## Checked on

`create-next-app` with TypeScript, ESLint, the App Router and `src/` (Next.js 16.4.2), Node 22. Every command above passed under `relay blueprint verify` (Relay 0.6.118) on 17 October 2026.

## Adjust it

- The starter has no test script, so `test` is empty. Add yours (`npm test`, `npx vitest run`, `npx playwright test`) as soon as the project has one.
- On pnpm, yarn or bun, change `package_manager` and the commands to match: `pnpm install --frozen-lockfile`, `pnpm lint`, `pnpm build`.
