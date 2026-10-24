# Scoreboard

Relay's meta-harness and each single tool on public benchmarks and on Relay's sealed exam, on the same model and the same tasks, rebuilt every week from the trials' own records. Week 2026-W43.

- Every number below: [`scoreboard.json`](scoreboard.json), built by `scripts/scoreboard.mjs` in [cicada0007/relay-bench](https://github.com/cicada0007/relay-bench) at `36f67b5`.
- The runners, the meter, the picker and one command per run: [the runbook](https://github.com/cicada0007/relay-bench/blob/main/RUNBOOK.md#the-scoreboard-every-week).
- Round 1, with every test: [the benchmarks page](../README.md).

**Relay meta-harness.** Every single tool in a run works on the same task; the picker reads each attempt's actions and their output (or its change and the project's own checks) and keeps one. Its grade on a task is the grade of the attempt it kept. The picker never sees a grade, the hidden tests, any tool's words about its own work, or which tool made which attempt. Cost: every attempt in the group plus the picker. Where the picker was asked only about groups the grader split, its cost on the other groups is estimated from the asked calls' mean and shown apart.

## Every benchmark

Each run's own measure, per entry. A dash is an entry the run did not have.

| Benchmark | Model | Measure | Relay | Claude Code | Relay meta-harness |
| --- | --- | --- | ---: | ---: | ---: |
| Terminal-Bench 2.1 | Claude Haiku 5.5 | solved | 71.8% | 83.3% | 86.2% |
| SWE-bench Verified | not run yet | resolved | – | – | – |
| SWE-bench Pro | not run yet | resolved | – | – | – |
| Relay's sealed exam | not run yet | requirements met | – | – | – |

## Terminal-Bench 2.1

Dataset `terminal-bench/terminal-bench-2-1@sha256:7d7bdc1c…` (registry revision 6, 89 tasks), through Harbor 0.24.0, each task in its own sandbox.

### Round 1, test F · Claude Haiku 5.5

87 tasks, 2 trials per task, 16 to 17 Oct 2026. Dropped for every entry after our infrastructure failed twice: qemu-alpine-ssh, qemu-startup.

| Entry | Score | 95% interval | Tasks | Cost | Cost per solved task | Median minutes |
| --- | ---: | --- | ---: | ---: | ---: | ---: |
| Relay 0.6.118 | 71.8% | 63.2% to 80.5% | 87 | $4.00 | $0.032 | 1.6 |
| Claude Code 2.1.300 | 83.3% | 76.4% to 89.7% | 87 | $6.90 | $0.048 | 1.4 |
| Relay meta-harness | 86.2% | 79.3% to 92.0% | 87 | $17.35 | $0.116 | 2.0 |

|  | Points | 95% interval | Tasks |
| --- | ---: | --- | ---: |
| Relay meta-harness minus Relay 0.6.118 | +14.4 | 7.5 to 21.8 | 87 |
| Relay meta-harness minus Claude Code 2.1.300 | +2.9 | −1.1 to 6.9 | 87 |
| Relay 0.6.118 minus Claude Code 2.1.300 | −11.5 | −19.5 to −3.4 | 87 |

Relay meta-harness: 2 attempts per group (Claude Code 2.1.300, Relay 0.6.118), picker gpt-6.1-sol at medium effort. 174 groups over 87 tasks; the grader split 42 of them. The picker was asked about 42 groups and kept the higher-graded attempt in 36 of the 42 split groups. Cost $17.35: attempts $10.90 + picker $1.56 + picker estimated on the 132 groups not asked $4.89. Keeping the attempt the grader scored higher in every group would score 89.7%.

## SWE-bench Verified

Dataset `swe-bench/swe-bench-verified@sha256:b934b0cc…` (registry revision 2, 500 tasks), through Harbor 0.24.0, each task in its own sandbox.

Not run yet.

## SWE-bench Pro

Dataset `scale-ai/swe-bench-pro@sha256:88411d32…` (registry revision 2, 731 tasks), through Harbor 0.24.0, each task in its own sandbox.

Not run yet.

## Relay's sealed exam

Tasks drafted from public issues filed after the models' training cutoffs, kept in a private repository the agent that improves Relay never sees (TIERS.md). Counts and scores only: no task is named.

Not run yet.

## Not in the registry

- **Terminal-Bench 4.0** (checked 24 Oct 2026, Harbor 0.24.0): The terminal-bench organisation publishes terminal-bench, terminal-bench-2 and terminal-bench-2-1 only. The 4.0 copies in the registry belong to a personal account (ryanmarten/terminal-bench-4-no-prebuild, tagged 4.0.0, and ryanmarten/tb4-preview), so the scoreboard does not run them.

## Week by week

| Week | Benchmark | Model | Entry | Score | 95% interval |
| --- | --- | --- | --- | ---: | --- |
| 2026-W43 | Terminal-Bench 2.1 | Claude Haiku 5.5 | Relay 0.6.118 | 71.8% | 63.2% to 80.5% |
| 2026-W43 | Terminal-Bench 2.1 | Claude Haiku 5.5 | Claude Code 2.1.300 | 83.3% | 76.4% to 89.7% |
| 2026-W43 | Terminal-Bench 2.1 | Claude Haiku 5.5 | Relay meta-harness | 86.2% | 79.3% to 92.0% |

## How it runs

- **Same model, one meter.** Every entry in a run uses the same model, tasks, limits and meter. Claude Code runs Anthropic models and Codex OpenAI models, so each is in the runs of its own provider's models. All model traffic goes through one meter inside each sandbox, so cost means the same for every entry.
- **The unit.** The task. An entry's score on a task is its mean over that task's trials (the meta-harness: over that task's groups of attempts).
- **Measures.** Solved (Terminal-Bench), resolved (SWE-bench) or requirements met (the exam), percent.
- **Intervals.** 95% percentile bootstrap over tasks, 10000 resamples, seed 20261015.
- **Differences.** The mean over the tasks both entries ran of (the first entry's score minus the second's), in points, with the same interval.
- **Stops and drops.** A task where our infrastructure failed twice for any tool is dropped for every entry.
- **The meta-harness.** A group is one task's attempts with the same trial number, one per tool. A group where an attempt kept no record of its actions is left out and counted.
- **Cost per solved task.** Metered cost divided by the trials (or, for the meta-harness, the groups) that succeeded. **Median minutes.** Median wall time of a trial; for the meta-harness, of its slowest attempt in a group plus the picker's measured time.

## Reproduce it

The [runbook](https://github.com/cicada0007/relay-bench/blob/main/RUNBOOK.md#the-scoreboard-every-week) has one command per run. Each needs Node 22, Harbor 0.24.0, the model's API key and an E2B key in the environment.
