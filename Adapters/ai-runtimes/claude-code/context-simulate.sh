#!/usr/bin/env bash
# IA Engineering — context-simulate.sh (Claude Code runtime)
#
# Replays the Main Agent's measured context occupancy under a compaction
# threshold T, and prints what each T would have cost. It reads only the
# numbers-only records of `usage-collect.sh --context-series` (WU-IAENG-374);
# Governance/CONTEXT_COMPACTION_MEASUREMENT.md is the report built with it.
#
# THE MODEL, AND WHAT IT ASSUMES
#
# A session's calls are replayed in order. Each call adds to the simulated
# occupancy what it added to the real one (its occupancy minus the previous
# call's). The call right after a REAL compaction adds nothing: in the
# simulated world the threshold fired earlier, so the real compaction does
# not happen. A real fall that is not a compaction (a rewind) is kept, but
# never below the post-compaction level. When the simulated occupancy reaches
# T percent of the window, a compaction happens: the occupancy becomes the
# post-compaction level P, and the summary request is charged.
#
# Cost is in units of the model's input-token price, so it holds for any
# model whose multipliers are the ones given:
#
#   a call       its simulated occupancy times the call's REAL blended rate,
#                (input + 1.25 cache_creation + R cache_read) / occupancy,
#                so a real cache miss stays a miss; right after a simulated
#                compaction, the whole occupancy is written: 1.25 per token
#   a compaction R times the occupancy summarised (read from the cache) plus
#                O times the summary written, taken as S, the median
#                postTokens of the real compactions (an upper bound: it also
#                counts the system prompt and the tools)
#   default      the real calls at their real costs, plus each real
#                compaction's summary request priced the same way
#
# R is the cache-read multiplier, O the output one. Output tokens of ordinary
# calls are the same under every T; they are reported apart, so a saving can
# be read against the context cost alone or against the whole bill.
#
# A long session is one whose peak occupancy reached --long-min tokens: the
# only sessions a threshold of 30 % or more of a 1M window changes.
#
# The interval is a percentile bootstrap over SESSIONS (a session's calls are
# not independent of each other): --reps resamples with replacement, the
# saving recomputed on each, 2.5th and 97.5th percentiles. With few long
# sessions it is wide, and that width is the finding, not a defect. awk's
# rand() differs between implementations, so the interval's last digit
# depends on the awk; --seed fixes it for one awk.
#
# USAGE
#
#   context-simulate.sh [--window N] [--post N] [--post-scale X]
#                       [--cache-read X] [--output X] [--long-min N]
#                       [--reps N] [--seed N] [--thresholds LIST] [FILE...]
#
#   --window      the context window, tokens (default 1000000)
#   --post        P, tokens; default: the median occupancy of the first call
#                 after the real compactions in the input
#   --post-scale  multiplies P (sensitivity; default 1)
#   --cache-read  R (default 0.05: Claude Opus 5.5, $0.20 against $4 input)
#   --output      O (default 5: Claude Opus 5.5, $20 against $4)
#   --long-min    tokens (default 300000)
#   --reps        bootstrap resamples (default 2000)
#   --seed        (default 374)
#   --thresholds  the T to simulate, percentages 1 to 99 separated by
#                 commas (default 30,40,50,60,70,80)
#
# OUTPUT (tab-separated)
#
#   sim-input  <sessions> <long-sessions> <calls> <active-days> <weeks> <real-compactions> <P> <S> <output-cost>
#   sim        <T> <compactions> <context-tokens> <context-cost> <compaction-cost> <compactions-per-day>
#              <in-flight-compactions-per-week> <saving-%> <ci-low-%> <ci-high-%> <saving-of-bill-%>
#
# T is a percentage, or "default" for the sessions as they ran. Exit 0, 1 on
# input with no ctx-call record, 2 on a usage error.

set -uo pipefail

err() { printf 'context-simulate: ERROR: %s\n' "$1" >&2; }
usage() {
  echo "Usage: $0 [--window N] [--post N] [--post-scale X] [--cache-read X] [--output X] [--long-min N] [--reps N] [--seed N] [--thresholds LIST] [FILE...]" >&2
}

WINDOW=1000000
POST=""
POST_SCALE=1
CACHE_READ=0.05
OUTPUT_MULT=5
LONG_MIN=300000
REPS=2000
SEED=374
THRESHOLDS="30,40,50,60,70,80"
FILES=()
int_arg() { [[ "$2" =~ ^[0-9]{1,9}$ ]] || { err "$1 takes a whole number, not '$2'."; exit 2; }; }
dec_arg() { [[ "$2" =~ ^[0-9]{1,3}(\.[0-9]{1,6})?$ ]] || { err "$1 takes a decimal number, not '$2'."; exit 2; }; }
while [ "$#" -gt 0 ]; do
  case "$1" in
    --window|--post|--long-min|--reps|--seed)
      [ "$#" -ge 2 ] || { usage; exit 2; }; int_arg "$1" "$2"
      case "$1" in
        --window) WINDOW="$2" ;; --post) POST="$2" ;; --long-min) LONG_MIN="$2" ;;
        --reps) REPS="$2" ;; --seed) SEED="$2" ;;
      esac
      shift 2 ;;
    --post-scale|--cache-read|--output)
      [ "$#" -ge 2 ] || { usage; exit 2; }; dec_arg "$1" "$2"
      case "$1" in
        --post-scale) POST_SCALE="$2" ;; --cache-read) CACHE_READ="$2" ;; --output) OUTPUT_MULT="$2" ;;
      esac
      shift 2 ;;
    --thresholds)
      [ "$#" -ge 2 ] || { usage; exit 2; }
      [[ "$2" =~ ^[1-9][0-9]?(,[1-9][0-9]?)*$ ]] || { err "--thresholds takes percentages 1 to 99 separated by commas, not '$2'."; exit 2; }
      THRESHOLDS="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    -*) err "unknown argument '$1'"; usage; exit 2 ;;
    *) FILES+=("$1"); shift ;;
  esac
done
[ "$WINDOW" -gt 0 ] || { err "--window must be positive."; exit 2; }

awk -F '\t' -v W="$WINDOW" -v PFIX="$POST" -v PSCALE="$POST_SCALE" -v R="$CACHE_READ" \
    -v O="$OUTPUT_MULT" -v LMIN="$LONG_MIN" -v REPS="$REPS" -v SEED="$SEED" -v TLIST="$THRESHOLDS" '
  function num(s) { return (s ~ /^[0-9]+$/) ? s + 0 : 0 }
  { sub(/\r$/, "") }
  # Records are filed under their session. A session found in two inputs (one
  # transcript file under two project directories, as after a project is
  # moved) is one session: a call is filed by its sequence number, and one
  # already filed is skipped. A shorter copy is a prefix of the longer one
  # (measured), so the union is the longer copy.
  $1 == "ctx-call" && NF >= 9 && $3 ~ /^[1-9][0-9]*$/ {
    s = $2
    if (!(s in sid)) { sid[s] = ++ns; key[ns] = s }
    i = sid[s]; k = $3 + 0
    if ((i, k) in t) next
    if (k > n[i]) n[i] = k
    t[i, k] = num($4); occ[i, k] = num($5); in_[i, k] = num($6); cc[i, k] = num($7); cr[i, k] = num($8)
    out[i, k] = num($9); infl[i, k] = (NF >= 10) ? num($10) : 0
    day[int(t[i, k] / 86400)] = 1
    if (tmin == "" || t[i, k] < tmin) tmin = t[i, k]
    if (t[i, k] > tmax) tmax = t[i, k]
    next
  }
  $1 == "ctx-drop" && NF >= 7 && $7 == "1" { realafter[$2, num($3)] = 1; next }
  $1 == "ctx-compact" && NF >= 10 {
    if (($2, $3) in rcseen) next
    rcseen[$2, $3] = 1
    nrc++; rc_s[nrc] = $2; rc_pre[nrc] = num($5); rc_post[nrc] = num($6); rc_infl[nrc] = num($8)
    if (num($6) > 0) sums[++nsum] = num($6)
    if (num($10) > 0) posts[++np] = num($10)
    next
  }
  function sortn(a, m,   i, j, v) { for (i = 2; i <= m; i++) { v = a[i]; for (j = i - 1; j >= 1 && a[j] > v; j--) a[j + 1] = a[j]; a[j + 1] = v } }
  function rate(i, k) { return occ[i, k] > 0 ? (in_[i, k] + 1.25 * cc[i, k] + R * cr[i, k]) / occ[i, k] : 0 }
  # Simulates threshold fraction f on session i; fills CT (tokens), CC (call
  # cost), CK (compaction cost), CN (compactions), CF (in flight).
  # The call right after a real compaction paid a cache rewrite the simulated
  # world does not have: it is priced at the rate of the call before it.
  function sim(i, f,   thr, k, s, d, jc, lo, rk) {
    CT = 0; CC = 0; CK = 0; CN = 0; CF = 0
    thr = f * W
    for (k = 1; k <= n[i]; k++) {
      jc = 0; rk = rate(i, k)
      if (k == 1) s = occ[i, k]
      else {
        d = occ[i, k] - occ[i, k - 1]
        if ((key[i], t[i, k]) in realafter) { d = 0; rk = rate(i, k - 1) }
        s += d
        if (d < 0) { lo = (P < occ[i, k]) ? P : occ[i, k]; if (s < lo) s = lo }
      }
      if (s >= thr) {
        CN++; CK += R * s + O * S; if (infl[i, k] > 0) CF++
        s = P; jc = 1
      }
      CT += s
      CC += jc ? 1.25 * s : s * rk
    }
  }
  function real(i,   k) {
    CT = 0; CC = 0
    for (k = 1; k <= n[i]; k++) { CT += occ[i, k]; CC += in_[i, k] + 1.25 * cc[i, k] + R * cr[i, k] }
  }
  END {
    if (ns == 0) { print "context-simulate: no ctx-call record in the input" > "/dev/stderr"; exit 1 }
    if (PFIX != "") P = PFIX + 0
    else if (np > 0) { sortn(posts, np); P = (np % 2) ? posts[(np + 1) / 2] : (posts[np / 2] + posts[np / 2 + 1]) / 2 }
    else P = 0.05 * W
    P = int(P * PSCALE)
    # S, the summary a compaction writes: the median postTokens of the real
    # ones (an upper bound: it also counts the system prompt and tools).
    if (nsum > 0) { sortn(sums, nsum); S = (nsum % 2) ? sums[(nsum + 1) / 2] : (sums[nsum / 2] + sums[nsum / 2 + 1]) / 2 }
    else S = P
    ndays = 0; for (d in day) ndays++
    weeks = (tmax - tmin) / 604800; if (weeks < 1) weeks = 1
    long = 0; outcost = 0; ncalls = 0
    for (i = 1; i <= ns; i++) {
      peak = 0
      for (k = 1; k <= n[i]; k++) { if (occ[i, k] > peak) peak = occ[i, k]; outcost += O * out[i, k]; ncalls++ }
      if (peak >= LMIN) long++
    }
    printf "sim-input\t%d\t%d\t%d\t%d\t%.1f\t%d\t%d\t%d\t%.0f\n", ns, long, ncalls, ndays, weeks, nrc, P, S, outcost

    # The sessions as they ran: per-session costs, kept for the bootstrap.
    for (i = 1; i <= ns; i++) { real(i); dT[i] = CT; dC[i] = CC; dK[i] = 0 }
    for (j = 1; j <= nrc; j++) if (rc_s[j] in sid) { i = sid[rc_s[j]]; dK[i] += R * rc_pre[j] + O * rc_post[j]; if (rc_infl[j] > 0) dF++ }
    totD = 0; tT = 0; tK = 0
    for (i = 1; i <= ns; i++) { totD += dC[i] + dK[i]; tT += dT[i]; tK += dK[i] }
    printf "sim\tdefault\t%d\t%.0f\t%.0f\t%.0f\t%.2f\t%.2f\t0.0\t0.0\t0.0\t0.0\n", nrc, tT, totD - tK, tK, nrc / ndays, dF / weeks

    nT = split(TLIST, TS, ",")
    for (x = 1; x <= nT; x++) {
      f = TS[x] / 100; aN = 0; aT = 0; aC = 0; aK = 0; aF = 0
      for (i = 1; i <= ns; i++) { sim(i, f); sC[i] = CC + CK; aN += CN; aT += CT; aC += CC; aK += CK; aF += CF }
      sav = 100 * (1 - (aC + aK) / totD)
      bill = 100 * (totD - aC - aK) / (totD + outcost)
      # Percentile bootstrap over sessions.
      srand(SEED + x)
      for (r = 1; r <= REPS; r++) {
        a = 0; b = 0
        for (q = 1; q <= ns; q++) { i = int(rand() * ns) + 1; a += sC[i]; b += dC[i] + dK[i] }
        bs[r] = (b > 0) ? 100 * (1 - a / b) : 0
      }
      sortn(bs, REPS)
      lo = bs[int(0.025 * REPS) + 1]; hi = bs[int(0.975 * REPS)]
      printf "sim\t%d\t%d\t%.0f\t%.0f\t%.0f\t%.2f\t%.2f\t%.1f\t%.1f\t%.1f\t%.1f\n", TS[x], aN, aT, aC, aK, aN / ndays, aF / weeks, sav, lo, hi, bill
    }
  }
' ${FILES[@]+"${FILES[@]}"}
