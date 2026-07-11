#!/usr/bin/env bash
#
# Plexus reqlist generator — § 10.4 PLX. A verb, not a system:
#
#   scan PLX.md → one entry per keyword-bearing line → PLX-reqlist.md
#
# Line-based extraction leans on a source convention: PLX.md keeps each
# statement on one source line (no mid-sentence hard wraps), so a keyword-
# bearing line is always a complete requirement, never a fragment.
#
# The keyword and the section anchor are *derived* — that part can never
# disagree with the source. The conformance class is NOT derivable by grep:
# it follows the § 10.2 ownership rule, carried below as an explicit
# section→class mapping (seeded from the § 10.2 table, reviewed like any
# other code); a hit the mapping cannot place is listed *unclassified*,
# never guessed.
#
# Degradation test — hand-runnable with no extra machinery:
#   ./plexus/generate-reqlist.sh            # regenerate PLX-reqlist.md
#   ./plexus/generate-reqlist.sh --check    # exit non-zero if it is stale
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$SCRIPT_DIR/PLX.md"
OUT="$SCRIPT_DIR/PLX-reqlist.md"

generate() {
  awk '
    BEGIN {
      # § 10.2 ownership rule as an explicit section→class mapping (the seed;
      # review like code). Lookup: exact subsection first, then parent section;
      # no match → unclassified. Subsections inherit unless listed (6.1 → 6).
      class["4.2"]  = "tenant-monorepo, tenant-platform"                    # partitioning/labels vs licensing/disclosure
      class["4.3"]  = "tenant-monorepo"                                     # repo & namespace layout
      class["5"]    = "app, tenant-monorepo, standard-repo"                 # intro binds every Plexus repo
      class["5.1"]  = "app, tenant-monorepo"                                # toolchain
      class["5.2"]  = "standard-repo"                                       # publishing mechanics
      class["5.3"]  = "tenant-monorepo, standard-repo"                      # library rules bind maintainers, app rules bind tenants
      class["5.4"]  = "tenant-monorepo"                                     # deploy granularity
      class["6"]    = "app"                                                 # the contract (6.1, 6.2 inherit)
      class["7"]    = "tenant-platform, standard-repo"                      # ops side vs verb safety baseline/layering (7.x inherit)
      class["8"]    = "tenant-monorepo, standard-repo"                      # update-bot policy vs propagation machinery
      class["10"]   = "app, tenant-monorepo, tenant-platform, standard-repo" # marker/conformance bind every conforming repo
      class["10.4"] = "standard-repo"                                       # the reqlist obligation itself
      # § 9 (deferred decisions) intentionally unmapped → unclassified, per
      # the § 10.1 v1.0 bar: deferrals resolve before unclassified reaches zero.
    }

    # Frontmatter: read version + timestamp, emit nothing.
    NR == 1 && /^---$/ { infm = 1; next }
    infm {
      if ($0 ~ /^---$/) infm = 0
      else if ($1 == "version:") version = $2
      else if ($1 == "timestamp:") timestamp = $2
      next
    }

    # Fenced code blocks are never requirements (e.g. the § 10.3 marker template).
    /^```/ { incode = !incode; next }
    incode { next }

    # The normative body starts at § 1; Abstract and Preamble are interpretive.
    /^## § 1 / { started = 1 }
    !started { next }

    # Headings: a §-numbered heading sets the current section; a bare ###
    # (e.g. "The dependency-mechanics rule") stays inside the enclosing section.
    /^#/ {
      if ($0 ~ /§ [0-9]/) {
        heading = $0; sub(/^#+ +/, "", heading)
        sec = $0; sub(/^.*§ +/, "", sec); sub(/ .*$/, "", sec)
      }
      next
    }

    {
      # Count keywords; strip the NOT-forms first so MUST/SHOULD do not double-count.
      # BCP 14 binds keywords only "as shown here, in all capitals" (preamble):
      # informal plurals ("MUSTs") are prose, not requirements — neutralized first.
      tmp = $0
      gsub(/MUSTs/, "", tmp); gsub(/SHOULDs/, "", tmp); gsub(/MAYs/, "", tmp)
      nMN = gsub(/MUST NOT/, "", tmp);   nSN = gsub(/SHOULD NOT/, "", tmp)
      nM  = gsub(/MUST/, "", tmp);       nS  = gsub(/SHOULD/, "", tmp)
      nMY = gsub(/MAY/, "", tmp)
      if (nMN + nSN + nM + nS + nMY == 0) next
      cMN += nMN; cSN += nSN; cM += nM; cS += nS; cMY += nMY

      kws = ""
      if (nM)  kws = kws (kws ? ", " : "") "MUST"
      if (nMN) kws = kws (kws ? ", " : "") "MUST NOT"
      if (nS)  kws = kws (kws ? ", " : "") "SHOULD"
      if (nSN) kws = kws (kws ? ", " : "") "SHOULD NOT"
      if (nMY) kws = kws (kws ? ", " : "") "MAY"

      # The requirement text, verbatim minus list/quote markers.
      t = $0
      sub(/^[ \t]+/, "", t); sub(/^> /, "", t)
      sub(/^- /, "", t); sub(/^[0-9]+\. /, "", t)

      # § 10.2 ownership lookup: exact subsection, then parent, else unclassified.
      c = ""
      if (sec in class) c = class[sec]
      else { p = sec; sub(/\..*$/, "", p); if (p in class) c = class[p] }

      entries++
      if (c == "") {
        uncls[++nu] = "- **" kws "** [§ " sec "] — " t
      } else {
        if (heading != lastheading) {
          out[++no] = ""
          out[++no] = "## " heading
          out[++no] = "*" (c ~ /,/ ? "Classes" : "Class") ": " c "*"
          out[++no] = ""
          lastheading = heading
        }
        out[++no] = "- **" kws "** — " t
      }
    }

    END {
      print "# PLX Requirements List (reqlist)"
      print ""
      print "> **GENERATED** from `PLX.md` " version " (" timestamp ") by `generate-reqlist.sh` — do not edit (§ 10.4)."
      print ""
      printf "%d entries: %d MUST · %d MUST NOT · %d SHOULD · %d SHOULD NOT · %d MAY · %d unclassified.\n", \
        entries, cM, cMN, cS, cSN, cMY, nu
      for (i = 1; i <= no; i++) print out[i]
      if (nu) {
        print ""
        print "## Unclassified"
        print ""
        print "*Hits the section→class mapping cannot place — listed, never guessed (§ 10.4).*"
        print ""
        for (i = 1; i <= nu; i++) print uncls[i]
      }
    }
  ' "$SRC"
}

if [[ "${1:-}" == "--check" ]]; then
  tmp="$(mktemp "${TMPDIR:-/tmp}/PLX-reqlist.XXXXXX")"
  trap 'rm -f "$tmp"' EXIT
  generate > "$tmp"
  if ! diff -u "$OUT" "$tmp"; then
    echo "✗ PLX-reqlist.md is stale — run plexus/generate-reqlist.sh" >&2
    exit 1
  fi
  echo "✓ PLX-reqlist.md is current"
else
  generate > "$OUT"
  echo "✓ wrote ${OUT#"$SCRIPT_DIR"/} from ${SRC#"$SCRIPT_DIR"/}"
fi
