# AlmsMatch

An agentic matching engine that takes an individual donor's giving profile and traverses a graph of real nonprofits to surface the handful that genuinely fit — with an LLM-written, mission-grounded rationale for each. Built in [Jac](https://github.com/jaseci-labs/jac) for JacHacks SF 2026.

**The user:** Priya, an angel investor in SF who wants to direct $10K/year toward climate nonprofits. She has no way to vet dozens of orgs herself, so every year she either defaults to the same two brand-name charities or does nothing. Smaller, more effective orgs never surface for her.

**What breaks today:** the two people best positioned to fix this — the donor and the org — never see each other. Priya doesn't have time to read 20 mission statements; a $3M food-rescue nonprofit doesn't have a marketing budget to compete with an $80M brand name. AlmsMatch is the traversal that connects them.

---

## Where Jac runs

Judges: this is criterion 01. Every link below is real code, not a pointer to "somewhere in the repo."

| What | File : line |
|---|---|
| **The two-hop graph walk** — `Investor --CaresAbout--> CauseHub --TaggedAs--> Nonprofit` | [walkers.jac:213-243](walkers.jac#L213-L243) |
| Deterministic prefilter (exclusions, cause/geography/leverage scoring) — plain Jac, runs on every candidate before any LLM call | [walkers.jac:245-303](walkers.jac#L245-L303) |
| **501(c)(3) verification gate** — a revoked org leaves the ranked list before it can cost an LLM call; `skip`, not `disengage`, so the walk continues | [walkers.jac:262-276](walkers.jac#L262-L276) |
| **The `by llm()` call** — cheap Jac math already ran; this only fires on survivors | [walkers.jac:314-320](walkers.jac#L314-L320) |
| 60/40 blend of the LLM's read against the graph's arithmetic — the ranking decision itself | [walkers.jac:326](walkers.jac#L326), formula at [walkers.jac:43-44](walkers.jac#L43-L44) |
| Single accumulate-then-report at exit (not scattered per-match reports) | [walkers.jac:350-367](walkers.jac#L350-L367) |
| **`PledgeCommitter`** — find-first-match walker, same two-hop traversal, writes the pledge back into the graph as a first-class node and reports immediately before `disengage` | [walkers.jac:387-430](walkers.jac#L387-L430) |
| **`FitAssessment`** — the typed `obj` byLLM validates the model's reply against; the Jac type system *is* the output schema | [ai.jac:11-15](ai.jac#L11-L15) |
| `score_fit` — no function body; `by llm()` is the implementation | [ai.jac:36-42](ai.jac#L36-L42) |
| `sem` strings grounding every field in the donor's actual words and the nonprofit's actual mission text, never general knowledge | [ai.jac:20-34](ai.jac#L20-L34), [ai.jac:51-63](ai.jac#L51-L63) |
| REST surface spawning the walkers above from `jac start` | [api.jac:64-110](api.jac#L64-L110) (`find_matches`), [api.jac:112-129](api.jac#L112-L129) (`commit_pledge`) |

**The one sentence that matters for this criterion:** the matching decision — deterministic scoring, LLM reasoning, and the blend between them — happens entirely inside `MatchFinder`'s walker abilities as it physically traverses the graph. Nothing about *which nonprofit wins* lives in Python, in the frontend, or in a raw API call. Delete `walkers.jac` and there is no product left.

**Jac ratio: 50.8%** — 1,484 Jac lines vs. 1,438 non-Jac, `CLAUDE.md` excluded (**46.0%** if you count it). Hand-counted with `wc -l` against `git ls-files`, re-measured after each change rather than quoted from an earlier commit.

| | lines |
|---|---|
| **Jac** (7 files) | **1,484** |
| single-file frontend (`web/index.html`) | 712 |
| JSON data — seed records + cached fixtures | 561 |
| docs + config (`README.md`, `jac.toml`, `.gitignore`) | 165 |

Worth reading the denominator honestly: **561 of those non-Jac lines are data, not code** — the seeded nonprofit records and the two cached fixture files — and another 712 are one deliberately un-frameworked HTML page. Counting only what is actually *program logic*, the project is **66.3% Jac** (1,484 vs. the 712-line frontend plus 41 lines of `jac.toml`). Every ranking decision lives on the Jac side of that line; the frontend renders what the walker already decided.

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
  seed_data.json      # 21 real nonprofits + 1 clearly-labeled synthetic test record
  fixtures/           # cached by llm() outputs AND cached IRS verification data
  walkers.jac         # MatchFinder (the traversal + ranking) and PledgeCommitter
  ai.jac              # FitAssessment schema, score_fit by llm(), sem grounding strings
  main.jac            # CLI entry: graph bootstrap, Seeder, GraphStats, the live match run
  api.jac             # jac start REST surface: find_matches, commit_pledge, demo_profile
  web/index.html       # single-page form → ranked results + traversal trace → pledge
  walkers.test.jac    # 15 tests, all offline (MockLLM, no API key needed)
```

The traversal is genuinely two-hop — `Investor -> CauseHub -> Nonprofit` — not a flat scan with an extra table in the middle. `CauseHub` exists purely to make that true.

## Running it

```bash
python -m venv .venv && source .venv/bin/activate
pip install jaseci byllm
echo "ANTHROPIC_API_KEY=sk-..." > .env   # gitignored, never committed

jac script reset      # seed the graph fresh, print structure + a live match run
jac script test       # 15 tests, fully offline, no key required
jac script serve       # jac start api.jac --no_client --port 8123
```

Then open `web/index.html` directly in a browser (`file://` works — CORS is permissive) and click **Load demo profile** to pre-fill Priya's exact values, no typing on stage.

**If wifi or the API flakes during judging:** kill the server and restart with `DEMO_MODE=1 jac script serve`. The walker still runs for real — real traversal, real deterministic scoring, real blend math — only the `by llm()` leaf calls replay a real response captured earlier against `claude-sonnet-5`, from [fixtures/cached_matches.json](fixtures/cached_matches.json). Zero visible difference in the UI.

## Design decisions worth knowing about

- **`sem` strings, not docstrings.** Every byLLM field is described in prose the model actually reads at call time ([ai.jac:20-34](ai.jac#L20-L34)) — this is why rationales quote specific mission text ("meals rescued and methane emissions avoided per pickup route") instead of generic praise.
- **The deterministic score runs first, always.** `by llm()` only fires on candidates that already cleared a cheap Jac-arithmetic floor ([walkers.jac:311](walkers.jac#L311)) — real cost control, not a stylistic choice, and it's why Rainforest Trust (an $80M org) gets demoted out of Priya's top 5 once the model reads what her $10K actually buys there.
- **`skip` vs. `disengage`.** `MatchFinder` uses `skip` — a rejected candidate doesn't stop the rest of the walk. `PledgeCommitter` uses `disengage` — it's a find-first-match walker, so it reports the receipt the instant it finds the target, then stops, deliberately skipping the exit-ability convention that governs `MatchFinder`.
- **The verification gate is deliberately not an LLM question.** Whether an org's 501(c)(3) status is currently in force is live registry data — a language model cannot answer it from training data, and would be confidently wrong if asked. So it's a graph field populated from the IRS Business Master File and a plain `if` in the walker ([walkers.jac:268](walkers.jac#L268)). It also runs *before* the LLM floor, so a revoked org never costs an API call.

## 501(c)(3) verification

Tax-exempt status can be revoked by operation of law after three consecutive years of unfiled Form 990s. Once that happens, gifts to the organization are no longer tax-deductible — and a donor has no easy way to check before giving.

EINs and tax-exempt status for all 21 real orgs were resolved from the **[ProPublica Nonprofit Explorer API](https://projects.propublica.org/nonprofits/api/)** (free, no key), matched on name + city, and cached once into [fixtures/irs_verification.json](fixtures/irs_verification.json). **The demo never makes a live third-party call** — same reasoning as `DEMO_MODE`.

- **20 of 21 verified** — present in the current IRS BMF as a 501(c)(3), exemption in force, contributions deductible.
- **1 unverified: Tradewater.** It operates as a for-profit public benefit corporation, not a tax-exempt charity, so no 501(c)(3) record exists. It still ranks — `unverified` gates nothing. It is *not* an accusation of wrongdoing, and we deliberately did not match it to a similarly-named unrelated charity.

### The one synthetic record — read this

`seed_data.json` contains exactly **one fictional organization**, flagged `"synthetic": true`, named **"SYNTHETIC TEST ORG - Lapsed Climate Coalition (NOT A REAL CHARITY)"**. It carries the only `revoked` status in the dataset and exists solely so the exclusion path is visible during a live demo.

**No real organization in this project is labeled revoked, and none ever will be.** Marking a real named charity as revoked without it actually appearing on the IRS Auto-Revocation List would be a false factual claim about a real institution. Where status could not be confirmed, the org is marked `unverified` — never `revoked`. The synthetic record's status is stored inline in `seed_data.json` and deliberately kept *out* of `fixtures/irs_verification.json`, so fiction cannot leak into the file of real IRS facts.

## Tracks

Social Impact · Fintech/Open · Best JacHammer · Best Use of Jaclang
