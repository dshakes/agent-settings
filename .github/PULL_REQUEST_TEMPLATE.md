<!-- Thanks for contributing to compass. Keep PRs focused. -->

## What & why
<!-- What changed and the reason. Link any issue. -->

## How I verified
- [ ] `make doctor` reports **0 errors**
- [ ] If I touched `claude/{agents,commands,skills,output-styles,hooks}`, I ran `make sync-plugin`
- [ ] Hooks (if changed) still never fail a session (only an intentional PreToolUse `exit 2` blocks)
- [ ] Docs/commands I changed still run; paths referenced exist

## Notes
<!-- Tradeoffs, follow-ups, anything a reviewer should know. -->
