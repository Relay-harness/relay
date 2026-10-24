#!/usr/bin/env node
// Renders benchmarks/scoreboard/README.md from scoreboard.json beside it. The page is never edited by hand: every
// number on it is the file's, built each week by scripts/scoreboard.mjs in cicada0007/relay-bench.
//
//   node benchmarks/scoreboard/render.mjs           writes README.md
//   node benchmarks/scoreboard/render.mjs --check   exits 1 when README.md is not the file's rendering, or when either
//                                                   holds a word for a result
//
// Numbers only, as on the round 1 page: each score with its interval, no word for a result, no colour.
import { readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const HERE = dirname(fileURLToPath(import.meta.url));
const HISTORY_WEEKS = 12;

/** Words that describe a result rather than state it; neither the file nor the page may hold one. */
export const RESULT_WORDS = /\b(better|worse|beats?|beaten|outperform\w*|wins?|won|loses?|lost|best|worst|clear difference)\b/i;

const dash = "–";
const fix = (v, d = 1) => {
	const s = Math.abs(v).toFixed(d);
	return Number(s) === 0 ? (0).toFixed(d) : v < 0 ? `−${s}` : s;
};
const pct = (v) => (v === null || v === undefined ? dash : `${fix(v)}%`);
const signed = (v) => (v === null || v === undefined ? dash : Number(Math.abs(v).toFixed(1)) === 0 ? "0.0" : v > 0 ? `+${fix(v)}` : fix(v));
const usd = (v, d = 3) => (v === null || v === undefined ? dash : `$${v.toFixed(d)}`);
const minutes = (v) => (v === null || v === undefined ? dash : v.toFixed(1));
const interval = (low, high, unit = "") => (low === null || low === undefined ? dash : `${fix(low)}${unit} to ${fix(high)}${unit}`);
const MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
const day = (iso) => {
	const [y, m, d] = iso.split("-").map(Number);
	return `${d} ${MONTHS[m - 1]} ${y}`;
};
const span = (a, b) => (!a ? null : a === b ? day(a) : a.slice(0, 7) === b.slice(0, 7) ? `${Number(a.slice(8))} to ${day(b)}` : `${day(a)} to ${day(b)}`);
const short = (pin) => pin.replace(/(sha256:[0-9a-f]{8})[0-9a-f]+/, "$1…");
const table = (head, align, rows) => [`| ${head.join(" | ")} |`, `| ${align.map((a) => (a === "r" ? "---:" : "---")).join(" | ")} |`, ...rows.map((r) => `| ${r.join(" | ")} |`)].join("\n");

const baseTool = (id) => id.split("@")[0];
const COLUMNS = [
	["relay", "Relay"],
	["claude-code", "Claude Code"],
	["codex", "Codex"],
	["prime-agent", "Prime Agent"],
	["hermes", "Hermes"],
	["meta", "Relay meta-harness"],
];

/** The run's title on the page. */
const runTitle = (b, run) => (run.label.includes(run.modelName) ? run.label : b.runs.length > 1 || run.label !== run.test ? `${run.label} · ${run.modelName}` : run.modelName);
const count = (n) => n.toLocaleString("en-US");

function summary(board) {
	const present = new Set(board.benchmarks.flatMap((b) => b.runs.flatMap((r) => r.entries.map((e) => baseTool(e.id)))));
	const cols = COLUMNS.filter(([id]) => id === "relay" || id === "meta" || present.has(id));
	const rows = [];
	for (const b of board.benchmarks) {
		if (!b.runs.length) {
			rows.push([b.title, "not run yet", b.measure, ...cols.map(() => dash)]);
			continue;
		}
		for (const run of b.runs) {
			const at = (id) => run.entries.find((e) => baseTool(e.id) === id);
			const label = b.runs.length > 1 ? `${b.title} · ${run.label}` : b.title;
			rows.push([label, run.modelName, b.measure, ...cols.map(([id]) => pct(at(id)?.score ?? null))]);
		}
	}
	return table(["Benchmark", "Model", "Measure", ...cols.map(([, name]) => name)], ["l", "l", "l", ...cols.map(() => "r")], rows);
}

function metaNote(meta, entries) {
	const name = (id) => entries.find((e) => e.id === id)?.name ?? id;
	const parts = [`${meta.arms.length} attempts per group (${meta.arms.map(name).join(", ")}), picker ${meta.picker.model} at ${meta.picker.effort} effort.`];
	if (!meta.groups) return [...parts, `${count(meta.groupsNotDecided)} groups not picked yet.`].join(" ");
	parts.push(`${meta.groups} groups over ${meta.tasks} tasks; the grader split ${meta.splitGroups} of them.`);
	parts.push(`The picker was asked about ${meta.groupsAsked} groups${meta.splitGroups ? ` and kept the higher-graded attempt in ${meta.pickedTopGraded} of the ${meta.splitGroups} split groups` : ""}.`);
	const cost = [`attempts ${usd(meta.attemptsUsd, 2)}`, `picker ${usd(meta.pickerUsd, 2)}`];
	if (meta.groupsPickerEstimated) cost.push(`picker estimated on the ${meta.groupsPickerEstimated} groups not asked ${usd(meta.pickerEstimatedUsd, 2)}`);
	parts.push(`Cost ${usd(meta.costUsd, 2)}: ${cost.join(" + ")}.`);
	if (meta.bestPossible !== null && meta.bestPossible !== undefined) parts.push(`Keeping the attempt the grader scored higher in every group would score ${pct(meta.bestPossible)}.`);
	if (meta.groupsLeftOut) parts.push(`${meta.groupsLeftOut} groups left out: an attempt kept no record of its actions.`);
	if (meta.groupsNotDecided) parts.push(`${count(meta.groupsNotDecided)} groups not picked yet.`);
	return parts.join(" ");
}

function runSection(b, run) {
	const out = [`### ${runTitle(b, run)}`, ""];
	const facts = [`${run.tasks} tasks`, `${run.trialsPerTask} ${run.trialsPerTask === 1 ? "trial" : "trials"} per task`];
	if (run.sample) facts.push(`a fixed sample of ${run.sample} of the set's tasks`);
	const when = span(run.firstTrial, run.lastTrial);
	if (when) facts.push(when);
	let line = `${facts.join(", ")}.`;
	if (run.status === "in progress" && run.trialsNotMade) line += ` In progress: ${count(run.trialsNotMade)} trials not made yet.`;
	if (run.droppedTasks?.length) line += ` Dropped for every entry after our infrastructure failed twice: ${run.droppedTasks.map((t) => t.split("/").pop()).join(", ")}.`;
	if (typeof run.droppedTaskCount === "number" && run.droppedTaskCount) line += ` Tasks dropped for every entry after our infrastructure failed twice: ${run.droppedTaskCount}.`;
	out.push(line, "");
	out.push(
		table(
			["Entry", "Score", "95% interval", "Tasks", "Cost", "Cost per solved task", "Median minutes"],
			["l", "r", "l", "r", "r", "r", "r"],
			run.entries.map((e) => (e.kind === "meta" && !e.groups ? [e.name, dash, dash, "0", dash, dash, dash] : [e.name, pct(e.score), interval(e.low, e.high, "%"), String(e.tasks), usd(e.costUsd, 2), usd(e.costPerSolvedUsd), minutes(e.medianMinutes)])),
		),
		"",
	);
	if (run.differences.length) {
		const name = (id) => run.entries.find((e) => e.id === id)?.name ?? id;
		out.push(table(["", "Points", "95% interval", "Tasks"], ["l", "r", "l", "r"], run.differences.map((d) => [`${name(d.of)} minus ${name(d.minus)}`, signed(d.points), interval(d.low, d.high), String(d.tasks)])), "");
	}
	const meta = run.entries.find((e) => e.kind === "meta");
	if (meta) out.push(`Relay meta-harness: ${metaNote(meta, run.entries)}`, "");
	return out.join("\n");
}

function benchmarkSection(b) {
	const out = [`## ${b.title}`, ""];
	if (b.about) {
		out.push(b.about, "");
	} else {
		out.push(`Dataset \`${short(b.dataset)}\` (registry revision ${b.datasetRevision}, ${b.tasksInSet} tasks), through Harbor ${b.harbor}, each task in its own sandbox.`, "");
	}
	if (!b.runs.length) {
		out.push("Not run yet.", "");
		return out.join("\n");
	}
	for (const run of b.runs) out.push(runSection(b, run));
	return out.join("\n");
}

function history(board) {
	const weeks = [...new Set(board.history.map((h) => h.week))].sort().slice(-HISTORY_WEEKS);
	const titles = new Map(board.benchmarks.map((b) => [b.id, b.title]));
	const models = new Map(board.benchmarks.flatMap((b) => b.runs.map((r) => [r.model, r.modelName])));
	const rows = board.history
		.filter((h) => weeks.includes(h.week))
		.map((h) => [h.week, titles.get(h.benchmark) ?? h.benchmark, models.get(h.model) ?? h.model, h.name ?? h.entry, pct(h.score), interval(h.low, h.high, "%")]);
	return table(["Week", "Benchmark", "Model", "Entry", "Score", "95% interval"], ["l", "l", "l", "l", "r", "l"], rows);
}

/** The page, from the scoreboard file. */
export function render(board) {
	const repo = board.repository;
	const lines = [
		"# Scoreboard",
		"",
		`Relay's meta-harness and each single tool on public benchmarks and on Relay's sealed exam, on the same model and the same tasks, rebuilt every week from the trials' own records. Week ${board.week}.`,
		"",
		`- Every number below: [\`scoreboard.json\`](scoreboard.json), built by \`scripts/scoreboard.mjs\` in [cicada0007/relay-bench](${repo})${board.commit ? ` at \`${board.commit.slice(0, 7)}\`` : ""}.`,
		`- The runners, the meter, the picker and one command per run: [the runbook](${repo}/blob/main/RUNBOOK.md#the-scoreboard-every-week).`,
		`- Round 1, with every test: [the benchmarks page](../README.md).`,
		"",
		`**${board.metaHarness.name}.** ${board.metaHarness.what} ${board.metaHarness.blind} Cost: ${board.metaHarness.cost.charAt(0).toLowerCase()}${board.metaHarness.cost.slice(1)}`,
		"",
		"## Every benchmark",
		"",
		"Each run's own measure, per entry. A dash is an entry the run did not have.",
		"",
		summary(board),
		"",
		...board.benchmarks.map(benchmarkSection),
	];
	if (board.notInRegistry?.length) {
		lines.push("## Not in the registry", "");
		for (const n of board.notInRegistry) lines.push(`- **${n.name}** (checked ${day(n.checked)}, Harbor ${n.harbor}): ${n.note}`);
		lines.push("");
	}
	if (board.history?.length) lines.push("## Week by week", "", history(board), "");
	lines.push(
		"## How it runs",
		"",
		`- **Same model, one meter.** ${board.statistics.sameModel} All model traffic goes through one meter inside each sandbox, so cost means the same for every entry.`,
		`- **The unit.** ${board.statistics.unit}`,
		`- **Measures.** ${board.measures.score}`,
		`- **Intervals.** ${board.statistics.interval}`,
		`- **Differences.** ${board.statistics.difference}`,
		`- **Stops and drops.** ${board.statistics.dropped}`,
		`- **The meta-harness.** ${board.metaHarness.groups}`,
		`- **Cost per solved task.** ${board.measures.costPerSolvedUsd} **Median minutes.** ${board.measures.medianMinutes}`,
		"",
		"## Reproduce it",
		"",
		`The [runbook](${repo}/blob/main/RUNBOOK.md#the-scoreboard-every-week) has one command per run. Each needs Node 22, Harbor 0.24.0, the model's API key and an E2B key in the environment.`,
		"",
	);
	return lines.join("\n");
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
	const text = readFileSync(join(HERE, "scoreboard.json"), "utf8");
	const page = render(JSON.parse(text));
	const readmePath = join(HERE, "README.md");
	if (process.argv.includes("--check")) {
		let current = "";
		try {
			current = readFileSync(readmePath, "utf8");
		} catch {}
		const problems = [];
		if (current !== page) problems.push("README.md is not the rendering of scoreboard.json: run node benchmarks/scoreboard/render.mjs");
		for (const [name, body] of [["scoreboard.json", text], ["README.md", page]]) {
			const word = body.match(RESULT_WORDS);
			if (word) problems.push(`${name} has a word for a result: "${word[0]}"`);
		}
		for (const p of problems) console.error(p);
		process.exit(problems.length ? 1 : 0);
	}
	writeFileSync(readmePath, page);
	console.log(`wrote ${readmePath}`);
}
