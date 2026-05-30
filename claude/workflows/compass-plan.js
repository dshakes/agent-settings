export const meta = {
  name: 'compass-plan',
  description: 'Draft an implementation plan from several independent angles, score them with a judge panel, then synthesize one plan from the winner while grafting the best ideas from the runners-up. Beats one-plan-iterated when the solution space is wide.',
  whenToUse: 'Before a non-trivial or ambiguous change where the approach is not obvious. Pass the task as args (a string) or args.task. Read-only: it produces a plan, it does not edit code.',
  phases: [
    { title: 'Draft', detail: 'independent plans from distinct angles' },
    { title: 'Judge', detail: 'panel scores each on the same rubric' },
    { title: 'Synthesize', detail: 'one plan from the best, grafting the rest' },
  ],
}

const TASK = (args && (typeof args === 'string' ? args : args.task)) || ''
if (!TASK) return { error: 'compass-plan needs a task — pass it as args, e.g. workflow args "add rate limiting to the login endpoint"' }

// Distinct angles, not the same plan three times. Each agent is told to commit
// to its angle so the panel has real alternatives to weigh.
const ANGLES = [
  { key: 'mvp-first',     stance: 'the smallest change that satisfies the requirement and ships safely; defer everything non-essential' },
  { key: 'risk-first',    stance: 'what can go wrong — failure modes, rollback, blast radius, migration safety — and design the plan around de-risking those first' },
  { key: 'simplicity',    stance: 'the design a senior engineer would call obviously correct in a year: fewest moving parts, reuses what exists, no new abstractions unless they pay' },
]

const PLAN_SCHEMA = {
  type: 'object',
  required: ['summary', 'steps', 'risks'],
  properties: {
    summary: { type: 'string', description: 'the approach in 2-3 sentences' },
    files:   { type: 'array', items: { type: 'string' }, description: 'files to touch' },
    steps:   { type: 'array', items: { type: 'string' }, description: 'ordered, concrete steps' },
    risks:   { type: 'array', items: { type: 'string' } },
    tests:   { type: 'array', items: { type: 'string' }, description: 'how the change is verified' },
  },
}

const SCORE_SCHEMA = {
  type: 'object',
  required: ['score', 'rationale'],
  properties: {
    score:     { type: 'number', description: '0-10 overall: correctness, simplicity, risk-coverage, fit to this repo' },
    rationale: { type: 'string' },
    bestIdea:  { type: 'string', description: 'the single strongest idea in this plan worth keeping even if it loses' },
  },
}

// Each plan is judged the moment it is drafted — risk-first can still be drafting
// while mvp-first is already being scored.
const scored = await pipeline(
  ANGLES,
  a => agent(
    `Task: ${TASK}\n\nRead the relevant code and this repo's CLAUDE.md/AGENTS.md first. Draft an implementation plan from this angle: ${a.stance}. Be concrete — real files, ordered steps, how it's tested.`,
    { label: `draft:${a.key}`, phase: 'Draft', agentType: 'architect', schema: PLAN_SCHEMA },
  ),
  (plan, a) => agent(
    `Score this "${a.key}" plan for the task: ${TASK}\n\n${JSON.stringify(plan, null, 2)}\n\nScore 0-10 on correctness, simplicity, risk-coverage, and fit to this repo. Name its single strongest idea.`,
    { label: `judge:${a.key}`, phase: 'Judge', agentType: 'architect', schema: SCORE_SCHEMA },
  ).then(s => ({ angle: a.key, plan, ...s })),
)

const ranked = scored.filter(Boolean).sort((a, b) => (b.score ?? 0) - (a.score ?? 0))
const winner = ranked[0]
const grafts = ranked.slice(1).map(r => r.bestIdea).filter(Boolean)

phase('Synthesize')
const final = await agent(
  `Task: ${TASK}\n\nThe winning plan (${winner.angle}, scored ${winner.score}/10):\n${JSON.stringify(winner.plan, null, 2)}\n\nStrongest ideas from the runner-up plans, graft any that improve it without bloating it:\n- ${grafts.join('\n- ') || '(none)'}\n\nWrite the final implementation plan as clean markdown: summary, files to touch, ordered steps, risks, and how it's verified. This is the plan a builder will execute — make it concrete and minimal.`,
  { label: 'synthesize', phase: 'Synthesize', agentType: 'architect' },
)

log(`plan synthesized from ${ranked.length} angles (winner: ${winner.angle}, ${winner.score}/10)`)
return { plan: final, winner: winner.angle, ranked: ranked.map(r => ({ angle: r.angle, score: r.score })) }
