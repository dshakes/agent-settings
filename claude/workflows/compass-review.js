export const meta = {
  name: 'compass-review',
  description: 'Parallel multi-dimension diff review — each dimension runs as its own agent, every finding is adversarially verified before it is reported, then synthesized into one Blocking/Should-fix/Nit verdict.',
  whenToUse: 'Run on a branch before you ship. Faster and more trustworthy than a single-pass /review: dimensions run concurrently and a skeptic kills plausible-but-wrong findings.',
  phases: [
    { title: 'Review', detail: 'one agent per dimension, in parallel' },
    { title: 'Verify', detail: 'adversarial skeptics refute each finding' },
    { title: 'Synthesize', detail: 'dedup + one reconciled verdict' },
  ],
}

// Diff scope: everything on this branch vs its base. Agents inherit your tool
// allowlist (Read/Grep/Glob/Bash(git diff…)) — no extra permissions needed.
const BASE = (args && args.base) || 'origin/HEAD'
const SCOPE = `Review the diff of the current branch against ${BASE}: run \`git diff ${BASE}...HEAD\` (fall back to \`git diff HEAD~5...HEAD\` if that ref is missing). Only judge lines in the diff and code they directly touch.`

// Each dimension is routed to the compass subagent sized for it — security to the
// opus security-auditor, the rest to the sonnet code-reviewer. Cost follows risk.
const DIMENSIONS = [
  { key: 'correctness', agentType: 'code-reviewer',     lens: 'logic errors, wrong edge-case handling, off-by-one, nil/undefined, broken invariants, missed error paths' },
  { key: 'security',    agentType: 'security-auditor',  lens: 'authz gaps, injection, secret exposure, unsafe input, trust-boundary crossings, tenant isolation' },
  { key: 'performance', agentType: 'code-reviewer',     lens: 'N+1 queries, needless allocation in hot paths, blocking I/O, unbounded growth, accidental O(n²)' },
  { key: 'tests',       agentType: 'code-reviewer',     lens: 'untested new behavior, missing failure-path tests, assertions that cannot fail, flaky timing' },
  { key: 'conventions', agentType: 'code-reviewer',     lens: 'deviations from this repo’s CLAUDE.md/AGENTS.md, naming/style drift, public API without docs' },
]

const FINDINGS_SCHEMA = {
  type: 'object',
  required: ['findings'],
  properties: {
    findings: {
      type: 'array',
      items: {
        type: 'object',
        required: ['title', 'file', 'severity', 'why'],
        properties: {
          title:    { type: 'string' },
          file:     { type: 'string', description: 'path:line' },
          severity: { type: 'string', enum: ['blocking', 'should-fix', 'nit'] },
          why:      { type: 'string', description: 'the concrete failure, one or two sentences' },
        },
      },
    },
  },
}

const VERDICT_SCHEMA = {
  type: 'object',
  required: ['refuted', 'reason'],
  properties: {
    refuted: { type: 'boolean', description: 'true if the finding is wrong, already handled, or not reachable' },
    reason:  { type: 'string' },
  },
}

// Pipeline: each dimension reviews, and its findings start verifying the moment
// that dimension returns — security can still be reviewing while correctness
// findings are already being refuted. No barrier, no wasted wall-clock.
const reviewed = await pipeline(
  DIMENSIONS,
  d => agent(
    `${SCOPE}\n\nYou are the ${d.key} reviewer. Report ONLY ${d.lens}. If nothing in the diff is wrong on this dimension, return an empty findings array — do not invent issues.`,
    { label: `review:${d.key}`, phase: 'Review', agentType: d.agentType, schema: FINDINGS_SCHEMA },
  ),
  (review, d) => parallel((review.findings || []).map(f => () =>
    agent(
      `A ${d.key} reviewer claims this finding on the current diff:\n  ${f.title} (${f.file})\n  ${f.why}\n\nTry to REFUTE it. Read the actual code. It is refuted if it is wrong, already handled elsewhere, or not reachable. Default to refuted=true if you are not sure it is a real, reachable problem.`,
      { label: `verify:${d.key}`, phase: 'Verify', schema: VERDICT_SCHEMA },
    ).then(v => ({ ...f, dimension: d.key, verdict: v }))
  )),
)

// Keep only findings that survived their skeptic. Dedup by file+title so two
// dimensions flagging the same line collapse to one.
const survivors = []
const seen = new Set()
for (const f of reviewed.flat().filter(Boolean)) {
  if (f.verdict?.refuted) continue
  const k = `${f.file}::${f.title}`.toLowerCase()
  if (seen.has(k)) continue
  seen.add(k)
  survivors.push(f)
}

phase('Synthesize')
const order = { blocking: 0, 'should-fix': 1, nit: 2 }
survivors.sort((a, b) => (order[a.severity] ?? 3) - (order[b.severity] ?? 3))
const blocking = survivors.filter(f => f.severity === 'blocking')

log(`${survivors.length} verified findings (${blocking.length} blocking) across ${DIMENSIONS.length} dimensions`)

return {
  verdict: blocking.length ? 'BLOCKING' : 'CLEAN',
  blocking: blocking.length,
  findings: survivors,
}
