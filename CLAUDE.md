# Claude Code Build Prompt: Agentic Nonprofit Matching Platform (JacHacks SF 2026)

## ROLE

You are building a complete, demo-ready hackathon project in **Jac** (the AI-native language from Jaseci Labs) for JacHacks SF 2026. Submissions close at **7:15 PM today**. Optimize every decision for the judging rubric below, not for production readiness. Working software beats scope.

## HARD CONSTRAINT (read first)

Your Jac knowledge may be outdated. Jac syntax changed meaningfully between 0.7.x and 0.8.x. Before writing a single line of Jac:

1. Run `pip install jaseci byllm` and then `jac --version`. Record the version.
2. Fetch and read the official LLM-oriented syntax reference: https://docs.jaseci.org/learn/tools/llmdocs/ and pull down `llmdocs-jaseci-mini_v3.txt` (or the current equivalent).
3. Fetch these pages and skim them: https://docs.jaseci.org/learn/data_spatial/walkers/ , https://docs.jaseci.org/learn/jac-byllm/agentic_ai/ , https://docs.jaseci.org/reference/plugins/byllm/
4. Write a 10-line `hello_graph.jac` that creates two nodes, one typed edge, and one walker that visits and prints. Run it with `jac run hello_graph.jac`. Do not proceed until it executes cleanly.

If any syntax in this prompt conflicts with the fetched docs, **the docs win**. Tell me when that happens.

> **Resolved for this project:** the authoritative reference is the installed skill docs at
> `.venv/lib/python3.14/site-packages/jaclang/cli/skills/*.md`. These take precedence over
> both this document's syntax sketches and any recalled syntax. Key files:
> `jac-walker-patterns.md`, `jac-node-edge-patterns.md`, `jac-by-llm.md`, `jac-testing.md`.

## THE PROJECT

**Working name:** AlmsMatch (rename if you have something better)

**One line:** An agentic matching engine that takes an individual investor's giving profile and traverses a graph of nonprofits to surface the handful that genuinely fit, with an LLM-written rationale for each.

**The user (name one person, not a market):** Priya, an angel investor in SF who wants to direct $10K/year toward climate nonprofits. She has no way to vet dozens of orgs herself, so every year she either defaults to the same two brand-name charities or does nothing. Smaller, more effective orgs never surface for her.

**What we build:** Priya enters her profile. A Jac walker spawns on her node, traverses the nonprofit graph along cause/geography edges, and at each candidate node a `by llm()` ability scores fit and writes a one-sentence rationale grounded in her stated values. Top matches come back ranked. She commits a pledge, which is written back into the graph as a first-class node.

**Explicitly out of scope:** real payment rails, Stripe, ACH, KYC, auth, user accounts, databases beyond in-graph persistence. A pledge is a graph node and a confirmation screen. Do not spend a single minute on payment infrastructure. It is not scored and it will eat the hours we need for the Jac logic.

## THE RUBRIC (this is exactly what we are scored on)

Four criteria, each scored 1 to 5 from a 4-minute live demo, then weighted. Use of Jac is worth double any other criterion.

### 01 — Use of Jac — 40%
*Is Jac doing real work at the center of the project?*

- **1 PERIPHERAL:** Jac is bolted on, boilerplate, or barely touched. The product would work the same without it. **NOT ELIGIBLE FOR PRIZES.**
- **3 MEANINGFUL:** Real logic lives in Jac and drives part of the main workflow, not just a thin wrapper around another stack. **MINIMUM TO QUALIFY.**
- **5 CENTRAL:** The product depends on Jac, used with depth or originality: walkers, graph traversal, byLLM, agentic flows.

Note from the organizers: be ready to show where Jac runs, point to it in the repo or demo rather than just claiming it. The highest score here also wins the Best JacHammer award ($500).

**Non-negotiable rules this implies:**
- The matching decision must happen **inside** a Jac walker traversing a Jac graph. If the ranking logic migrates into a Python helper or a raw OpenAI call, we have failed criterion 01 and forfeited 40% of the score.
- Codebase must be **at least 40% Jac** by the event rules. Track this. Run `cloc . --exclude-dir=node_modules,.venv` periodically and report the Jac percentage to me. If it drops below 50%, stop adding non-Jac code and move logic into Jac.
- Use typed edges, not just untyped `++>`. Use walker abilities with `with <NodeType> entry`. Use `report`. Use `disengage` where it makes sense.
- Use `sem` semantic strings on the byLLM functions. It improves output quality and it is visibly Jac-native on screen.

### 02 — Real-World Use Case — 20%
*Would someone outside this room actually use it?*

- **1 UNCLEAR:** Hard to name the user or the problem being solved.
- **3 CLEAR:** Real user, real problem, credible value.
- **5 COMPELLING:** A problem worth solving, and a convincing way to solve it.

Note: name one person, not a market. A narrow, focused problem can earn a 5.

**Implication:** seed the graph with **real nonprofits and real mission text**, 18 to 22 of them, spread across climate, education, housing, health, and food security. Real names and real missions make the demo credible in a way that "Nonprofit A, Nonprofit B" never will. Put them in a `seed_data.jac` or a JSON the Jac seeder reads.

### 03 — Technical Execution — 20%
*How much did you build, and how well does it hold up?*

- **1 THIN:** Mostly scaffolding, templates, or hand-waving.
- **3 SOLID:** A real build with the hard part genuinely done.
- **5 IMPRESSIVE:** Ambitious scope, cleanly pulled off in one day.

Note: judged against one day of building, not a funded roadmap.

**Implication:** the "hard part" here is the traversal plus LLM-reasoning pipeline. That is where the effort goes. Everything else stays deliberately thin.

### 04 — Demo and Story — 20%
*Did you show the core product working, end to end?*

- **1 INCOMPLETE:** Slides, mockups, or a workflow that never runs.
- **3 FUNCTIONAL:** Main flow runs start to finish, rough edges and all.
- **5 CONVINCING:** Complete, clear, and demoed with real evidence.

Note: a working demo beats a deck. Scored on what you show, not what you promise.

**Implication:** the demo must run live without a network gamble. Build a cached/mock mode (see Phase 5).

### In the 4 minutes, the organizers want:
1. Say who it is for, and what breaks for them today.
2. Run the core workflow live. Do not describe it.
3. Show where Jac runs inside the product.

### Tracks to submit on Devpost
Social Impact (1st: $1,500), Fintech/Open (1st: $1,500), Best JacHammer ($500), Best Use of Jaclang ($400). Select all four.

## ARCHITECTURE

Keep it to four Jac files plus one thin frontend.

```
almsmatch/
  main.jac           # entry, graph bootstrap, walker spawn, API surface
  nodes.jac          # node + edge archetypes
  walkers.jac        # MatchFinder, PledgeCommitter, (stretch) NonprofitScout
  ai.jac             # byLLM model config, by llm() abilities, sem strings
  seed_data.json     # ~20 real nonprofits
  web/               # single page, minimal
  README.md
  .env.example
```

### Graph schema

**Nodes**
- `Investor`: name, cause_areas (list[str]), annual_budget (int), geography (str), values_statement (str, free text), exclusions (list[str])
- `Nonprofit`: name, mission (str), cause_tags (list[str]), geography (str), annual_budget (int), impact_metric (str), ein (str)
- `CauseHub`: tag (str) — a hub node per cause area so traversal is a real multi-hop graph walk, not a flat list scan. This matters for criterion 01.
- `Pledge`: amount (int), rationale (str), timestamp (str)

**Edges**
- `CaresAbout` (Investor -> CauseHub), has weight: int
- `TaggedAs` (Nonprofit -> CauseHub)
- `OperatesIn` (Nonprofit -> Region)
- `PledgedTo` (Investor -> Nonprofit), carries the Pledge

The traversal is genuinely two-hop: Investor -> CauseHub -> Nonprofit. That is the difference between "Jac as a database" and "Jac as the product."

### The core walker (pseudocode, translate to current Jac syntax)

```
walker MatchFinder {
    has candidates: list = [];
    has scored: list = [];

    can start with Investor entry {
        # hop 1: out along CaresAbout to the cause hubs she cares about
        visit [->:CaresAbout:->];
    }

    can gather with CauseHub entry {
        # hop 2: in along TaggedAs to nonprofits under this cause
        visit [<-:TaggedAs:<-];
    }

    can evaluate with Nonprofit entry {
        # cheap deterministic prefilter in Jac (budget, geography, exclusions)
        if not passes_filter(here, self.investor) { disengage; }
        # expensive LLM reasoning, only on survivors
        fit = score_fit(self.investor_profile, here.mission, here.impact_metric);
        self.scored.append((here, fit));
        report fit;
    }

    can finish with exit {
        self.scored.sort(key=..., reverse=True);
        report self.scored[:5];
    }
}
```

Two things to preserve: the prefilter must be plain Jac logic (proves real logic lives in Jac), and the LLM call must be a Jac `by llm()` ability (proves byLLM depth). Both together is what a 5 looks like.

### The byLLM layer (`ai.jac`)

```
import from byllm.lib { Model }
glob llm = Model(model_name="gpt-4o");   # or the hackathon-provided sponsor model

obj FitAssessment {
    has score: int;            # 1-100
    has rationale: str;        # one sentence, addressed to the investor
    has concern: str;          # one honest caveat
}

sem FitAssessment.score = "How well this nonprofit matches the investor's stated values and constraints, 1-100.";
sem FitAssessment.rationale = "One sentence, second person, citing something specific from the nonprofit's actual mission.";
sem FitAssessment.concern = "One honest reason this might not be the right fit. Never fabricate.";

def score_fit(investor_values: str, exclusions: list[str], mission: str, impact_metric: str) -> FitAssessment by llm();
sem score_fit = """
Assess fit between an individual donor and a nonprofit. Ground the rationale in the
specific mission text provided, never in general knowledge about the organization.
If the mission text does not support a strong match, say so honestly and score low.
""";
```

The typed return object is the point: byLLM validates the LLM response against the Jac type, so the Jac type system is acting as the output schema. Say that sentence out loud in the demo, it is a criterion 01 point.

**Stretch (only if ahead of schedule):** a second `by llm()` ability that writes a short portfolio summary across the top 3 matches, showing an agentic flow where one walker's output feeds another LLM step.

### Frontend

Single page. Do not use a heavy framework. Serve it from Jac if `jac-client` or `jac serve` cooperates, otherwise a static HTML file hitting a local endpoint is fine. Three screens:

1. Profile form (cause checkboxes, budget slider, geography, free-text values box, exclusions)
2. Results: ranked cards with score, rationale, concern, and a visible "traversal trace" panel showing which nodes the walker visited in order. That trace panel is doing double duty as proof of graph traversal for the judges.
3. Pledge confirmation

Styling: clean, one accent color, generous whitespace. Twenty minutes maximum. It is 20% of one criterion, not the product.

## BUILD PHASES AND TIME BOXES

Report to me at the end of each phase. Do not silently roll forward if a phase overruns, tell me and we cut scope.

**Context hygiene (do this every phase, not just when it feels slow):** run `/compact` at the end of every phase below before starting the next one. This is a long single session and unmanaged context compounds cost even with caching. If a phase involved reading a lot of docs or files that are no longer relevant to what comes next (e.g. finishing the Jac syntax research before Phase 1, or finishing backend work before the frontend phase), run `/clear` instead of `/compact` since the next phase doesn't need that context at all. Tell me which one you ran and why at each checkpoint.

**Phase 0 — Environment (25 min)**
```
python -m venv .venv && source .venv/bin/activate
pip install jaseci byllm
jac --version
jac plugins list
jac plugins enable byllm
git init && git add -A && git commit -m "chore: init"
```
Fetch the docs listed in HARD CONSTRAINT. Get `hello_graph.jac` running. Commit.
**Checkpoint: run `/clear` before Phase 1** — the doc research is no longer needed once the syntax is confirmed, and Phase 1 doesn't need it in context.

**Phase 1 — Graph and seed data (60 min)**
Write `nodes.jac`, build `seed_data.json` with ~20 real nonprofits, write the bootstrap in `main.jac`. Success test: `jac run main.jac` prints the graph structure and node counts. Commit as "feat: graph schema and seed data".
**Checkpoint: run `/compact` before Phase 2** — keep the schema and seed data summarized in context, Phase 2 builds directly on it.

**Phase 2 — Traversal without AI (60 min)**
Write `MatchFinder` with deterministic scoring only (tag overlap, geography, budget fit). No LLM yet. Success test: running it for a hardcoded Priya profile returns a sensible ranked list. This is your fallback demo if byLLM breaks. Commit.
**Checkpoint: run `/compact` before Phase 3** — the deterministic walker logic stays relevant (Phase 3 extends it), but trim any debugging back-and-forth from getting it working.

**Phase 3 — byLLM integration (75 min)**
Write `ai.jac`, wire `score_fit` into the walker's `evaluate` ability. Success test: rationales are specific to each nonprofit's mission text, not generic. If they are generic, tighten the `sem` string. Commit.
**Checkpoint: run `/clear` before Phase 4** — the backend/walker/byLLM work is done and committed; the frontend phase doesn't need that debugging history in context, just the API surface it needs to call.

**Phase 4 — Frontend and pledge flow (75 min)**
Form, results, traversal trace panel, `PledgeCommitter` walker writing the Pledge node. Commit.
**Checkpoint: run `/compact` before Phase 5** — you're about to stress-test the same app end to end, keep the full picture but trim the frontend build chatter.

**Phase 5 — Demo hardening (45 min) — DO NOT SKIP THIS**
- Add `DEMO_MODE=1` env flag that serves cached LLM responses from `fixtures/cached_matches.json`. Live LLM calls on hackathon wifi at 7:30 PM are a real risk to criterion 04.
- Pre-fill the form with Priya's exact profile behind a "Load demo profile" button so you are not typing on stage.
- Time the full run. If a match round takes over 20 seconds, cap the LLM calls at the top 6 prefiltered candidates.
- Run through the demo end to end three times.
**Checkpoint: run `/compact` before Phase 6** — submission writeup needs the architecture and file locations in context, but not the demo hardening iteration.

**Phase 6 — Submission (30 min, start by 5:30 PM)**
- README with: the problem, the user, a Jac architecture section with a diagram, and a section titled **"Where Jac Runs"** with direct file-and-line links to the walker abilities and byLLM calls. This exists specifically for criterion 01.
- Record the demo video.
- `cloc` output in the README proving the 40% Jac requirement.
- Star https://github.com/jaseci-labs/jac (required).
- **Partial submission on Devpost at 5:50 PM.** Non-negotiable, editable afterward. Final close is 7:15 PM hard.

## FAILURE MODES TO AVOID

Flag it to me immediately if you catch yourself doing any of these:

1. **Jac as a wrapper.** If the ranking logic ends up in Python and Jac only stores data, criterion 01 collapses to a 1 and we are not eligible for prizes. The traversal and the scoring stay in Jac.
2. **Fighting the toolchain.** If a Jac feature fights you for more than 20 minutes, tell me and route around it. We do not need `jac-scale` or cloud deploy.
3. **Building payment rails.** Zero minutes on this.
4. **Generic LLM output.** If every rationale sounds the same, the demo dies. Rationales must quote something specific from the mission text.
5. **Scope creep into recommendations-for-institutions.** One investor persona, one flow.

## WHAT I WANT FROM YOU FIRST

Do not start coding. Reply with:
1. Confirmed Jac version and whether `hello_graph.jac` ran.
2. Any place the fetched docs contradict the syntax sketches above.
3. A revised phase plan with your own time estimates.
4. The single biggest technical risk you see and your mitigation.

Then start Phase 1.

---

## CONFIRMED PROJECT CONVENTIONS (resolved, do not re-litigate)

These four were corrected and reconfirmed by the user, and verified against the installed
skill docs. They override the pseudocode sketches above wherever they conflict.

1. **`skip;` is the project default for `MatchFinder`**, not `disengage;`. A prefilter
   rejection must keep visiting other candidates, not halt the walker. `skip` ends the
   current ability only; `disengage` discards the whole queue. If a future walker does a
   find-first-match lookup rather than ranking multiple candidates, `disengage` is correct
   there — call that out explicitly when the shape comes up.
2. **Single accumulate-then-report at exit.** Accumulate into a `has` list during traversal
   and emit exactly ONE `report` from the exit ability. Per-match `report` is a documented
   anti-pattern (it scatters N tiny reports). Note the pseudocode above does both — drop
   the inner `report fit;`.
3. **Typed exit abilities:** `can finish with <NodeType> exit`, never a bare
   `can finish with exit`. A generic walker `with entry` is NOT a per-node catch-all — it
   fires only at the spawn location.
4. **Fully typed edges with declared endpoints:**
   `edge TaggedAs: Nonprofit -> CauseHub { has weight: int = 1; }`

**Environment (verified 2026-07-26):** Jac 0.16.7, Python 3.14.6, macOS arm64.
Plugins present: `byllm==0.6.19`, `jac-client==0.3.25`, `jac-desktop==0.2.2`,
`jac-mcp==0.1.24`, `jac-scale==0.2.31`, `jac-super==0.1.22`.
`hello_graph.jac` runs clean. `.env` is gitignored and was never committed.

**Other doc-confirmed gotchas that bite this build:**
- `report` also prints to stdout — that's why output looks doubled. Not a bug.
- Type the report channel: `has reports: list[T] = [];`. Omitting `= []` makes `reports` a
  required spawn parameter and every `spawn` fails with E1050.
- LLM return types are `obj`s, **never** `node`s. Have the LLM fill an `obj`, then copy
  fields into a `node` to persist.
- Typed traversal uses single arrows: `[->:EdgeType:->]`. `[-->:EdgeType:]` is a parse error.
- The node you spawn on runs its matching entry too, before any `visit` — classic off-by-one.
- Entry points are `can`, not `def`. Use `sem`, not docstrings (docstrings fail W0060).
- `MockLLM` from `byllm.lib` runs without API keys; outputs consumed sequentially, one per
  `by` call. This is the Phase 5 `DEMO_MODE` mechanism and it needs no key to build.
