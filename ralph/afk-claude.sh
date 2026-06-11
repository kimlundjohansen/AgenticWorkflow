#!/bin/bash
set -eo pipefail

# Put the script's own bin/ (vendored jq) and ~/bin on PATH, so this works
# regardless of which shell launches the script or how stale its PATH is.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PATH="$SCRIPT_DIR/bin:$HOME/bin:$PATH"

# Resolve a concrete jq binary. On Windows the vendored binary is jq.exe, and
# bash does not reliably append .exe during command lookup in every launch
# context, so probe explicit candidates rather than relying on bare `jq`.
JQ=""
for cand in "$SCRIPT_DIR/bin/jq" "$SCRIPT_DIR/bin/jq.exe" "$HOME/bin/jq" "$HOME/bin/jq.exe" jq jq.exe; do
  if command -v "$cand" >/dev/null 2>&1; then
    JQ="$cand"
    break
  fi
done
if [ -z "$JQ" ]; then
  echo "Error: jq not found (looked in $SCRIPT_DIR/bin, $HOME/bin, and PATH)." >&2
  exit 1
fi

# Resolve a concrete gh binary. This script may be launched from WSL (where gh
# is often NOT installed) as well as Git Bash. Under WSL we can still call the
# Windows GitHub CLI via the /mnt/c interop mount; WSL translates the cwd so
# gh.exe still resolves the repo from the git remote and reuses the Windows
# keyring login. Probe explicit candidates rather than relying on bare `gh`.
GH=""
for cand in \
  gh \
  gh.exe \
  "/mnt/c/Program Files/GitHub CLI/gh.exe" \
  "/c/Program Files/GitHub CLI/gh.exe" \
  "/mnt/c/Program Files (x86)/GitHub CLI/gh.exe" \
  "/c/Program Files (x86)/GitHub CLI/gh.exe"; do
  if command -v "$cand" >/dev/null 2>&1; then
    GH="$cand"
    break
  fi
done
if [ -z "$GH" ]; then
  echo "Error: gh (GitHub CLI) not found in PATH or the standard Windows install location." >&2
  echo "Install it in this environment (e.g. WSL: 'sudo apt install gh') or ensure gh.exe is reachable." >&2
  exit 1
fi

# A stale/invalid GITHUB_TOKEN in the environment overrides gh's keyring login
# and makes every API call 401, which previously surfaced as "No issues found"
# because the gh errors below are swallowed. Drop it so gh falls back to the
# (valid) keyring account. If you genuinely need a token, set GH_TOKEN instead.
unset GITHUB_TOKEN

if [ -z "$1" ]; then
  echo "Usage: $0 <iterations>"
  exit 1
fi

# Validate the iteration count is a positive integer so the loop bound is well
# defined. A non-numeric or empty value would make the arithmetic loop misbehave.
if ! [[ "$1" =~ ^[1-9][0-9]*$ ]]; then
  echo "Error: iterations must be a positive integer (got '$1')." >&2
  exit 1
fi
iterations="$1"

# jq filter to extract streaming text from assistant messages
stream_text='select(.type == "assistant").message.content[]? | select(.type == "text").text // empty | gsub("\n"; "\r\n") | . + "\r\n\n"'

# jq filter to extract final result
final_result='select(.type == "result").result // empty'

# Remove build artifacts the docker sandbox may have left in the mounted repo.
# Directory.Build.props redirects output to /tmp on Linux, but this is a belt-and-
# braces cleanup so a stray Linux-built obj/bin can never reach the Windows host
# (where Visual Studio chokes on the embedded POSIX paths). Only prune obj/bin that
# sit next to a .csproj — this deliberately spares ralph/bin (the vendored jq.exe).
clean_build_artifacts() {
  while IFS= read -r csproj; do
    projdir="$(dirname "$csproj")"
    rm -rf "$projdir/obj" "$projdir/bin"
  done < <(find . -name '*.csproj' -not -path '*/obj/*' -not -path '*/bin/*' 2>/dev/null)
}

for ((i=1; i<=iterations; i++)); do
  echo "=== Ralph iteration $i of $iterations ===" >&2

  tmpfile=$(mktemp)
  trap "rm -f $tmpfile" EXIT

  commits=$(git log -n 5 --format="%H%n%ad%n%B---" --date=short 2>/dev/null || echo "No commits found")
  gh_err=$(mktemp)
  if ! issues=$("$GH" issue list --state open --label afk --limit 50 \
    --json number,title,body,labels \
    --jq '.[] | "## Issue #\(.number): \(.title)\nLabels: \([.labels[].name] | join(", "))\n\n\(.body)\n"' \
    2>"$gh_err"); then
    echo "Error: 'gh issue list' failed (exit $?). gh said:" >&2
    sed 's/^/  gh: /' "$gh_err" >&2
    echo "Diagnostics:" >&2
    echo "  cwd:    $(pwd)" >&2
    echo "  gh bin: $(command -v gh || echo 'NOT FOUND')" >&2
    echo "  remote: $(git remote get-url origin 2>&1)" >&2
    echo "  GH_TOKEN set: $([ -n "$GH_TOKEN" ] && echo yes || echo no); GITHUB_TOKEN set: $([ -n "$GITHUB_TOKEN" ] && echo yes || echo no)" >&2
    echo "  gh used: $GH" >&2
    echo "  --- gh auth status ---" >&2
    "$GH" auth status 2>&1 | sed 's/^/  /' >&2
    rm -f "$gh_err"
    exit 1
  fi
  rm -f "$gh_err"
  if [ -z "$issues" ]; then
    issues="No issues found"
  fi
  prompt=$(cat ralph/prompt.md)

  docker sandbox run claude . -- \
    --verbose \
    --print \
    --output-format stream-json \
    "Previous commits: $commits Issues: $issues $prompt" \
  | grep --line-buffered '^{' \
  | tee "$tmpfile" \
  | "$JQ" --unbuffered -rj "$stream_text" || true

  # Scrub any Linux-built obj/bin the sandbox leaked into the mounted repo.
  clean_build_artifacts

  # The vendored jq is a native Windows binary (jq.exe) and cannot open a
  # Git-Bash POSIX path like /tmp/tmp.XXXX by name. Rather than convert the
  # path (cygpath isn't always present), feed the file to jq on stdin via cat
  # (a POSIX tool that reads /tmp fine). jq reading stdin needs no path at all.
  result=$(cat "$tmpfile" | "$JQ" -r "$final_result")

  rm -f "$tmpfile"

  if [[ "$result" == *"<promise>NO MORE TASKS</promise>"* ]]; then
    echo "Ralph complete after $i iterations."
    exit 0
  fi
done
