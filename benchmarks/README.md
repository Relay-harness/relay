# Benchmarks

Round 1 of Relay's pre-registered benchmark: Relay 0.6.118 against Claude Code 2.1.300, Prime Agent 0.10.0 and Hermes 0.22.2, on the same model and the same tasks. Hidden judges outside each tool's repository graded every run. The tests and the measures were fixed before the first paid run.

- Full write-up: [relayevals.com/ai-coding-agent-benchmark](https://relayevals.com/ai-coding-agent-benchmark)
- Pre-registration, runner, meter, task lock and every analysis script: [cicada0007/relay-bench](https://github.com/cicada0007/relay-bench)
- Every number below, per tool and per test, from the round's analysis: [`round-1/results.json`](round-1/results.json)

## Every result

Each test's own measure, per tool. A dash is a tool the test did not run.

| Test | Model | Measure | Relay | Claude Code | Prime Agent | Hermes |
| --- | --- | --- | ---: | ---: | ---: | ---: |
| A · Long requests | Claude Sonnet 5.5 | requirements met | 90.5% | 98.6% | 92.6% | – |
| B · Everyday changes | Claude Haiku 5.5 | solved | 91.7% | 100.0% | 100.0% | 100.0% |
| B · Long requests | Claude Haiku 5.5 | requirements met | 73.6% | 93.1% | 58.3% | 90.3% |
| D · Faults during a long request | Claude Haiku 5.5 | requirements met | 80.6% | 97.2% | 2.8% | 97.2% |
| F · Terminal-Bench 2.1 | Claude Haiku 5.5 | solved | 71.8% | 83.3% | – | – |
| G · OOLONG (yahoo, 128k) | Claude Haiku 5.5 | solved | 10.0% | 2.0% | 6.0% | – |
| G · LongBench v2 | Claude Haiku 5.5 | solved | 60.0% | 60.0% | 58.0% | – |

## Relay minus each tool

The mean over tasks of Relay's score minus the other tool's, in points, with a bootstrap 95% interval over tasks (10,000 resamples, seed 20261015). Test D has one task, so it has no interval.

| Test | Relay minus | Points | 95% interval | Tasks or items |
| --- | --- | ---: | --- | ---: |
| A · Long requests | Claude Code | −8.1 | −16.0 to −1.4 | 12 |
| A · Long requests | Prime Agent | −2.1 | −11.3 to 6.9 | 12 |
| B · Everyday changes | Claude Code | −8.3 | −19.4 to 0.0 | 12 |
| B · Everyday changes | Prime Agent | −8.3 | −19.4 to 0.0 | 12 |
| B · Everyday changes | Hermes | −8.3 | −19.4 to 0.0 | 12 |
| B · Long requests | Claude Code | −19.4 | −38.9 to −2.8 | 12 |
| B · Long requests | Prime Agent | +15.3 | −11.1 to 37.5 | 12 |
| B · Long requests | Hermes | −16.7 | −36.1 to −1.4 | 12 |
| F · Terminal-Bench 2.1 | Claude Code | −11.5 | −19.5 to −3.4 | 87 |
| G · OOLONG (yahoo, 128k) | Claude Code | +8.0 | 0.0 to 18.0 | 50 |
| G · OOLONG (yahoo, 128k) | Prime Agent | +4.0 | −8.0 to 16.0 | 50 |
| G · LongBench v2 | Claude Code | 0.0 | −10.0 to 10.0 | 50 |
| G · LongBench v2 | Prime Agent | +2.0 | −4.0 to 10.0 | 50 |

## Faults (test D)

One long request, 2 runs per fault and tool. 120 seconds after the first model request, the tool is killed once, or every model connection is dropped for 10 minutes, or every model request gets an overloaded error for 10 minutes. Every tool runs in the same restart loop, which calls the tool's own resume command up to 3 times.

| Finished with nobody acting | Killed | Network cut | Model errors |
| --- | ---: | ---: | ---: |
| Relay | 1 of 2 | 1 of 2 | 2 of 2 |
| Claude Code | 2 of 2 | 2 of 2 | 1 of 2 |
| Prime Agent | 0 of 2 | 0 of 2 | 0 of 2 |
| Hermes | 2 of 2 | 1 of 2 | 2 of 2 |

## Cost per solved task

Metered model spend divided by the runs that succeeded.

| Test | Relay | Claude Code | Prime Agent | Hermes |
| --- | ---: | ---: | ---: | ---: |
| A · Long requests | $2.613 | $2.210 | $2.379 | – |
| B · Everyday changes | $0.045 | $0.034 | $0.032 | $0.036 |
| B · Long requests | $1.239 | $2.483 | $4.501 | $2.385 |
| D · Faults during a long request | $0.643 | $1.203 | – | $1.388 |
| F · Terminal-Bench 2.1 | $0.032 | $0.048 | – | – |
| G · OOLONG (yahoo, 128k) | $0.038 | $0.091 | $0.051 | – |
| G · LongBench v2 | $0.012 | $0.008 | $0.016 | – |

| | Relay | Claude Code | Prime Agent |
| --- | ---: | ---: | ---: |
| Said done but failed (test A) | 26.5% | 5.9% | 23.5% |

## How it ran

- **Tests.** A: 12 long requests of about 6 parts each, 3 runs per tool. B: 12 everyday changes, 3 runs each, and test A's long requests once each. D: one long request under three faults. F: Terminal-Bench 2.1, all 89 public tasks, 2 trials each, through Harbor 0.24.0. G: OOLONG and LongBench v2, scored by their own published scorers.
- **Same model, one meter.** Every model tier of every tool was set to the test model. All model traffic went through one meter inside each sandbox, which counted every token, so cost means the same for every tool.
- **Grading.** Each run was graded by a judge the tool never saw, on a clean copy of its result.
- **Stops and drops.** Test A stopped at its $190 cap after 102 of 108 runs; the runs not made are the same for every tool. In test F, qemu-alpine-ssh and qemu-startup were dropped for both tools after our infrastructure failed twice.
- **Reward hacking.** Every counted run was read for edited or skipped tests, hard-coded answers and access to the judge or the meter. None was found ([the check](https://github.com/cicada0007/relay-bench/blob/main/results/reward-hacking-round-1.md)).
- **Official numbers.** No same-model official numbers exist for these tools on Terminal-Bench 2.1, OOLONG or LongBench v2 ([what was checked](https://github.com/cicada0007/relay-bench/blob/main/results/official-numbers-round-1.md)).
- **Spend.** At most $317.42 of a $400 budget, pilot included.

## Reproduce it

The runbook in [relay-bench](https://github.com/cicada0007/relay-bench/blob/main/RUNBOOK.md) has one command per test. Each needs Node 22, an Anthropic API key and an E2B key in the environment.
