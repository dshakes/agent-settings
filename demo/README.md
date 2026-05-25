# Demo

`compass.gif` (shown at the top of the root README) is generated from
[`demo.tape`](demo.tape) with [vhs](https://github.com/charmbracelet/vhs) — a tool
that records a terminal session from a script, so the demo is reproducible and
diff-able instead of a hand-captured screen recording.

## Render it
```bash
brew install vhs        # or: go install github.com/charmbracelet/vhs@latest
make demo               # == vhs demo/demo.tape  -> demo/compass.gif
git add demo/compass.gif && git commit -m "docs: refresh demo gif"
```

The tape only runs repo-local, read-only commands (`make doctor`, the status line,
the guardrail, the agent/command roster), so it needs no network or plugin install
and produces the same output every time.

## Prefer a web player?
`asciinema rec demo.cast` records a lightweight, copy-pasteable cast you can embed
via asciinema.org or `agg demo.cast demo.gif`.
