#!/usr/bin/env bash
#
# check-consistency.sh - Internal consistency guard for eli5-gate.
#
# The gate's behavior is restated in three places that must agree, plus two
# packaging manifests that must stay well-formed. Nothing else guards them, so
# this script does:
#
#   1. Verdict parity  - the four canonical verdicts (from the eli5-core section
#      of commands/eli5.md) appear, as an exact set, in SKILL.md and README.md.
#   2. Contract phrases - key behavior tokens (the flags, the createdAt anchor,
#      the read-only promise) are restated in SKILL.md, consistent with canonical.
#   3. Marker integrity - commands/eli5.md still carries the eli5-core:begin/:end
#      markers that downstream vendors (claude-power-pack) sync against.
#   4. Manifest validation - plugin.json / marketplace.json parse and carry the
#      required fields, with a plugin name that is consistent across both
#      manifests and the SKILL.md frontmatter.
#
# Fail-open by default (exit 0, warnings only) so it never blocks local work.
# Pass --strict (used by CI) to exit non-zero when any check fails.
#
# Usage: scripts/check-consistency.sh [--strict] [--help]

set -uo pipefail

STRICT=0
for arg in "$@"; do
  case "$arg" in
    --strict) STRICT=1 ;;
    -h|--help)
      # Print only the leading header comment block (skip the shebang, stop at
      # the first non-comment line - not every '#' comment in the file).
      awk 'NR==1 {next} /^#/ {sub(/^# ?/, ""); print; next} {exit}' "$0"
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg (try --help)" >&2
      exit 2
      ;;
  esac
done

# Resolve the repo root from this script's own location (scripts/ sits at the
# repo root), so the guard works no matter what the caller's cwd is.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

CANON="$ROOT/commands/eli5.md"
SKILL="$ROOT/skills/eli5-gate/SKILL.md"
README="$ROOT/README.md"
PLUGIN="$ROOT/.claude-plugin/plugin.json"
MARKET="$ROOT/.claude-plugin/marketplace.json"

FAILURES=0

pass() { printf '  [PASS] %s\n' "$1"; }
warn() { printf '  [WARN] %s\n' "$1"; }
fail() { printf '  [FAIL] %s\n' "$1"; FAILURES=$((FAILURES + 1)); }

# Join newline-separated stdin into a single ", "-delimited line. (paste's -d
# takes a *list* of delimiters used in rotation, so -d', ' alternates comma and
# space - not what we want here.)
join_comma() { paste -sd',' - | sed 's/,/, /g'; }

# Confirm the files we reason about are actually present.
for f in "$CANON" "$SKILL" "$README" "$PLUGIN" "$MARKET"; do
  if [[ ! -f "$f" ]]; then
    fail "expected file missing: ${f#$ROOT/}"
  fi
done

# Extract verdict names from a markdown table whose header's first cell is
# "Verdict". Returns each data row's first cell, stripped of **bold** and
# `code`, one per line, sorted+unique. Works on canonical (bolded) and the
# restatements (plain) alike.
extract_verdicts() {
  awk '
    /^\|[[:space:]]*Verdict[[:space:]]*\|/ { intable = 1; next }
    intable && /^\|[[:space:]]*[-: ]+\|/   { next }          # separator row
    intable && /^\|/ {
      line = $0; sub(/^\|/, "", line)
      cell = substr(line, 1, index(line, "|") - 1)
      gsub(/\*\*/, "", cell); gsub(/`/, "", cell)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", cell)
      if (cell != "") print cell
      next
    }
    intable && !/^\|/ { intable = 0 }                         # table ended
  ' "$1" | sort -u
}

echo "eli5-gate consistency check (${ROOT##*/})"
echo

# ---------------------------------------------------------------------------
echo "1. Verdict parity (canonical -> SKILL.md, README.md)"
CANON_V="$(extract_verdicts "$CANON")"
CANON_N="$(printf '%s\n' "$CANON_V" | grep -c . || true)"
if [[ "$CANON_N" -lt 1 ]]; then
  fail "could not extract any verdicts from commands/eli5.md (guard needs review)"
else
  pass "canonical verdicts ($CANON_N): $(echo "$CANON_V" | join_comma)"
  for target in "SKILL.md:$SKILL" "README.md:$README"; do
    label="${target%%:*}"; file="${target#*:}"
    [[ -f "$file" ]] || continue
    target_v="$(extract_verdicts "$file")"
    missing="$(comm -23 <(printf '%s\n' "$CANON_V") <(printf '%s\n' "$target_v"))"
    extra="$(comm -13 <(printf '%s\n' "$CANON_V") <(printf '%s\n' "$target_v"))"
    if [[ -n "$missing" ]]; then
      fail "$label is missing verdict(s): $(echo "$missing" | join_comma)"
    fi
    if [[ -n "$extra" ]]; then
      fail "$label has verdict(s) not in canonical: $(echo "$extra" | join_comma)"
    fi
    [[ -z "$missing" && -z "$extra" ]] && pass "$label verdict set matches canonical"
  done
fi
echo

# ---------------------------------------------------------------------------
echo "2. Contract phrases (present in canonical AND SKILL.md)"
# Stable tokens that encode the gate's contract. If canonical renames one, the
# check fails on canonical too - a deliberate nudge to update guard + SKILL.md
# together rather than let the summary drift.
CONTRACT_TOKENS=(
  '--yes'
  '--auto-approve'
  'eli5: auto-approve'
  'createdAt'
  'read-only'
)
for tok in "${CONTRACT_TOKENS[@]}"; do
  in_canon=0; in_skill=0
  grep -qF -- "$tok" "$CANON" && in_canon=1
  grep -qF -- "$tok" "$SKILL" && in_skill=1
  if [[ "$in_canon" -eq 1 && "$in_skill" -eq 1 ]]; then
    pass "\"$tok\" present in both"
  elif [[ "$in_canon" -eq 0 ]]; then
    fail "\"$tok\" absent from commands/eli5.md - contract changed; update the guard and SKILL.md"
  else
    fail "\"$tok\" present in canonical but missing from SKILL.md (drift)"
  fi
done
echo

# ---------------------------------------------------------------------------
echo "3. Marker integrity (eli5-core vendor contract)"
# Anchor to ^<!-- so prose mentions of "eli5-core" do not satisfy the check.
if grep -qE '^<!-- eli5-core:begin' "$CANON" && grep -qE '^<!-- eli5-core:end' "$CANON"; then
  pass "commands/eli5.md carries eli5-core:begin and eli5-core:end markers"
else
  fail "commands/eli5.md is missing an eli5-core marker (breaks the CPP vendor sync)"
fi
echo

# ---------------------------------------------------------------------------
echo "4. Manifest validation (plugin.json, marketplace.json)"
# The SKILL.md frontmatter name is cross-checked against the manifests.
SKILL_NAME="$(awk -F': *' '/^name:/{print $2; exit}' "$SKILL" | tr -d '[:space:]')"
if command -v python3 >/dev/null 2>&1; then
  if python3 - "$PLUGIN" "$MARKET" "$SKILL_NAME" <<'PY'
import json, sys

plugin_path, market_path, skill_name = sys.argv[1], sys.argv[2], sys.argv[3]
failures = 0

def load(path):
    global failures
    try:
        with open(path) as fh:
            return json.load(fh)
    except FileNotFoundError:
        print(f"  [FAIL] {path.split('/')[-1]} not found"); failures += 1
    except json.JSONDecodeError as exc:
        print(f"  [FAIL] {path.split('/')[-1]} is not valid JSON: {exc}"); failures += 1
    return None

def require(obj, key, where, typ=None):
    global failures
    if not isinstance(obj, dict) or key not in obj or obj[key] in (None, "", [], {}):
        print(f"  [FAIL] {where}: missing/empty required field '{key}'"); failures += 1
        return None
    if typ is not None and not isinstance(obj[key], typ):
        print(f"  [FAIL] {where}: field '{key}' must be {typ.__name__}"); failures += 1
        return None
    return obj[key]

plugin = load(plugin_path)
market = load(market_path)

plugin_name = None
if plugin is not None:
    for key in ("name", "description", "version", "author", "license"):
        require(plugin, key, "plugin.json")
    author = plugin.get("author")
    if isinstance(author, dict):
        require(author, "name", "plugin.json.author")
    elif author is not None:
        print("  [FAIL] plugin.json: 'author' must be an object with a name"); failures += 1
    plugin_name = plugin.get("name")
    if failures == 0:
        print(f"  [PASS] plugin.json parses with required fields (name={plugin_name!r})")

market_names = []
if market is not None:
    require(market, "name", "marketplace.json")
    owner = require(market, "owner", "marketplace.json")
    if isinstance(owner, dict):
        require(owner, "name", "marketplace.json.owner")
    plugins = require(market, "plugins", "marketplace.json", list)
    if isinstance(plugins, list):
        for i, p in enumerate(plugins):
            where = f"marketplace.json.plugins[{i}]"
            for key in ("name", "source", "description"):
                require(p, key, where)
            if isinstance(p, dict) and p.get("name"):
                market_names.append(p["name"])
    if market.get("name") and plugin_name and market["name"] != "eli5-gate":
        print(f"  [FAIL] marketplace.json name {market['name']!r} != 'eli5-gate'"); failures += 1

# Cross-manifest + skill name consistency.
names = {n for n in ([plugin_name] + market_names + [skill_name]) if n}
if len(names) > 1:
    print(f"  [FAIL] plugin name is inconsistent across manifests/SKILL.md: {sorted(names)}"); failures += 1
elif names:
    print(f"  [PASS] plugin name consistent across manifests + SKILL.md: {names.pop()!r}")

sys.exit(1 if failures else 0)
PY
  then
    : # python printed its own PASS lines
  else
    FAILURES=$((FAILURES + 1))
  fi
else
  warn "python3 not found - skipping JSON manifest validation (install python3 to enable)"
fi
echo

# ---------------------------------------------------------------------------
if [[ "$FAILURES" -eq 0 ]]; then
  echo "All consistency checks passed."
  exit 0
fi

echo "$FAILURES consistency check(s) failed."
if [[ "$STRICT" -eq 1 ]]; then
  echo "(--strict) exiting non-zero."
  exit 1
fi
echo "(fail-open) exiting 0 - re-run with --strict in CI to make this blocking."
exit 0
