# loop.tape — render the autonomous-loop capture:  vhs demo/loop.tape  → assets/loop.gif
# Faithful replay of the REAL run on PR #4 (real checks, fix commit 737d589, labels).
Output assets/loop.gif

Set Shell "zsh"
Set FontSize 24
Set Width 1200
Set Height 680
Set Padding 40
Set Theme "Catppuccin Mocha"
Set TypingSpeed 30ms
Set LineHeight 1.4

Hide
Type "source demo/_loop.sh; setopt interactive_comments 2>/dev/null; PROMPT='%F{141}❯%f '; clear"
Enter
Sleep 300ms
Show

Type "# 🧭 compass · autonomous PR loop — real run on PR #4"
Enter
Sleep 1400ms
Type "open"
Enter
Sleep 2200ms
Type "red"
Enter
Sleep 3000ms
Type "fix"
Enter
Sleep 3000ms
Type "green"
Enter
Sleep 2400ms
Type "gate"
Enter
Sleep 3000ms
