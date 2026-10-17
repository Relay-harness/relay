# Contributing

Thank you for helping. This repository holds Relay's installer, its blueprints and its benchmark results.

## Blueprints

A new blueprint, or a fix to one, is the most useful contribution.

1. Create a fresh project for the stack with its official starter.
2. Add `blueprints/<stack>/.relay/blueprint.yaml`, `blueprints/<stack>/AGENTS.md` and `blueprints/<stack>/README.md`, following an existing blueprint.
3. Copy both files into the fresh project, commit, and run `relay blueprint verify`. Every command must pass.
4. Say in the README which starter and versions you checked, and on what date.
5. Open a pull request with the `relay blueprint verify` output.

Keep each `AGENTS.md` short and specific to the stack: where things live, the conventions the stack expects, and the checks to run before a task is done.

## Benchmarks

Benchmark results come from the pre-registered runs in [cicada0007/relay-bench](https://github.com/cicada0007/relay-bench). They are not edited here by hand. To question a result, open an issue there.

## The installer

`install.sh` is published with each Relay release and copied here unchanged. Report a problem with it in an issue; changes to it are made in the release, not in this repository.
