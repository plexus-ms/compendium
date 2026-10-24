#!/usr/bin/env bash
#
# Plexus requirements check — a verb, not a system:
#
#   check    lint the map (standard.md) and every module page (contracts/*.md, approaches/*.md)
#   extract  print one module's requirement lines, for ship's `changed` comparator
#
# The map carries no requirements and no BCP 14 keyword. A module at standard
# maturity carries its requirements as blockquoted bullets ("> - ") under
# numbered section headings; a keyword anywhere else, a blockquote that is not
# such a bullet, or any keyword or blockquote in a module below standard
# maturity fails the run. The trailing "## Maintaining" section of a module is
# prose throughout. Extraction is structural: no classification, no heuristics.
#
# Degradation test — hand-runnable with no extra machinery:
#   ./plexus/requirements.sh                       # same as --check
#   ./plexus/requirements.sh --check               # exit non-zero on any defect
#   ./plexus/requirements.sh --extract contracts/app.md
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MAP="$SCRIPT_DIR/standard.md"
CONTRACTS="$ROOT/contracts"
APPROACHES="$ROOT/approaches"

# scan <mode> <file>: mode is "map", "module", or "extract". The index.md of
# each folder is a table of contents, not a module, and is skipped.
# Prints "✗ <file>: line N: ..." defects to stderr and exits 1 if any; in
# extract mode prints the requirement lines of a standard module to stdout.
scan() {
  local mode="$1" file="$2"
  awk -v mode="$mode" -v name="${file#"$ROOT"/}" '
    function defect(msg) { err[++ne] = "✗ " name ": line " NR ": " msg }
    function haskw(s,   t) {
      t = s
      gsub(/MUSTs|SHOULDs|MAYs/, "", t)      # informal plurals are prose
      return t ~ /MUST|SHOULD|MAY/
    }

    # Frontmatter: collect the module fields, emit nothing.
    NR == 1 && /^---$/ { infm = 1; next }
    infm {
      if ($0 ~ /^---$/) infm = 0
      else if ($1 == "maturity:") maturity = $2
      else if ($1 == "code:") code = $2
      else if ($1 == "kind:") defect("kind is the folder, contracts/ or approaches/, not a field")
      else if ($1 == "binds:") binds = $2
      next
    }

    # Fenced code blocks are never requirements (figures, templates, examples).
    /^```/ { incode = !incode; next }
    incode { next }

    /^## Maintaining$/ { maintaining = 1; section = ""; next }

    # A §-numbered heading names the section the next requirements belong to.
    /^#+ § / {
      if (maintaining) defect("numbered section after Maintaining")
      section = $0; sub(/^#+ +§ +/, "", section); sub(/ .*/, "", section)
      started = 1
      next
    }

    /^> - / {
      if (mode == "map") { defect("requirement in the map: " $0); next }
      if (maturity != "standard") { defect("requirement in a module at " maturity " maturity: " $0); next }
      if (maintaining) { defect("requirement under Maintaining: " $0); next }
      if (!started) { defect("requirement before the first § heading"); next }
      t = $0; sub(/^> - /, "", t)
      out[++no] = "§ " section " " t
      next
    }

    /^>/ { defect("blockquote line is not a \"> - \" requirement bullet"); next }

    # Everything else is prose: no BCP 14 keyword may appear here.
    haskw($0) { defect("BCP 14 keyword outside a requirement: " $0) }

    END {
      if (mode == "module") {
        if (maturity !~ /^(note|candidate|standard)$/) defect("maturity must be note, candidate or standard, not \"" maturity "\"")
        if (binds !~ /^(repo|app|host|organisation)$/) defect("binds must be repo, app, host or organisation, not \"" binds "\"")
        if (maturity == "note" && code != "") defect("a note carries no code")
        if (maturity != "note" && code !~ /^PLX-[A-Z][A-Za-z]+$/) defect("code must be PLX- plus one capitalised word, not \"" code "\"")
      }
      if (ne) {
        for (i = 1; i <= ne; i++) print err[i] > "/dev/stderr"
        exit 1
      }
      if (mode == "extract") for (i = 1; i <= no; i++) print out[i]
    }
  ' "$file"
}

case "${1:---check}" in
  --check)
    status=0
    scan map "$MAP" || status=1
    for page in "$CONTRACTS"/*.md "$APPROACHES"/*.md; do
      [[ "$page" == */index.md ]] && continue
      scan module "$page" || status=1
    done
    # Module codes are unique across pages.
    dup="$(grep -h '^code: ' "$CONTRACTS"/*.md "$APPROACHES"/*.md | sort | uniq -d || true)"
    if [[ -n "$dup" ]]; then
      echo "✗ duplicate module code: $dup" >&2
      status=1
    fi
    # Every declared dependency names a module that exists.
    codes="$(grep -h '^code: ' "$CONTRACTS"/*.md "$APPROACHES"/*.md | cut -d' ' -f2)"
    read -ra deps <<<"$(grep -h '^depends: ' "$CONTRACTS"/*.md "$APPROACHES"/*.md | sed 's/^depends: *\[//; s/\]//; s/,/ /g' | tr '\n' ' ')"
    for dep in "${deps[@]}"; do
      if ! grep -qx "$dep" <<<"$codes"; then
        echo "✗ unknown module in depends: $dep" >&2
        status=1
      fi
    done
    # Dependencies respect the seams (§ 1.3 PLX): a contract depends only on
    # contracts, and a dependency that crosses from the dev side (repo, app) to
    # the ops side (host, organisation), or back, targets a contract.
    awk '
      function side(b) { return (b == "repo" || b == "app") ? "dev" : "ops" }
      FNR == 1 { key = FILENAME; sub(/.*\//, "", key); binds = ""; deps = ""; kind = (FILENAME ~ /\/contracts\//) ? "contract" : "approach" }
      FNR == 1 && /^---$/ { infm = 1; next }
      infm && /^---$/ { infm = 0; K[key] = kind; B[key] = binds; D[key] = deps; nextfile }
      infm && $1 == "code:" { key = $2 }
      infm && $1 == "binds:" { binds = $2 }
      infm && $1 == "depends:" { deps = $0; sub(/^depends: *\[/, "", deps); sub(/\].*/, "", deps); gsub(/,/, " ", deps) }
      END {
        for (m in K) {
          n = split(D[m], d, " ")
          for (i = 1; i <= n; i++) {
            if (!(d[i] in K)) continue
            if (K[m] == "contract" && K[d[i]] != "contract") { print "✗ " m " is a contract and depends on the approach " d[i] > "/dev/stderr"; bad = 1 }
            if (side(B[m]) != side(B[d[i]]) && K[d[i]] != "contract") { print "✗ " m " (" B[m] ") depends on " d[i] " (" B[d[i]] ") across the dev/ops seam; only a contract may be depended on across a seam" > "/dev/stderr"; bad = 1 }
          }
        }
        exit bad
      }
    ' "$CONTRACTS"/*.md "$APPROACHES"/*.md || status=1
    if [[ $status -eq 0 ]]; then
      contracts=("$CONTRACTS"/*.md); approaches=("$APPROACHES"/*.md)
      echo "✓ the map, $(( ${#contracts[@]} - 1 )) contracts and $(( ${#approaches[@]} - 1 )) approaches are well-formed"
    fi
    exit $status
    ;;
  --extract)
    [[ -n "${2:-}" ]] || { echo "usage: $0 --extract <module page>" >&2; exit 2; }
    scan extract "$2"
    ;;
  *)
    echo "usage: $0 [--check | --extract <module page>]" >&2
    exit 2
    ;;
esac
