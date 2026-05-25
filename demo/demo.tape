# compass demo — render with:  vhs demo/demo.tape   (or: make demo)
# Punchy, error-free, repo-local. Short helper commands (see demo/_demo.sh) keep
# the screen clean; narration uses shell comments enabled in a hidden setup block.

Output demo/compass.gif

Set Shell "zsh"
Set FontSize 22
Set Width 1120
Set Height 600
Set Padding 28
Set Theme "Catppuccin Mocha"
Set TypingSpeed 22ms

Hide
Type "source demo/_demo.sh; setopt interactive_comments 2>/dev/null; PROMPT='%F{42}❯%f '; clear"
Enter
Sleep 400ms
Show

Type "# compass — one config, both agents: Claude Code + Codex"
Enter
Sleep 850ms

Type "# blocks the catastrophic, allows the rest"
Enter
Sleep 400ms
Type "guard 'rm -rf /'"
Enter
Sleep 1000ms
Type "guard 'rm -rf ./build'"
Enter
Sleep 1300ms

Type "# the live status line: model · dir · git · context · cost"
Enter
Sleep 400ms
Type "statusline"
Enter
Sleep 1500ms

Type "# a cost-tiered crew + the workflows you actually use"
Enter
Sleep 400ms
Type "roster"
Enter
Sleep 850ms
Type "cmds"
Enter
Sleep 1200ms

Type "# install once, every repo gets it:  /plugin install core@compass"
Enter
Sleep 1900ms
