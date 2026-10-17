# FastAPI blueprint

For a FastAPI service on Python 3.12 with uv, pytest, ruff and mypy. Two files: `.relay/blueprint.yaml` tells Relay how to install, test, lint and build the project, and `AGENTS.md` tells the agent how the project is written.

## Use it

From your project's root:

```bash
curl -fsSL https://raw.githubusercontent.com/Relay-harness/relay/main/blueprints/fastapi/.relay/blueprint.yaml --create-dirs -o .relay/blueprint.yaml
curl -fsSL https://raw.githubusercontent.com/Relay-harness/relay/main/blueprints/fastapi/AGENTS.md -o AGENTS.md
relay blueprint verify
```

If the project already has an `AGENTS.md`, add this one's lines to it instead of replacing it.

`relay blueprint verify` runs every command in a clean checkout of your base branch and says which pass. When they all do, `relay blueprint commit` commits the file on its own. From then on, a task is done only when every check passes.

## What Relay runs

- `uv sync`
- `uv run pytest`
- `uv run ruff check .`
- `uv run ruff format --check .`
- `uv run mypy app`

## Checked on

a minimal uv project with FastAPI 0.143.3, pytest 9.1.1, ruff 0.17.1 and mypy, on Python 3.12.13. Every command above passed under `relay blueprint verify` (Relay 0.6.118) on 17 October 2026.

## Adjust it

- pytest needs to find your package: set `pythonpath = ["."]` under `[tool.pytest.ini_options]` in `pyproject.toml`, or install the project.
- The type check reads `app/`. If your code lives elsewhere, change `mypy app` to your package's folder.
- On poetry, change `package_manager` to `poetry`, `uv sync` to `poetry install`, and `uv run` to `poetry run`.
