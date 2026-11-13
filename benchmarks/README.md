# Benchmarks

November 2026: Relay 0.6.128 (a local build with the fixes from this test) against Claude Code 2.1.300 and Prime Agent 0.10.2, on the same model (OpenAI gpt-6-luna) and the same 12 long requests, one run each. Hidden judges outside each tool's repository graded every run.

- The runner, the meter and the task set: [cicada0007/relay-bench](https://github.com/cicada0007/relay-bench)
- The earlier round, with every test: [round 1, October 2026](round-1)
- Every week, the [scoreboard](scoreboard): Relay's meta-harness and each tool on Terminal-Bench 2.1, SWE-bench Verified, SWE-bench Pro and Relay's sealed exam, per model

## Every result

Each test's own measure, per tool. A dash is a tool the test did not run.

| Test | Model | Measure | Relay | Claude Code | Prime Agent | Hermes |
| --- | --- | --- | ---: | ---: | ---: | ---: |
| Long requests, all 12 | GPT-6 Luna | requirements met | 76.4% | 83.3% | 54.2% | – |
| Long requests, all 12 | GPT-6 Luna | solved (all 6 met) | 25.0% | 41.7% | 8.3% | – |
| Long requests, all 12 | GPT-6 Luna | judge checks passed | 94.6% | 97.0% | 89.5% | – |
| Long requests, 6 in Node | GPT-6 Luna | requirements met | 80.6% | 88.9% | 69.4% | – |
| Long requests, 6 in Python | GPT-6 Luna | requirements met | 72.2% | 77.8% | 38.9% | – |

The same results as counts:

| Measure | Relay | Claude Code | Prime Agent |
| --- | ---: | ---: | ---: |
| Requirements met, of 72 | 55 | 60 | 39 |
| Requirements met | 76.4% | 83.3% | 54.2% |
| Judge checks passed, of 820 | 776 | 795 | 734 |
| Judge checks passed | 94.6% | 97.0% | 89.5% |
| Tasks with all 6 requirements met | 3 | 5 | 1 |
| Model spend | $13.45 | $5.98 | $9.02 |
| Total time | 12.7 h | 6.1 h | 7.3 h |

## Every task

Requirements met, of 6.

| Task | Relay | Claude Code | Prime Agent |
| --- | ---: | ---: | ---: |
| node-build-runner | 5 | 6 | 5 |
| node-http-framework | 6 | 6 | 6 |
| node-kv-store | 6 | 5 | 3 |
| node-package-resolver | 4 | 6 | 4 |
| node-spreadsheet | 6 | 6 | 5 |
| node-template-engine | 2 | 3 | 2 |
| py-calendar | 4 | 5 | 2 |
| py-dataframe | 5 | 6 | 4 |
| py-issue-tracker | 4 | 5 | 1 |
| py-mini-sql | 5 | 4 | 5 |
| py-text-adventure | 4 | 3 | 1 |
| py-vcs-lite | 4 | 5 | 1 |

## Relay minus each tool

The mean over tasks of Relay's requirement share minus the other tool's, in points, with a bootstrap 95% interval over tasks (10,000 resamples, seed 20261015).

| Relay minus | Points | 95% interval | Tasks |
| --- | ---: | --- | ---: |
| Claude Code | −6.9 | −15.3 to 2.8 | 12 |
| Prime Agent | +22.2 | 9.7 to 34.7 | 12 |

## Cost and time per task

| Task | Relay | Claude Code | Prime Agent |
| --- | ---: | ---: | ---: |
| node-build-runner | $0.793 · 57 min | $0.300 · 30 min | $0.443 · 66 min |
| node-http-framework | $1.080 · 66 min | $0.339 · 28 min | $0.311 · 27 min |
| node-kv-store | $1.153 · 70 min | $0.312 · 27 min | $0.076 · 6 min |
| node-package-resolver | $1.299 · 74 min | $0.303 · 23 min | $0.366 · 19 min |
| node-spreadsheet | $1.197 · 76 min | $0.212 · 16 min | $0.151 · 12 min |
| node-template-engine | $1.392 · 77 min | $0.476 · 29 min | $1.697 · 32 min |
| py-calendar | $1.218 · 54 min | $0.898 · 37 min | $0.890 · 26 min |
| py-dataframe | $0.913 · 55 min | $0.365 · 14 min | $0.327 · 18 min |
| py-issue-tracker | $0.829 · 42 min | $0.580 · 41 min | $0.924 · 83 min |
| py-mini-sql | $0.916 · 62 min | $0.755 · 47 min | $1.076 · 27 min |
| py-text-adventure | $1.578 · 71 min | $0.871 · 44 min | $1.749 · 75 min |
| py-vcs-lite | $1.087 · 58 min | $0.567 · 31 min | $1.011 · 48 min |

| | Relay | Claude Code | Prime Agent |
| --- | ---: | ---: | ---: |
| Spend per requirement met | $0.245 | $0.100 | $0.231 |
| Spend per task with all 6 met | $4.485 | $1.195 | $9.022 |
| Said done | 8 of 12 | 12 of 12 | 11 of 12 |
| Said done but failed | 7 of 8 | 7 of 12 | 10 of 11 |

## How it ran

- **Tasks.** 12 long requests of 6 numbered parts each, from the relay-bench task set: 6 in Node, 6 in Python. One run per tool per task.
- **Same model, one meter.** Every tool ran gpt-6-luna through the OpenAI Responses API. All model traffic went through one meter inside each E2B sandbox, which counted every token, so spend means the same for every tool.
- **Limits.** 180 minutes per run. Spend cap per run: $6 for Relay, $2 for the others.
- **Grading.** Each run was graded by a judge the tool never saw, on a clean copy of its result. A requirement is met when all of its checks pass.
- **Refused planning calls.** OpenAI rejected Relay's planning request as "flagged as potentially violating" in 7 runs, and one Prime Agent run stopped at the start in the same way. Each of these spent less than $0.01. They were set aside and run again, under a rule set before the re-runs. Probes showed the same request was flagged at random, more often when several were sent at once. A Relay build that resends a flagged planning request unchanged ran the last two tasks (node-spreadsheet and py-dataframe). No request was flagged in those runs.
- **Counted run.** py-text-adventure has two completed Relay runs, at 4 and 5 requirements met. The first is counted. Counting the second instead gives Relay 56 of 72, $13.09, 12.5 h, and −5.6 points (−15.3 to 5.6) against Claude Code.
- **Spend.** About $58 of model spend across the pilot, set-aside runs and re-runs, under a $120 cap.
