# Working in this Next.js app

- App Router. Routes live in `src/app` (or `app`); a folder is a route segment, `page.tsx` renders it, `layout.tsx` wraps it.
- Components are Server Components unless they need state, effects or browser APIs. Add `"use client"` only to the file that needs it, as low in the tree as it can go.
- Fetch data in Server Components or route handlers (`app/api/**/route.ts`), not in client effects.
- Environment variables: only `NEXT_PUBLIC_*` reach the browser. Never put a secret in a `NEXT_PUBLIC_` name, and never commit `.env*`.
- TypeScript is strict. Do not silence an error with `any`, `@ts-ignore` or `as unknown as`; fix the type.
- Before calling a task done, run `npm run lint` and `npm run build`. `next build` is the type check; it must pass.
- Do not edit `.next/`, `node_modules/` or lockfiles by hand. Add dependencies with `npm install <name>`.
- Keep changes to what the task asks. Do not reformat files you did not otherwise change.
