# compass demo tape — renders a terminal GIF showing the config in action.
#
# Render it (one command, after `brew install vhs`):
#     vhs demo/demo.tape          # or: make demo
# Produces demo/compass.gif. Commit that gif and it shows at the top of the README.
#
# Every command here is repo-local and deterministic — no plugin install or
# network needed, so the recording is reproducible.

Output demo/compass.gif

Set Shell "zsh"
Set FontSize 16
Set Width 1280
Set Height 800
Set Padding 20
Set Theme "Catppuccin Mocha"
Set TypingSpeed 35ms

Type "# compass — one config, both agents (Claude Code + Codex)"
Enter
Sleep 700ms

Type "# 1) validate the whole setup"
Enter
Type "make doctor | tail -6"
Enter
Sleep 2.5s

Type "# 2) the status line: model · dir · git · context · cost"
Enter
Type `echo '{"model":{"display_name":"Claude Opus 4.7"},"workspace":{"current_dir":"/Users/you/lantern"},"permission_mode":"acceptEdits","cost":{"estimated_cost_cents":37,"total_input_tokens":42000}}' | claude/statusline.sh; echo`
Enter
Sleep 2.5s

Type "# 3) the guardrail blocks catastrophe (exit 2), allows real subpaths"
Enter
Type `echo '{"tool_name":"Bash","tool_input":{"command":"rm -rf /"}}' | claude/hooks/protect-paths.sh; echo " exit=$?"`
Enter
Sleep 2s
Type `echo '{"tool_name":"Bash","tool_input":{"command":"rm -rf ./build"}}' | claude/hooks/protect-paths.sh; echo "allowed exit=$?"`
Enter
Sleep 2.5s

Type "# 4) the roster: specialist subagents + workflow commands"
Enter
Type "ls claude/agents | sed 's/.md//' | column && echo --- && ls claude/commands | sed 's/.md//' | column"
Enter
Sleep 3s

Type "# install once -> every repo gets it.  /plugin install core@compass for teams."
Enter
Sleep 2.5s
