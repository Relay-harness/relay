# Working in this FastAPI service

- The app object lives in `app/main.py`. Group routes with `APIRouter` in modules under `app/`, and include them in `main.py`.
- Every endpoint declares its request and response models with Pydantic, and returns those models, not bare dicts, once the service grows past a health check.
- Use `Depends` for shared resources (database sessions, settings, the current user); do not create them inside a handler.
- Settings come from the environment through one settings object. Never hard-code a secret, and never commit `.env`.
- Blocking I/O does not go in an `async def` handler: use a `def` handler, or an async client.
- Tests use `fastapi.testclient.TestClient` (or `httpx.AsyncClient`) under `tests/`. A change to an endpoint comes with a test of it.
- Before calling a task done, run `uv run pytest`, `uv run ruff check .`, `uv run ruff format --check .` and `uv run mypy app`. All four must pass.
- Add dependencies with `uv add <name>` (or `uv add --dev <name>`), never by editing the lockfile.
