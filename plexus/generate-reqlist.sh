#!/usr/bin/env bash
#
# Plexus reqlist generator — a verb, not a system:
#
#   scan standard.md → headings + "> - " requirement lines → standard-reqlist.md
#
# The standard carries its requirements as blockquoted bullets under section
# headings, so extraction is structural: no classification, no
# heuristics. The same pass lints the convention — a BCP 14 keyword found
# outside a blockquote, or a malformed blockquote line, fails the run.
#
# Degradation test — hand-runnable with no extra machinery:
#   ./plexus/generate-reqlist.sh            # regenerate standard-reqlist.md
#   ./plexus/generate-reqlist.sh --check    # exit non-zero if it is stale
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$SCRIPT_DIR/standard.md"
OUT="$SCRIPT_DIR/standard-reqlist.md"

generate() {
  awk '
    # Frontmatter: read version + timestamp, emit nothing.
    NR == 1 && /^---$/ { infm = 1; next }
    infm {
      if ($0 ~ /^---$/) infm = 0
      else if ($1 == "version:") version = $2
      else if ($1 == "timestamp:") timestamp = $2
      next
    }

    # Fenced code blocks are never requirements (figures, templates, examples).
    /^```/ { incode = !incode; next }
    incode { next }

    # A §-numbered heading updates the section stack at its nesting level;
    # deeper stack entries are cleared so the stack always mirrors the tree.
    /^#+ § / {
      started = 1
      level = 0
      while (substr($0, level + 1, 1) == "#") level++
      h = $0; sub(/^#+ +/, "", h)
      for (l = level; l <= 6; l++) { head[l] = ""; printed[l] = 0 }
      head[level] = h
      next
    }

    # Requirement lines: blockquoted bullets under the current section.
    # Not-yet-printed ancestor headings are emitted first, at their own
    # levels, so the reqlist mirrors the standard\047s heading nesting.
    /^> - / {
      if (!started) {
        err[++ne] = "line " NR ": requirement before the first § heading"
        next
      }
      t = $0; sub(/^> - /, "", t)
      emitted = 0
      for (l = 2; l <= 6; l++) {
        if (head[l] != "" && !printed[l]) {
          hashes = ""
          for (i = 1; i <= l; i++) hashes = hashes "#"
          out[++no] = ""
          out[++no] = hashes " " head[l]
          printed[l] = 1
          emitted = 1
        }
      }
      if (emitted) out[++no] = ""
      out[++no] = "- " t
      next
    }

    # Any other blockquote line breaks the one-bullet-per-line convention.
    /^>/ {
      err[++ne] = "line " NR ": blockquote line is not a \"> - \" requirement bullet"
      next
    }

    # Everything else is informative prose — no BCP 14 keyword may appear here.
    {
      tmp = $0
      # Informal plurals ("MUSTs") are prose, not keywords
      gsub(/MUSTs/, "", tmp); gsub(/SHOULDs/, "", tmp); gsub(/MAYs/, "", tmp)
      if (tmp ~ /MUST|SHOULD|MAY/)
        err[++ne] = "line " NR ": BCP 14 keyword outside a blockquote: " $0
    }

    END {
      if (ne) {
        for (i = 1; i <= ne; i++) print "✗ " err[i] > "/dev/stderr"
        exit 1
      }
      print "---"
      print "title: The Plexus Standard Requirements List (PLX Reqlist)"
      print "short_title: 2. Standard Reqlist"
      print "description: Condensed requirements list extracted from the Plexus Standard."
      print "version: " version
      print "timestamp: " timestamp
      print "note: Auto-generated from `standard.md` " version " (" timestamp ") by `generate-reqlist.sh` — do not edit."
      print "order: 2"
      print "---"
      for (i = 1; i <= no; i++) print out[i]
    }
  ' "$SRC"
}

tmp="$(mktemp "${TMPDIR:-/tmp}/standard-reqlist.XXXXXX")"
trap 'rm -f "$tmp"' EXIT
generate > "$tmp"

if [[ "${1:-}" == "--check" ]]; then
  if ! diff -u "$OUT" "$tmp"; then
    echo "✗ standard-reqlist.md is stale — run plexus/generate-reqlist.sh" >&2
    exit 1
  fi
  echo "✓ standard-reqlist.md is current"
else
  mv "$tmp" "$OUT"
  trap - EXIT
  echo "✓ wrote ${OUT#"$SCRIPT_DIR"/} from ${SRC#"$SCRIPT_DIR"/}"
fi
