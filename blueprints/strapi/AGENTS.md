# Working in this Strapi app

- Strapi 5, TypeScript. Content types live in `src/api/<name>/content-types/<name>/schema.json`; their controllers, routes and services sit beside them.
- Change a content type's schema through its `schema.json`, then let Strapi regenerate `types/generated` on the next build. Commit both.
- Customize behavior by extending the core controllers and services (`factories.createCoreController`), not by replacing them.
- Permissions are data, set in the admin panel or a bootstrap function in `src/index.ts`. Do not open a route to the public role unless the task asks for it.
- Secrets (`APP_KEYS`, `API_TOKEN_SALT`, `ADMIN_JWT_SECRET`, `TRANSFER_TOKEN_SALT`, `JWT_SECRET`) come from the environment. Never commit `.env`.
- Before calling a task done, run `npx tsc --noEmit` and `npm run build`. Both must pass.
- Do not edit `dist/`, `.strapi/`, `.tmp/` or `node_modules/`. Add plugins and dependencies with `npm install <name>`.
