export const meta = {
  name: 'compass-audit',
  description: 'Exhaustive whole-codebase bug & security sweep. Multi-modal finders search by different angles, loop until two dry rounds, and each fresh finding is confirmed by a perspective-diverse panel (2-of-3 vote) before it is reported.',
  whenToUse: 'A deep audit of an area or the whole repo — more coverage than one review pass. Scope it with args.path (e.g. "src/routes"). Spends real tokens across many agents; stop it from /workflows anytime.',
  phases: [
    { title: 'Sweep', detail: 'multi-modal finders, loop-until-dry' },
    { title: 'Confirm', detail: '3-lens panel votes on each fresh finding' },
  ],
}

const PATH = (args && args.path) || '.'
const MAX_DRY = (args && args.maxDry) || 2          // stop after this many empty rounds
const MAX_ROUNDS = (args && args.maxRounds) || 6    // hard cap regardless

// Each finder is blind to the others and hunts a different failure class. One
// search angle never finds everything; overlapping angles do.
const FINDERS = [
  { key: 'authz',      hunt: 'missing or wrong authorization/authentication checks, privilege escalation, IDOR, endpoints reachable without the right scope' },
  { key: 'injection',  hunt: 'SQL/command/template/path injection, unsanitized input flowing into a sink, unsafe deserialization' },
  { key: 'errors',     hunt: 'swallowed errors, unchecked returns, panics/unwraps on fallible paths, partial failure left in a bad state' },
  { key: 'concurrency',hunt: 'data races, unsynchronized shared state, deadlocks, check-then-act races, context/cancellation not honored' },
  { key: 'resources',  hunt: 'leaked file handles/connections/goroutines, unbounded buffers/caches, missing timeouts, retry storms' },
  { key: 'secrets',    hunt: 'hardcoded credentials/keys, secrets logged or returned in responses, tokens with no expiry' },
]

const BUGS_SCHEMA = {
  type: 'object',
  required: ['bugs'],
  properties: {
    bugs: {
      type: 'array',
      items: {
        type: 'object',
        required: ['title', 'file', 'why'],
        properties: {
          title: { type: 'string' },
          file:  { type: 'string', description: 'path:line' },
          why:   { type: 'string', description: 'the concrete failure and how it triggers' },
          severity: { type: 'string', enum: ['critical', 'high', 'medium', 'low'] },
        },
      },
    },
  },
}

const VOTE_SCHEMA = {
  type: 'object',
  required: ['real', 'reason'],
  properties: {
    real:   { type: 'boolean', description: 'true only if this is a genuine, reachable defect' },
    reason: { type: 'string' },
  },
}

const key = b => `${(b.file || '').toLowerCase()}::${(b.title || '').toLowerCase()}`

const seen = new Set()
const confirmed = []
let dry = 0
let round = 0

while (dry < MAX_DRY && round < MAX_ROUNDS) {
  round++
  // Barrier: collect this round's finders together so we can dedup against
  // everything seen so far before paying for confirmation.
  const found = (await parallel(FINDERS.map(f => () =>
    agent(
      `Search ${PATH} for: ${f.hunt}. Read real code — grep for the risky patterns, then open the files. Report only defects you can point to a specific line for. Round ${round}; if you are confident the area is clean for your class, return an empty array.`,
      { label: `sweep:${f.key}#${round}`, phase: 'Sweep', schema: BUGS_SCHEMA },
    )))).filter(Boolean).flatMap(r => r.bugs || [])

  const fresh = found.filter(b => b.file && !seen.has(key(b)))
  if (!fresh.length) { dry++; log(`round ${round}: no new findings (dry ${dry}/${MAX_DRY})`); continue }
  dry = 0
  fresh.forEach(b => seen.add(key(b)))
  log(`round ${round}: ${fresh.length} fresh findings → 3-lens confirmation`)

  // Perspective-diverse confirmation: three lenses, not three clones. A finding
  // ships only if at least two of three independently call it real.
  const judged = await parallel(fresh.map(b => () =>
    parallel(['exploitability', 'reachability', 'correctness'].map(lens => () =>
      agent(
        `Judge this candidate defect through the ${lens} lens — is it a genuine, reachable problem?\n  ${b.title} (${b.file})\n  ${b.why}\nRead the code before deciding. Be skeptical: if the ${lens} case is not actually met, answer real=false.`,
        { label: `confirm:${lens}`, phase: 'Confirm', schema: VOTE_SCHEMA },
      )))
      .then(votes => {
        const yes = votes.filter(Boolean).filter(v => v.real).length
        return { ...b, votes: yes, real: yes >= 2 }
      })))

  confirmed.push(...judged.filter(v => v.real))
}

phase('Confirm')
const sev = { critical: 0, high: 1, medium: 2, low: 3 }
confirmed.sort((a, b) => (sev[a.severity] ?? 4) - (sev[b.severity] ?? 4))
log(`audit complete: ${confirmed.length} confirmed findings over ${round} rounds (${seen.size} candidates triaged)`)

return {
  confirmed: confirmed.length,
  candidates: seen.size,
  rounds: round,
  findings: confirmed,
  note: dry < MAX_DRY ? `stopped at round cap (${MAX_ROUNDS}) — more may remain` : 'converged (two dry rounds)',
}
