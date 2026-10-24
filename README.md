<h1 align="center">Relay</h1>

<p align="center">
  <strong>The coding agent harness that is done only when your checks pass.</strong><br>
  Runs on your machine, with your own models.
</p>

<p align="center">
  <a href="https://relayevals.com">Website</a> ·
  <a href="https://relayevals.com/docs">Docs</a> ·
  <a href="benchmarks">Benchmarks</a> ·
  <a href="blueprints">Blueprints</a> ·
  <a href="https://relayevals.com/changelog">Changelog</a>
</p>

---

Relay takes a task, works on it in its own branch, and calls it done only when every test, lint and build command your repository names passes in a clean checkout. The result is a pull request, or a branch when Relay cannot push. It runs on your machine and uses your own model account: Claude, ChatGPT, GitHub Copilot or an API key.

## Install

macOS and Linux:

```bash
curl -fsSL https://relayevals.com/install.sh | bash
```

The script is [`install.sh`](install.sh) in this repository, byte for byte. It downloads a versioned release, checks it against the release's published SHA-256 checksums, and installs the `relay` command. Relay runs on Node.js 22.8 or newer; the script offers to install Node when it is missing.

## Quickstart

```bash
cd your-project
relay queue run
```

The first run works out how to install, test, lint and build the project, tries each command once, and offers a first task. Before anything runs you see the task's contract: what it must pass, its budget, and the branch it works on.

For an interactive session instead:

```bash
relay
```

`relay panel` opens the same in a local web page.

## Blueprints

A blueprint is a ready `.relay/blueprint.yaml` and `AGENTS.md` for one stack: how Relay installs, tests, lints and builds the project, and how the project is written. Each one was checked on a freshly created project.

| Stack | |
| --- | --- |
| [Next.js](blueprints/nextjs) | App Router, TypeScript, npm |
| [FastAPI](blueprints/fastapi) | Python 3.12, uv, pytest, ruff, mypy |
| [Payload](blueprints/payload) | Payload 3 on Next.js, pnpm |
| [Strapi](blueprints/strapi) | Strapi 5, TypeScript, npm |
| [Turborepo](blueprints/turborepo) | pnpm workspaces |

```bash
curl -fsSL https://raw.githubusercontent.com/Relay-harness/relay/main/blueprints/nextjs/.relay/blueprint.yaml --create-dirs -o .relay/blueprint.yaml
relay blueprint verify
```

## Benchmarks

Round 1, on the same model and the same tasks, graded by hidden judges. Requirements met on 12 long requests, Claude Sonnet 5.5:

| Relay | Claude Code | Prime Agent |
| ---: | ---: | ---: |
| 90.5% | 98.6% | 92.6% |

Every test, every tool, intervals and costs: [benchmarks](benchmarks). Every week, Relay's meta-harness and each tool on public benchmarks and the sealed exam: [the scoreboard](benchmarks/scoreboard). The pre-registration, runner and raw results: [cicada0007/relay-bench](https://github.com/cicada0007/relay-bench).

## This repository

| | |
| --- | --- |
| [`install.sh`](install.sh) | The installer that `relayevals.com/install.sh` serves |
| [`blueprints/`](blueprints) | Ready blueprints per stack |
| [`benchmarks/`](benchmarks) | Benchmark results and the weekly scoreboard |

The Relay harness itself is distributed through the installer as versioned releases; its source is not in this repository. Questions, bugs and blueprint requests are welcome in [Issues](https://github.com/Relay-harness/relay/issues). Security reports: see [SECURITY.md](SECURITY.md).

## Who builds Relay

Relay is built and maintained by Relay, an independent company. Its source code is managed by the Relay founders: [arnav@relayevals.com](mailto:arnav@relayevals.com).

## License

The contents of this repository are released under the [MIT License](LICENSE).
