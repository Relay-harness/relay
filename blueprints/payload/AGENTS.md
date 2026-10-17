# Working in this Payload app

- Payload 3 runs inside Next.js. The config is `src/payload.config.ts`; collections live in `src/collections`, globals beside them.
- A schema change is a change to a collection or global config. After one, run `pnpm generate:types` so `src/payload-types.ts` matches, and `pnpm generate:importmap` when you add or move admin components. Commit what they generate.
- Use the generated types (`import type { Post } from '@/payload-types'`), not hand-written copies.
- Access control belongs in each collection's `access` functions, not in route handlers. Default to the most restrictive access that the task allows.
- On Postgres or SQLite, a schema change that will reach production needs a migration: `pnpm payload migrate:create`, and commit the file.
- Secrets (`PAYLOAD_SECRET`, `DATABASE_URI`) come from the environment. Never commit `.env`.
- Before calling a task done, run `pnpm test:int`, `pnpm exec tsc --noEmit` and `pnpm build`. All must pass.
- Do not edit `node_modules/`, `.next/` or the lockfile by hand. Add dependencies with `pnpm add <name>`.
