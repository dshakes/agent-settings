#!/usr/bin/env bash
# _loop.sh — replays the REAL autonomous-loop run on PR #4 of dshakes/compass-sdlc-smoketest:
# real PR number, real check transitions (red → green), the real Builder fix commit (737d589),
# and the real label changes. A faithful terminal capture of the validated run — sourced by
# demo/loop.tape to render assets/loop.gif. (For a GitHub-UI screencast, see sdlc/SMOKETEST.md.)
R=$'\033[31m'; G=$'\033[32m'; Y=$'\033[33m'; P=$'\033[35m'; B=$'\033[1m'; D=$'\033[2m'; C=$'\033[38;5;39m'; X=$'\033[0m'

open() {
  printf "  %byou push a PR%b   %bPR #4 · smoke: add Sub (buggy)%b\n" "$B" "$X" "$D" "$X"
  printf "  %b▶ runs automatically:%b  Reviewer · Security · QA · %bCodex audit%b\n" "$C" "$X" "$P" "$X"
}
red() {
  printf "\n  %bgh pr checks 4%b\n" "$D" "$X"
  printf "    review    %b●  fail%b    Reviewer verdict: %bBLOCKING%b\n" "$R" "$X" "$R" "$X"
  printf "    qa        %b●  fail%b    TestSub(5,3) = 8, want 2\n" "$R" "$X"
  printf "    %bCodex audit:%b Sub returns a+b instead of a-b\n" "$P" "$X"
  printf "    %b+ label agent:needs-fix%b\n" "$R" "$X"
}
fix() {
  printf "\n  %b↻ sdlc-fix%b  the Builder fixes it on the PR branch + pushes\n" "$Y" "$X"
  printf "    %b●  737d589%b  fix: correct Sub to return a - b instead of a + b\n" "$G" "$X"
  printf "    %bthe push re-triggers the Reviewer…%b\n" "$D" "$X"
}
green() {
  printf "\n  %bgh pr checks 4%b\n" "$D" "$X"
  printf "    review    %b●  pass%b    re-review: %bCLEAN%b\n" "$G" "$X" "$G" "$X"
  printf "    qa        %b●  pass%b\n" "$G" "$X"
  printf "    %b+ label agent:reviewed-clean%b\n" "$G" "$X"
}
gate() {
  printf "\n  %b✓ mergeable%b — awaiting a code-owner approval   %b(you merge — always)%b\n" "$G$B" "$X" "$D" "$X"
}
