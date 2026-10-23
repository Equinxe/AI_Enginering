# Context Compaction Measurement

---

# Purpose

The compaction plan of 23 October 2026 (Work Units A to E) asks one question before any hook is written: **at what share of the context window should the Main Agent hand off, and is it worth holding a compaction while an Employee is still working?** This document is the measurement that answers it, Work Unit A (WU-IAENG-374). It follows `Core/CONTEXT_BUDGET.md`'s rule: every number carries the command that produced it, and what is measured is kept apart from what is simulated.

**Verdict: the decision gate failed.** The plan sets three failure conditions: fewer than 10 long sessions, any non-numeric field emitted, no interval or sensitivity. The second and third pass. The first does not: **8 long sessions, not 10.** As the plan requires, this document says so and **withholds the recommendation** for `IAENG_CTX_ALERT_PCT` and for the runtime's auto-compaction settings. What follows is the measurement, which stands on its own, and a simulation labelled exploratory: it is not a basis for a default.

---

# What was read, and how

**Source.** Every Claude Code transcript on the Director's machine, `~/.claude/projects/*/`, on 23 October 2026, read only. The runtime keeps a transcript for 30 days after its last write (`cleanupPeriodDays`), so a long-running session stays visible from its first day, and short sessions older than 30 days are gone.

**Collector.** `Adapters/ai-runtimes/claude-code/usage-collect.sh --context-series` prints one record per Main Agent API call, compaction and occupancy drop. Every field after the record tag is a number, except the session, which is a 16-hex-character hash of its file name. No prompt, reply, path, model or agent name is printed. Subagent files are read for their entry timestamps only, never their content. Its header defines every field.

```bash
C=Adapters/ai-runtimes/claude-code
for g in 300 900 3600; do
  for d in ~/.claude/projects/*/; do
    bash $C/usage-collect.sh --transcripts-dir "$d" --context-series --gap $g
  done > /tmp/ctx-$g.tsv
done
```

**Check that counts (plan: "any non-numeric field emitted" fails).** It covers 18,761 records at gap 900, with 0 non-numeric fields:

```bash
awk -F'\t' '{for(i=2;i<=NF;i++) if($i!~/^[0-9]+$/ && !(i==2 && $1!="ctx-source" && $i~/^[0-9a-f]{16}$/)) b++}
            END{print "non-numeric fields:", b+0, "records:", NR}' /tmp/ctx-900.tsv
```

**Occupancy** is `input_tokens + cache_creation_input_tokens + cache_read_input_tokens` of one call: what the call sent, so what the window held. Caching changes what a call costs, not what it occupies (`Core/CONTEXT_BUDGET.md`, Cost is not occupation).

**Duplicates.** One session file sits under two project directories (a project renamed on disk). The shorter copy is an exact prefix of the longer: 2,438 identical calls out of 2,518. The simulator counts it once, so the population is **16 unique main sessions, not 17**.

**Long session.** A session whose peak occupancy reached 300,000 tokens. That is 30 % of the window, the lowest threshold simulated: a session that never reached it is unchanged by every threshold, so it carries no information about the choice. The definition was fixed in the simulator before the sessions were counted. It is also not what fails the gate: at a 200,000 floor the count is 9, still under 10.

---

# Measured

All from `/tmp/ctx-900.tsv` unless the gap is named. The descriptive statistics come from the program in the Appendix.

## The sessions

| | |
|---|---|
| Unique main sessions | **16**, of which **8 long** (peak ≥ 300k), 9 with peak ≥ 200k |
| Main Agent calls (deduplicated by message id) | **16,222** |
| Calendar span / days with at least one call | **56.8 days** (27 Aug to 23 Oct 2026) / **32 days** |
| Subagent transcript files read for timestamps | 1,104 |

The 8 long sessions, with hashes shortened to labels (`sessions.sh` in the Appendix):

| | Peak | Calls | First day | Last day | Days | Auto compactions | … with an Employee in flight | Manual |
|---|---|---|---|---|---|---|---|---|
| L1 | 999,540 | 1,889 | 27 Aug | 23 Sep | 26.8 | 4 | 1 | 0 |
| L2 | 999,522 | 2,757 | 31 Aug | 23 Sep | 23.0 | 5 | 0 | 0 |
| L3 | 987,224 | 3,850 | 3 Sep | 20 Oct | 47.3 | 7 | 4 | 0 |
| L4 | 965,535 | 662 | 23 Sep | 9 Oct | 16.0 | 1 | 1 | 1 |
| L5 | 962,180 | 2,518 | 23 Sep | 22 Oct | 29.3 | 3 | 1 | 2 |
| L6 | 965,091 | 2,179 | 23 Sep | 23 Oct | 30.0 | 2 | 2 | 2 |
| L7 | 971,976 | 1,640 | 23 Sep | 23 Oct | 30.1 | 2 | 0 | 3 |
| L8 | 797,684 | 585 | 21 Oct | 23 Oct | 2.2 | 0 | 0 | 0 |

This is the Director's working pattern, and the reason the gate fails. The work runs as **few, very long sessions**: one session lasted 47 days and holds 3,850 calls. L8 is still running as this is written, so its peak will grow. Long sessions start in bursts, not at a steady rate: three between 27 August and 3 September, four on 23 September, one on 21 October. Retention also works against the count. L1 and L2 were last written on 23 September, so they fall out of the 30-day window now. The count can drop to 6 before it reaches 10.

## The window, and where the runtime compacts

| | Value |
|---|---|
| Window in use | **1,000,000 tokens.** Eight sessions peaked above 790,000 and one compaction read 1,011,821, impossible in a 200k window |
| Auto compactions | **24** (trigger `auto` in the runtime's `compact_boundary` entry). Manual: **8** |
| Occupancy when auto compaction fired (`preTokens`) | median **968,011** (96.8 %); quartiles 967,047 to 970,583; min 848,341, max 1,011,821 |
| Summary size (`postTokens`) | median **16,150**; quartiles 14,836 to 20,037 |
| Occupancy of the first call after (P below) | median **66,064**; quartiles 57,196 to 76,507 |
| Duration of an auto compaction | median **111 s**; quartiles 70 s to 166 s; max 221 s |
| Manual compactions, occupancy | 293,448 to 955,875, median 411,330 |
| Occupancy drops of more than half (≥ 20k tokens) | 31, **every one at a recorded compaction**: the drop detector and the runtime's own record agree, 31 of 31 |

So the runtime's default auto-compaction point on this machine is **≈ 97 % of the 1M window**. That matches Kevin's observation that the default sits near 97 %.

## Compactions while an Employee was in flight (decides WU-E)

An Employee counts as in flight at a compaction when one of the session's subagent transcripts has entries on both sides of it, with no silence longer than the gap. A gap of 900 s is the default, and 300 s and 3,600 s are the sensitivity cases.

| Gap | Auto compactions with ≥ 1 Employee in flight | Per week, 8.1 weeks | Exact Poisson 95 % interval |
|---|---|---|---|
| 300 s | 8 of 24 | 0.99 | 0.43 to 1.94 |
| **900 s** | **9 of 24** | **1.11** | **0.51 to 2.11** |
| 3,600 s | 9 of 24 | 1.11 | 0.51 to 2.11 |

By week (7-day blocks counted from Tuesday 22 September, 00:00 UTC). Rows: auto compactions, then those with an Employee in flight.

| Week from | 25 Aug | 1 Sep | 8 Sep | 15 Sep | 22 Sep | 29 Sep | 6 Oct | 13 Oct | 20 Oct (3.5 days) |
|---|---|---|---|---|---|---|---|---|---|
| Auto | 1 | 4 | 5 | 0 | 3 | 5 | 2 | 2 | 2 |
| In flight | 0 | 1 | 0 | 0 | 1 | 4 | 2 | 1 | 0 |

The rate is not stationary. Since 22 September, the period of systematic Employee dispatch, the count is **8 of 14 auto compactions in 4.5 weeks: 1.8 per week (95 %: 0.77 to 3.5)**. Before that it was 1 of 10 in 3.7 weeks.

The plan's rule for WU-E is "only if WU-A shows ≥ 1 compaction/week during an Employee in flight". **The point estimate meets it: 1.11 per week over the whole span, 1.8 per week since dispatch became systematic.** The whole-span interval still reaches below 1. Lowering the compaction threshold raises the count: the simulation below gives 3.6 per week at T = 50 %.

---

# Simulated (exploratory: the gate failed)

`Adapters/ai-runtimes/claude-code/context-simulate.sh` replays each session's calls under a threshold T, as a percentage of the 1M window. Its header states the model in full. In short:

- Each call adds to the simulated occupancy what it added to the real one.
- The call right after a real compaction adds nothing. In the simulated world, the threshold fired earlier.
- At T, the occupancy becomes P, the measured median 66,064.
- A call costs its simulated occupancy times its own real blended rate, so a real cache miss stays a miss. The call after a simulated compaction rewrites the whole context at 1.25.
- A compaction costs R × the occupancy it read, plus O × the summary, taken as the median `postTokens`.

**Prices.** Costs are in units of the input-token price. Claude Opus 5.5 lists $4 per million input tokens, $20 output (O = 5), $5 for a 5-minute cache write (1.25) and **$0.20 for a cache read: R = 0.05, not the 0.1 the plan assumed**. 0.1 is the multiplier of the older models (Opus 5, 4.x), kept here as a sensitivity case. Source: Anthropic, *Pricing* and *Prompt caching*, `https://platform.claude.com/docs/en/about-claude/pricing` and `https://platform.claude.com/docs/en/build-with-claude/prompt-caching`, as cached by the `claude-api` reference on 6 October 2026. On a subscription these are API-equivalent costs, not a bill.

```bash
bash $C/context-simulate.sh /tmp/ctx-900.tsv                       # base: P = 66,064, R = 0.05
bash $C/context-simulate.sh --thresholds 95,96,97,98 /tmp/ctx-900.tsv  # validation
bash $C/context-simulate.sh --post-scale 0.5 /tmp/ctx-900.tsv      # sensitivity
bash $C/context-simulate.sh --post-scale 2 /tmp/ctx-900.tsv
bash $C/context-simulate.sh --cache-read 0.1 /tmp/ctx-900.tsv
```

## Base case

Columns:

- **Context tokens re-sent**: occupancy summed over all 16,222 calls (Kevin's "re-read tokens").
- **Context cost**: in millions of input-price units. At $4 per million, the default's 561 M units are about $2,244 over the 57 days.
- **Saving**: against the default, with a 95 % percentile bootstrap over sessions (2,000 resamples, seed 374).
- **Of the bill**: the same saving with ordinary output (67.6 M units, the same under every T) included.

| T | Compactions | Per active day (Handoffs) | In flight per week | Context tokens re-sent | Context cost | Summary cost | **Saving** (95 % interval) | Of the bill |
|---|---|---|---|---|---|---|---|---|
| default (≈ 97 %) | 32 | 1.00 | 1.48 | 7.69 B | 561.1 M | 4.2 M | 0 | 0 |
| 80 % | 33 | 1.03 | 2.09 | 6.88 B | 494.2 M | 3.9 M | **11.9 %** (6.1 to 15.8) | 10.6 % |
| 70 % | 39 | 1.22 | 2.71 | 6.04 B | 447.8 M | 4.4 M | **20.0 %** (12.1 to 24.6) | 17.9 % |
| 60 % | 46 | 1.44 | 2.96 | 5.29 B | 385.5 M | 4.9 M | **30.9 %** (24.9 to 35.3) | 27.6 % |
| 50 % | 58 | 1.81 | 3.57 | 4.50 B | 330.1 M | 5.9 M | **40.6 %** (36.4 to 43.4) | 36.2 % |
| 40 % | 76 | 2.38 | 4.93 | 3.78 B | 282.7 M | 7.4 M | **48.7 %** (45.8 to 50.6) | 43.5 % |
| 30 % | 113 | 3.53 | 6.78 | 2.93 B | 222.2 M | 10.4 M | **58.8 %** (55.8 to 60.9) | 52.6 % |

The default row counts real compactions, auto and manual. Its "in flight" counts both triggers (12 in 8.1 weeks). The WU-E figure above counts auto only.

## Validation

Replayed at T = 97 %, the observed default, the model should reproduce the real sessions. It gives 27 compactions against 32 real, and 8.06 B context tokens against 7.69 B (+4.8 %, cost +5.8 %). The gap has a known cause. The model treats every real compaction as one the threshold makes unnecessary, including the 8 **manual** ones (at 293k to 956k), which the Director would still make under any T. So the simulated occupancy is a little too high at every T, and **the savings above are understated by up to about 5 points**. On this repository's two sessions alone (L3, L8), whose compactions were all automatic, the replay at 97 % gives the same 7 compactions, context tokens within 0.9 % and context cost within 0.1 %.

## Sensitivity

Saving against the default (95 % interval):

| T | P × 0.5 (33,703) | **base** (P 66,064, R 0.05) | P × 2 (134,813) | R = 0.1 | P × 2 and R = 0.1 |
|---|---|---|---|---|---|
| 80 % | 15.0 (10.0 to 19.1) | 11.9 (6.1 to 15.8) | 4.2 (−1.7 to 8.2) | 11.3 (5.7 to 14.8) | 4.2 (−1.2 to 7.7) |
| 70 % | 23.3 (16.2 to 28.0) | 20.0 (12.1 to 24.6) | 13.8 (8.7 to 17.3) | 20.6 (12.7 to 24.9) | 14.4 (9.3 to 17.8) |
| 60 % | 34.6 (29.9 to 37.6) | 30.9 (24.9 to 35.3) | 22.8 (18.2 to 25.9) | 31.0 (25.6 to 34.5) | 23.7 (18.9 to 26.7) |
| 50 % | 43.3 (40.1 to 45.3) | 40.6 (36.4 to 43.4) | 32.7 (27.8 to 36.2) | 40.8 (36.9 to 43.4) | 33.6 (28.7 to 36.7) |
| 40 % | 53.3 (49.2 to 56.0) | 48.7 (45.8 to 50.6) | 41.1 (37.3 to 43.7) | 49.5 (46.4 to 51.5) | 42.5 (39.0 to 44.9) |
| 30 % | 62.8 (59.8 to 64.7) | 58.8 (55.8 to 60.9) | 48.5 (45.2 to 50.9) | 60.0 (56.8 to 61.9) | 51.0 (47.8 to 53.1) |

**Re-reading after a compaction.** An agent that lost its context reads files again, so occupancy grows faster after a compaction. That cost scales with the number of compactions, which the model does not otherwise capture. Measured: over the 20 calls after a real compaction, the median growth is **40,063 tokens**, against **31,054** for other 20-call windows: **9,009 more**. Over 50 calls it is 8,304 more (`recovery.sh` in the Appendix). That is about 14 % of P, well inside the P × 2 case, which bounds it.

## What the simulation says, read with its limits

1. **Cost alone points to the lowest threshold.** Saving rises monotonically as T falls, in every sensitivity case. The summary requests stay near 5 % of context cost even at 30 % (4.7 % in the base case). Cost therefore cannot choose T. The choice is between cost and **interruptions**: Handoffs per day, and Employees in flight at a compaction. Kevin's "~28 % saving at ~50 %" falls inside our range for 50 % (27.8 to 45.3 % across all cases). His other figure, 817 M re-read tokens at 37 % against 1,206 M at 80 % (−32 %), compares with our −45 % between 40 % and 80 % (3.78 B against 6.88 B). A different workload and window, so neither confirms nor refutes ours.
2. **What the simulation cannot see:** whether work is lost at a compaction, and so whether a lower T costs quality. That is the WU-PM acceptance criterion "no state lost", which only the D+14 trial measures.
3. **The bootstrap is over 8 informative sessions** and 8 non-informative ones. The intervals are narrow because the long sessions behave alike. Narrow does not mean representative of other ways of working: an adopter with many short sessions would see almost no effect from any T.

---

# Limits

- **The gate.** 8 long sessions, from one person's way of working, over 57 days. This is the reason no recommendation is made.
- **One machine, one Director, mostly one model.** Claude Opus 5.5 since 5 October. Earlier calls ran other models at R = 0.1; the R = 0.1 column covers that.
- **Retention.** Sessions with no write for 30 days are gone, so the short sessions of late August and early September are missing. Long sessions are complete from their first day.
- **"In flight" is inferred from timestamps,** not from the runtime's own dispatch state. An Employee waiting in silence longer than the gap counts as not in flight. Its count barely moves between 300 s and 3,600 s (8 against 9).
- **The cost model** is in input-price units and assumes the 5-minute cache write (1.25). A 1-hour write (2.0) would raise every compaction's rewrite cost; that case was not run.
- **Not measured:** context lost at a compaction, the Director's time per Handoff, and the latency of a compaction (median 111 s) as felt in a working session.

---

# Recommendation: withheld

The plan makes this the stop point: with fewer than 10 long sessions, no default is recommended. These are the decisions open to the Director, with the facts for each:

1. **Accept 8 long sessions as enough, explicitly.** The exploratory figures above then apply as they stand. Every case agrees that saving rises as T falls, at the price of more Handoffs per day: 1.8 per active day at 50 % against 1.0 today. Choosing T is a choice about interruptions, not about cost.
2. **Wait for more long sessions and run the commands above again.** Retention removes L1 and L2 now, so 10 means four new long sessions. They arrive in bursts, so no date can be promised. It is unlikely before the operational target of mid to late November. Raising `cleanupPeriodDays` would keep transcripts longer, at the privacy cost of keeping them longer on disk.
3. **Measure through the trial instead.** WU-B and WU-C ship with the alert switchable. The D+14 measurement planned for about 20 November, set against this report as baseline, then supplies the data this gate asked for.

Independent of the gate:

- **The plan's cache-read multiplier must be 0.05 for Claude Opus 5.5, not 0.1.** The ranking of thresholds does not change, and the savings differ by at most 1.2 points.
- **WU-E (hold while an Employee is in flight):** 9 auto compactions in 8.1 weeks had an Employee in flight, **1.11 per week (95 %: 0.51 to 2.11)**, and 1.8 per week since dispatch became systematic. This meets the plan's "≥ 1 per week" rule at the point estimate. Those 9 compactions all come from the 8 long sessions, so this figure also rests on the sample the gate found too small.
- **`CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` and `autoCompactWindow`:** nothing here supports changing them before the Director has chosen T. The runtime's default (≈ 97 %) is the baseline every saving above is measured against.

**Where this should be referenced:** from `Core/CONTEXT_BUDGET.md`, which is Director text. A line under "Relationship to Other Documents" would do it. This Work Unit does not edit Core.

---

# Appendix: the descriptive programs

Run on `/tmp/ctx-900.tsv`; they read only the numbers-only records.

`stats.sh` (sessions, compactions by trigger, quantiles, in flight by week):

```bash
awk -F '\t' '
  function q(a, n, p,   i, j, v) {
    for (i = 1; i <= n; i++) b[i] = a[i]
    for (i = 2; i <= n; i++) { v = b[i]; for (j = i - 1; j >= 1 && b[j] > v; j--) b[j + 1] = b[j]; b[j + 1] = v }
    i = int(p * n + 0.5); if (i < 1) i = 1; if (i > n) i = n
    return b[i]
  }
  $1 == "ctx-session" && !($2 in ses) { ses[$2] = 1; ns++; if ($6 >= 300000) long++; if ($6 >= 200000) l2++
    if (first == "" || $4 < first) first = $4; if ($5 > last) last = $5 }
  $1 == "ctx-compact" && !(($2, $3) in cs) {
    cs[$2, $3] = 1
    if ($4 == 1) { na++; pre[na] = $5; post[na] = $6; dur[na] = $7; aft[na] = $10; if ($8 > 0) ainf++
                   x = ($3 - 1790035200) / 604800; w = (x >= 0 || int(x) == x) ? int(x) : int(x) - 1
                   wk[w]++; if ($8 > 0) wkf[w]++ }
    else if ($4 == 2) { nm++; mpre[nm] = $5; if ($8 > 0) minf++ }
  }
  $1 == "ctx-drop" && !(($2, $3) in ds) { ds[$2, $3] = 1; nd++; if ($7 == 1) ndb++ }
  END {
    printf "sessions %d long(>=300k) %d (>=200k) %d span-days %.1f\n", ns, long, l2, (last - first) / 86400
    printf "compactions auto %d manual %d\n", na, nm
    printf "auto pre  p25 %d med %d p75 %d\n", q(pre, na, .25), q(pre, na, .5), q(pre, na, .75)
    printf "auto post p25 %d med %d p75 %d\n", q(post, na, .25), q(post, na, .5), q(post, na, .75)
    printf "auto occ-after p25 %d med %d p75 %d\n", q(aft, na, .25), q(aft, na, .5), q(aft, na, .75)
    printf "auto duration-ms p25 %d med %d p75 %d\n", q(dur, na, .25), q(dur, na, .5), q(dur, na, .75)
    printf "auto in flight %d of %d; manual in flight %d of %d; drops %d, at a boundary %d\n", ainf, na, minf, nm, nd, ndb
    for (w in wk) printf "week %+d auto %d in-flight %d\n", w, wk[w], wkf[w] + 0
  }' /tmp/ctx-900.tsv
```

`sessions.sh` prints, for each session with peak ≥ 300k, the longest copy's peak, calls and first and last day, and its auto (and in flight) and manual compactions. It is the same `awk` over `ctx-session` and `ctx-compact`, with `strftime` (gawk).

`recovery.sh` (growth over the N calls after a compaction, against other N-call windows; N = 20 and 50):

```bash
awk -F '\t' -v N=20 '
  function med(a, n,   i, j, v) {
    for (i = 2; i <= n; i++) { v = a[i]; for (j = i - 1; j >= 1 && a[j] > v; j--) a[j + 1] = a[j]; a[j + 1] = v }
    return n ? a[int((n + 1) / 2)] : 0 }
  $1 == "ctx-call" && !(($2, $3) in seen) { seen[$2, $3] = 1; o[$2, $3 + 0] = $5; t[$2, $3 + 0] = $4; if ($3 + 0 > n[$2]) n[$2] = $3 + 0 }
  $1 == "ctx-drop" && $7 == 1 { after[$2, $3] = 1 }
  END {
    for (s in n) {
      for (k = 1; k <= n[s]; k++) if ((s, t[s, k]) in after) mark[s, k] = 1
      for (k = 1; k + N <= n[s]; k++) {
        bad = 0; for (j = k + 1; j <= k + N; j++) if ((s, j) in mark) bad = 1
        if (bad) continue
        g = o[s, k + N] - o[s, k]
        if ((s, k) in mark) post[++np] = g; else if (k % N == 1) base[++nb] = g
      }
    }
    printf "after %d median %d; other %d median %d; excess %d\n", np, med(post, np), nb, med(base, nb), med(post, np) - med(base, nb)
  }' /tmp/ctx-900.tsv
```

Poisson intervals: exact, from the chi-square quantiles, χ²(0.025; 2k)/2 and χ²(0.975; 2k+2)/2, divided by the weeks.

---

# Relationship to Other Documents

- `Core/CONTEXT_BUDGET.md`: what the framework itself occupies before work begins. This document is what the work occupies after.
- `Adapters/ai-runtimes/claude-code/usage-collect.sh`, `context-simulate.sh`: the two commands every number comes from.
- `Standards/DATA_PROTECTION_STANDARD.md`: the transcripts are read in place and never copied. Only numbers leave the collector, and only aggregates reach this document.
- `Standards/TESTING_STANDARD.md`: both scripts are tested, each test seen red against a hand mutant (WU-IAENG-374 report).

---

# Metadata

Owner: IA Engineering

Version: 0.0.14

Status: Draft

Category: Governance — Measurement

Severity: Advisory
