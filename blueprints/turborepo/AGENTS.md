# Working in this Turborepo

- Apps live in `apps/`, shared packages in `packages/`. A package is imported by its `name` in its `package.json` (`@repo/ui`), never by a relative path across the repo.
- Tasks are defined in `turbo.json` and run with `pnpm turbo run <task>`. A new script that should run everywhere gets a task in `turbo.json` with its `dependsOn` and `outputs`.
- Add a dependency to the workspace that uses it: `pnpm add <name> --filter <workspace>`. Shared versions go in the package that owns them, not the root.
- A change to a shared package can break every app that uses it. Run the checks for the whole repo, not just the app you touched.
- Before calling a task done, run `pnpm turbo run lint`, `pnpm turbo run check-types` and `pnpm turbo run build`. All must pass.
- Do not edit `.turbo/`, `node_modules/`, build outputs or `pnpm-lock.yaml` by hand.
