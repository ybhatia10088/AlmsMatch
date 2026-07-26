# AlmsMatch

An agentic matching engine that takes an individual donor's giving profile and traverses a graph of real nonprofits to surface the handful that genuinely fit — with an LLM-written, mission-grounded rationale for each. Built in [Jac](https://github.com/jaseci-labs/jac) for JacHacks SF 2026.

**The user:** Priya, an angel investor in SF who wants to direct $10K/year toward climate nonprofits. She has no way to vet dozens of orgs herself, so every year she either defaults to the same two brand-name charities or does nothing. Smaller, more effective orgs never surface for her.

**What breaks today:** the two people best positioned to fix this — the donor and the org — never see each other. Priya doesn't have time to read 20 mission statements; a $3M food-rescue nonprofit doesn't have a marketing budget to compete with an $80M brand name. AlmsMatch is the traversal that connects them.

---

## Where Jac runs

Judges: this is criterion 01. Every link below is real code, not a pointer to "somewhere in the repo."

| What | File : line |
|---|---|
| **The two-hop graph walk** — `Investor --CaresAbout--> CauseHub --TaggedAs--> Nonprofit` | [walkers.jac:207-237](walkers.jac#L207-L237) |
| Deterministic prefilter (exclusions, cause/geography/leverage scoring) — plain Jac, runs on every candidate before any LLM call | [walkers.jac:239-278](walkers.jac#L239-L278) |
| **The `by llm()` call** — cheap Jac math already ran; this only fires on survivors | [walkers.jac:290-296](walkers.jac#L290-L296) |
| 60/40 blend of the LLM's read against the graph's arithmetic — the ranking decision itself | [walkers.jac:302](walkers.jac#L302), formula at [walkers.jac:43-44](walkers.jac#L43-L44) |
| Single accumulate-then-report at exit (not scattered per-match reports) | [walkers.jac:326-342](walkers.jac#L326-L342) |
| **`PledgeCommitter`** — find-first-match walker, same two-hop traversal, writes the pledge back into the graph as a first-class node and reports immediately before `disengage` | [walkers.jac:363-397](walkers.jac#L363-L397) |
| **`FitAssessment`** — the typed `obj` byLLM validates the model's reply against; the Jac type system *is* the output schema | [ai.jac:11-15](ai.jac#L11-L15) |
| `score_fit` — no function body; `by llm()` is the implementation | [ai.jac:36-42](ai.jac#L36-L42) |
| `sem` strings grounding every field in the donor's actual words and the nonprofit's actual mission text, never general knowledge | [ai.jac:20-34](ai.jac#L20-L34), [ai.jac:51-63](ai.jac#L51-L63) |
| REST surface spawning the walkers above from `jac start` | [api.jac:64-110](api.jac#L64-L110) (`find_matches`), [api.jac:112-129](api.jac#L112-L129) (`commit_pledge`) |

**The one sentence that matters for this criterion:** the matching decision — deterministic scoring, LLM reasoning, and the blend between them — happens entirely inside `MatchFinder`'s walker abilities as it physically traverses the graph. Nothing about *which nonprofit wins* lives in Python, in the frontend, or in a raw API call. Delete `walkers.jac` and there is no product left.

**Jac ratio: 66.8%** of the codebase (1,320 Jac lines / 1,977 code+config lines, `CLAUDE.md` excluded; 57.8% if you count it). Hand-counted — `wc -l *.jac` vs. every other tracked file.

---

## Architecture

```
Investor (Priya)
   │  CaresAbout (weighted edge)
   ▼
CauseHub (e.g. "climate")
   │  TaggedAs (incoming, from every matching org)
   ▼
Nonprofit  ──┬── deterministic score  (cause fit + budget leverage + geography)
             └── by llm() FitAssessment  (score, rationale, concern)
                       │
                  60/40 blend  →  ranked MatchReport
                       │
                 commit a match
                       ▼
        Investor --PledgedTo--> Pledge --Supports--> Nonprofit
```

```
almsmatch/
  nodes.jac          # Investor, Nonprofit, CauseHub, Region, Pledge + typed edges
  seed_data.json      # 21 real nonprofits: climate, education, housing, health, food security
  walkers.jac         # MatchFinder (the traversal + ranking) and PledgeCommitter
  ai.jac              # FitAssessment schema, score_fit by llm(), sem grounding strings
  main.jac            # CLI entry: graph bootstrap, Seeder, GraphStats, the live match run
  api.jac             # jac start REST surface: find_matches, commit_pledge, demo_profile
  fixtures/           # cached real by llm() outputs — DEMO_MODE=1 fallback if wifi dies
  web/index.html       # single-page form → ranked results + traversal trace → pledge
  walkers.test.jac    # 13 tests, all offline (MockLLM, no API key needed)
```

The traversal is genuinely two-hop — `Investor -> CauseHub -> Nonprofit` — not a flat scan with an extra table in the middle. `CauseHub` exists purely to make that true.

## Running it

```bash
python -m venv .venv && source .venv/bin/activate
pip install jaseci byllm
echo "ANTHROPIC_API_KEY=sk-..." > .env   # gitignored, never committed

jac script reset      # seed the graph fresh, print structure + a live match run
jac script test       # 13 tests, fully offline, no key required
jac script serve       # jac start api.jac --no_client --port 8123
```

Then open `web/index.html` directly in a browser (`file://` works — CORS is permissive) and click **Load demo profile** to pre-fill Priya's exact values, no typing on stage.

**If wifi or the API flakes during judging:** kill the server and restart with `DEMO_MODE=1 jac script serve`. The walker still runs for real — real traversal, real deterministic scoring, real blend math — only the `by llm()` leaf calls replay a real response captured earlier against `claude-sonnet-5`, from [fixtures/cached_matches.json](fixtures/cached_matches.json). Zero visible difference in the UI.

## Design decisions worth knowing about

- **`sem` strings, not docstrings.** Every byLLM field is described in prose the model actually reads at call time ([ai.jac:20-34](ai.jac#L20-L34)) — this is why rationales quote specific mission text ("meals rescued and methane emissions avoided per pickup route") instead of generic praise.
- **The deterministic score runs first, always.** `by llm()` only fires on candidates that already cleared a cheap Jac-arithmetic floor ([walkers.jac:287](walkers.jac#L287)) — real cost control, not a stylistic choice, and it's why Rainforest Trust (an $80M org) gets demoted out of Priya's top 5 once the model reads what her $10K actually buys there.
- **`skip` vs. `disengage`.** `MatchFinder` uses `skip` — a rejected candidate doesn't stop the rest of the walk. `PledgeCommitter` uses `disengage` — it's a find-first-match walker, so it reports the receipt the instant it finds the target, then stops, deliberately skipping the exit-ability convention that governs `MatchFinder`.
- **EINs are schema-present, not populated.** `Nonprofit.ein` ([nodes.jac:21](nodes.jac#L21)) exists for a production version to fill from IRS data. Every seed record ships with a real name and real mission text, but a blank EIN — we chose not to hand-copy 21 tax IDs against a one-day deadline rather than risk attaching a wrong or stale one to a real org's name.

## Tracks

Social Impact · Fintech/Open · Best JacHammer · Best Use of Jaclang
