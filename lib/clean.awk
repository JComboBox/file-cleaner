# clean.awk — remove headers, marked snippets, and pattern lines from a file.
#
# All parameters arrive through the environment (ENVIRON) rather than -v so
# that regex backslashes are passed through untouched:
#   FC_AWK_LINE_COMMENT   ERE matching a line comment, e.g. ^[[:space:]]*#
#   FC_AWK_BLOCK_START    ERE matching a block comment opener, e.g. ^[[:space:]]*/\*
#   FC_AWK_BLOCK_END      ERE matching a block comment closer, e.g. \*/
#   FC_AWK_KEEP           ERE for leading lines that must survive (shebang, <?xml ...>)
#   FC_AWK_HEADER_PATTERN lowercase ERE; the leading comment is removed only if it matches
#   FC_AWK_SNIPPET_BEGIN  literal marker opening a block to delete (inclusive)
#   FC_AWK_SNIPPET_END    literal marker closing that block
#   FC_AWK_PATTERN_FILE   optional file of EREs, one per line; matching lines are deleted
#
# Exit status: 0 on success, 2 on an unterminated snippet block.

function blank(s) { return s ~ /^[[:space:]]*$/ }

BEGIN {
  lc   = ENVIRON["FC_AWK_LINE_COMMENT"]
  bs   = ENVIRON["FC_AWK_BLOCK_START"]
  be   = ENVIRON["FC_AWK_BLOCK_END"]
  keep = ENVIRON["FC_AWK_KEEP"]
  hpat = ENVIRON["FC_AWK_HEADER_PATTERN"]
  sbeg = ENVIRON["FC_AWK_SNIPPET_BEGIN"]
  send = ENVIRON["FC_AWK_SNIPPET_END"]
  pfile = ENVIRON["FC_AWK_PATTERN_FILE"]

  npat = 0
  if (pfile != "") {
    while ((getline p < pfile) > 0) {
      if (p ~ /^[[:space:]]*#/ || blank(p)) continue
      pats[++npat] = p
    }
    close(pfile)
  }
}

{ raw[NR] = $0 }

END {
  # Pass 1: drop marked snippet blocks and pattern-matched lines.
  n = 0; in_snip = 0
  for (i = 1; i <= NR; i++) {
    line = raw[i]
    if (!in_snip && sbeg != "" && index(line, sbeg)) { in_snip = i; continue }
    if (in_snip) { if (send != "" && index(line, send)) in_snip = 0; continue }
    drop = 0
    for (k = 1; k <= npat; k++) if (line ~ pats[k]) { drop = 1; break }
    if (!drop) out[++n] = line
  }
  if (in_snip) {
    printf "unterminated snippet block starting at line %d\n", in_snip > "/dev/stderr"
    exit 2
  }

  # Pass 2: the leading comment block is the header candidate.
  i = 1
  while (keep != "" && i <= n && out[i] ~ keep) { print out[i]; i++ }
  kept = i - 1

  j = i
  while (j <= n && blank(out[j])) j++
  hs = j; he = 0
  if (j <= n) {
    if (bs != "" && out[j] ~ bs) {
      k = j
      # A one-line block ("/* x */") closes on its own line.
      rest = out[k]; sub(bs, "", rest)
      if (rest !~ be) { k++; while (k <= n && out[k] !~ be) k++ }
      if (k <= n) he = k
    } else if (lc != "" && out[j] ~ lc) {
      k = j
      while (k + 1 <= n && out[k + 1] ~ lc) k++
      he = k
    }
  }

  start = i
  if (he && hpat != "") {
    text = ""
    for (m = hs; m <= he; m++) text = text "\n" tolower(out[m])
    if (text ~ hpat) {
      start = he + 1
      while (start <= n && blank(out[start])) start++
      # Keep one blank line between a preserved shebang and the code.
      if (kept && start <= n) print ""
    }
  }

  for (m = start; m <= n; m++) print out[m]
}
