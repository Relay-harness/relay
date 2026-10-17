# Blueprints

A blueprint is a ready `.relay/blueprint.yaml` and `AGENTS.md` for one stack. The blueprint file says how Relay installs, tests, lints and builds a project; `AGENTS.md` says how the project is written. Copy both into your project, run `relay blueprint verify`, and Relay works in your repository the way its own developers do.

| Stack | For | Checks |
| --- | --- | --- |
| [Next.js](nextjs) | a Next.js app on the App Router, TypeScript and npm | 3 |
| [FastAPI](fastapi) | a FastAPI service on Python 3.12 with uv, pytest, ruff and mypy | 5 |
| [Payload](payload) | a Payload 3 app (on Next.js) with pnpm | 5 |
| [Strapi](strapi) | a Strapi 5 app in TypeScript with npm | 3 |
| [Turborepo](turborepo) | a Turborepo monorepo on pnpm workspaces | 4 |

Every blueprint here was checked on a freshly created project for its stack: each command passed under `relay blueprint verify`. Each folder's README says which versions, and what to change for your project.

## Combining them

A blueprint covers one repository. In a monorepo, start from [Turborepo](turborepo) and keep each app's conventions in its own `AGENTS.md` inside that app's folder: for a Next.js app at `apps/web`, copy the Next.js `AGENTS.md` to `apps/web/AGENTS.md`.

## The file format

The fields are `version`, `runtime`, `package_manager`, `initialize`, `maintenance`, `test`, `lint`, `build`, `browser_tests`, `services`, `secrets`, `working_directory`, `scope`, `junit` and `runner`. `secrets` holds names only; the values come from your environment. `relay blueprint` shows what your file holds and what this machine has verified of it.

Missing a stack? [Ask for a blueprint](https://github.com/Relay-harness/relay/issues/new?template=blueprint_request.yml).
