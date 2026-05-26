# compass demo — render with:  vhs demo/demo.tape   (or: make demo)
# Punchy + colorful + error-free. Short helpers (demo/_demo.sh) keep the screen clean.

Output demo/preview.gif

Set Shell "zsh"
Set FontSize 24
Set Width 1180
Set Height 640
Set Padding 30
Set Theme "Catppuccin Mocha"
Set TypingSpeed 18ms

Hide
Type "source demo/_demo.sh; setopt interactive_comments 2>/dev/null; PROMPT='%F{141}❯%f '; clear"
Enter
Sleep 300ms
Show

Type "# 🧭 compass — one config, every agent"
Enter
Sleep 700ms

Type "# guardrails: block the catastrophic, allow the rest"
Enter
Type "guard 'rm -rf /'"
Enter
Sleep 700ms
Type "guard 'rm -rf ./build'"
Enter
Sleep 1100ms

Type "statusline"
Enter
Sleep 1500ms

Type "# raise a PR → it reviews & fixes itself → you merge"
Enter
Type "loop"
Enter
Sleep 2600ms

Type "crew"
Enter
Sleep 1600ms

Type "# install once → make install   (or:  /plugin install core@compass)"
Enter
Sleep 2200ms
