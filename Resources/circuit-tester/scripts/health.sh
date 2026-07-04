#!/bin/bash
# SkillSwitch circuit-tester: runtime health check + machine-readable report.
OUT="${PWD}/skillswitch-health-report.txt"
SELF="$(realpath "$0" 2>/dev/null || echo "$0")"
SKILLDIR="$(dirname "$(dirname "$SELF")")"
{
echo "== skillswitch health report v1 =="
date
echo "-- runtime --"
uname -s -m
grep -h PRETTY_NAME /etc/os-release 2>/dev/null || sw_vers -productName 2>/dev/null
echo "sandbox: ${SANDBOX_RUNTIME:-none}"
echo "user: $(whoami)  home: $HOME"
echo "-- skill dir --"
echo "path: $SKILLDIR"
touch "$SKILLDIR/.write-test" 2>/dev/null && { echo "writable: yes"; rm -f "$SKILLDIR/.write-test"; } || echo "writable: no"
ls -a "$SKILLDIR" 2>/dev/null | tr '\n' ' '; echo
echo "-- env names (values masked) --"
env | sort | while IFS='=' read -r k rest; do
  case "$k" in
    *KEY*|*TOKEN*|*SECRET*|*PASSWORD*|*CREDENTIAL*|*AUTH*) echo "$k=<masked-set>";;
    *) echo "$k=$rest";;
  esac
done
echo "-- write tests --"
touch "${TMPDIR:-/tmp}/skillswitch-health" 2>/dev/null && echo "tmp: OK" || echo "tmp: FAILED"
echo "-- tools --"
for t in python3 node git curl jq; do
  printf "%s: " "$t"
  command -v "$t" >/dev/null 2>&1 && "$t" --version 2>&1 | head -1 || echo missing
done
echo "-- network --"
printf "api.github.com: "; curl -s -m 8 -o /dev/null -w '%{http_code}\n' https://api.github.com 2>&1
printf "raw.githubusercontent.com: "; curl -s -m 8 -o /dev/null -w '%{http_code}\n' https://raw.githubusercontent.com 2>&1
printf "www.skills.sh: "; curl -s -m 8 -o /dev/null -w '%{http_code}\n' https://www.skills.sh 2>&1
echo "== end =="
} > "$OUT" 2>&1
cat "$OUT"
echo "report: $OUT"
