# The matching engine. This is the center of the product: the ranking decision is
# made by a walker moving through the graph, not by a helper function handed a list.
#
# MatchFinder is a two-hop walk that spawns on an Investor node:
#   hop 0  Investor --CaresAbout-->  CauseHub
#   hop 1  CauseHub <--TaggedAs--    Nonprofit
# and scores each Nonprofit it lands on.
#
# Scoring is two-stage, and the staging is the point. Cheap deterministic Jac math
# runs at every candidate node; the expensive `by llm()` reasoning runs only on the
# ones that math says are worth reasoning about. Both stages live inside the walker
# ability - the ranking decision never leaves the graph walk.

import from nodes { Investor, Nonprofit, CauseHub, CaresAbout, TaggedAs }
import from ai { score_fit, FitAssessment }


# Geography is a containment ladder, not a set of unrelated strings. An org that
# operates "Global" does serve someone in the Bay Area; an org scoped narrower
# than the donor may not reach her at all.
glob REGION_LADDER: list[str] = [
    "San Francisco Bay Area",
    "California",
    "United States",
    "Global"
];

glob MAX_CAUSE: int = 40;
glob MAX_LEVERAGE: int = 35;
glob MAX_GEO: int = 25;

# The two scorers answer different questions and they disagree on purpose.
# The deterministic score knows the numbers - budget leverage, geographic reach,
# how strongly she weights this cause. The LLM score knows the prose - whether the
# mission text actually describes what she said she wanted funded. Neither alone
# ranks well: math alone loves any small local org, and the model alone loves any
# well-written mission. 60/40 lets the reading lead while the arithmetic anchors it.
glob LLM_WEIGHT: int = 60;
glob DET_WEIGHT: int = 40;


def blend(llm_score: int, det_score: int) -> int {
    return (LLM_WEIGHT * llm_score + DET_WEIGHT * det_score) // 100;
}


obj MatchResult {
    has name: str;
    has mission: str;
    has impact_metric: str;
    has geography: str;
    has annual_budget: int;
    # `score` is what the ranking sorts on: the blend when the LLM ran, the
    # deterministic score when it did not. `base_score` and `llm_score` are kept
    # separately so the UI can show the judges both halves of the disagreement.
    has score: int = 0;
    has base_score: int = 0;
    has llm_score: int = 0;
    has reasoned: bool = False;
    has rationale: str = "";
    has concern: str = "";
    has cause_points: int = 0;
    has leverage_points: int = 0;
    has geo_points: int = 0;
    has gift_bps: int = 0;
    # Human-readable "why", one line per scoring component. Doubles as the
    # grounding context handed to the LLM.
    has signals: list[str] = [];
}


obj MatchReport {
    has investor: str;
    has considered: int = 0;
    has rejected: list[str] = [];
    has matches: list[MatchResult] = [];
    has trace: list[str] = [];
}


def region_scope(name: str) -> int {
    if name in REGION_LADDER {
        return REGION_LADDER.index(name);
    }
    return -1;
}


def geo_points(inv_geo: str, org_geo: str) -> int {
    inv = region_scope(inv_geo);
    org = region_scope(org_geo);
    if inv == -1 or org == -1 {
        return 0;
    }
    gap = org - inv;
    # A narrower scope than the donor's own means the org may not serve her region.
    if gap < 0 {
        return 0;
    }
    if gap == 0 {
        return MAX_GEO;
    }
    if gap == 1 {
        return 18;
    }
    if gap == 2 {
        return 12;
    }
    return 8;
}


# What fraction of the org's annual budget does one gift represent? This is the
# whole "a small amount of money still changes the outcome" thesis, in integers.
def gift_bps(org_budget: int, gift: int) -> int {
    if org_budget <= 0 or gift <= 0 {
        return 0;
    }
    return (gift * 10000) // org_budget;
}


def leverage_points(bps: int) -> int {
    if bps >= 30 {
        return MAX_LEVERAGE;
    }
    if bps >= 10 {
        return 28;
    }
    if bps >= 3 {
        return 20;
    }
    if bps >= 1 {
        return 12;
    }
    return 5;
}


def cause_points(org_tags: list[str], cause_weight: dict[str, int]) -> int {
    best = 0;
    matched = 0;
    for tag in org_tags {
        if tag in cause_weight {
            matched += 1;
            if cause_weight[tag] > best {
                best = cause_weight[tag];
            }
        }
    }
    if matched == 0 {
        return 0;
    }
    # Base credit for being in a cause she funds, scaled by how strongly she
    # weights that cause, plus a small bonus for overlapping on several.
    raw = 20 + (5 * best) + (3 * (matched - 1));
    return raw if raw < MAX_CAUSE else MAX_CAUSE;
}


# Hard gate, not a score penalty. Runs before any expensive work.
def excluded_by(name: str, mission: str, exclusions: list[str]) -> str {
    haystack = (name + " " + mission).lower();
    for term in exclusions {
        cleaned = term.strip().lower();
        if len(cleaned) > 0 and cleaned in haystack {
            return term;
        }
    }
    return "";
}


walker MatchFinder {
    # Profile snapshot, captured from the spawn origin so every downstream
    # ability can score without walking back to the Investor node.
    has investor_name: str = "";
    has gift: int = 0;
    has geography: str = "";
    has exclusions: list[str] = [];
    has values_statement: str = "";
    has cause_weight: dict[str, int] = {};

    has top_n: int = 5;

    # LLM controls. `use_llm=False` is the Phase 2 fallback demo - the whole
    # traversal and ranking still runs, just without the reasoning layer. The
    # annex tests run this way so `jac test` never touches the network.
    has use_llm: bool = True;
    # Deterministic floor: a candidate this far off on the numbers does not earn
    # an API call. This is the "cheap filter before expensive work" gate, and it
    # is plain Jac arithmetic deciding it.
    has llm_floor: int = 40;
    # Hard ceiling on calls per run, so an unexpectedly large graph can never
    # turn a 4-minute demo into a 2-minute wait.
    has llm_budget: int = 8;
    has llm_calls: int = 0;

    has seen: list[str] = [];
    has considered: int = 0;
    has rejected: list[str] = [];
    has scored: list[MatchResult] = [];
    has trace: list[str] = [];

    has reports: list[MatchReport] = [];

    can start with Investor entry {
        self.investor_name = here.name;
        self.gift = here.annual_budget;
        self.geography = here.geography;
        self.exclusions = here.exclusions;
        self.values_statement = here.values_statement;

        hubs = [here ->:CaresAbout:->];
        for hub in hubs {
            # Read the CaresAbout edge's own weight - how strongly she funds
            # this cause relative to the others.
            weight = 1;
            for link in [edge here ->:CaresAbout:-> hub] {
                weight = link.weight;
            }
            self.cause_weight[hub.tag] = weight;
        }

        self.trace.append(
            f"hop 0  Investor({here.name})  --CaresAbout-->  {len(hubs)} CauseHub {[h.tag for h in hubs]}"
        );
        visit hubs;
    }

    can gather with CauseHub entry {
        orgs = [here <-:TaggedAs:<-];
        self.trace.append(
            f"hop 1  CauseHub({here.tag})  <--TaggedAs--  {len(orgs)} Nonprofit"
        );
        visit orgs;
    }

    can evaluate with Nonprofit entry {
        # An org tagged under two of her cause hubs is reached twice. Score once.
        if here.name in self.seen {
            self.trace.append(f"       . {here.name}: already scored via another hub");
            skip;
        }
        self.seen.append(here.name);
        self.considered += 1;

        # Deterministic prefilter, in plain Jac, before any expensive reasoning.
        hit = excluded_by(here.name, here.mission, self.exclusions);
        if len(hit) > 0 {
            self.rejected.append(f"{here.name} (matches exclusion '{hit}')");
            self.trace.append(f"       x {here.name}: EXCLUDED on '{hit}', skipped");
            skip;
        }

        cp = cause_points(here.cause_tags, self.cause_weight);
        bps = gift_bps(here.annual_budget, self.gift);
        lp = leverage_points(bps);
        gp = geo_points(self.geography, here.geography);

        base = cp + lp + gp;

        result = MatchResult(
            name=here.name,
            mission=here.mission,
            impact_metric=here.impact_metric,
            geography=here.geography,
            annual_budget=here.annual_budget,
            score=base,
            base_score=base,
            cause_points=cp,
            leverage_points=lp,
            geo_points=gp,
            gift_bps=bps,
            signals=[
                f"cause fit {cp}/{MAX_CAUSE} - tagged {here.cause_tags}, she funds {list(self.cause_weight.keys())}",
                f"leverage {lp}/{MAX_LEVERAGE} - a ${self.gift} gift is {bps} basis points of a ${here.annual_budget} budget",
                f"geography {gp}/{MAX_GEO} - operates {here.geography}, she is in {self.geography}"
            ]
        );

        # Stage two, at the node, on survivors only. `score_fit` has no body in
        # ai.jac - `by llm()` is the implementation and FitAssessment is the
        # schema the reply is validated against, so what comes back here is
        # already a well-typed object, never a string to be parsed.
        if self.use_llm and base >= self.llm_floor and self.llm_calls < self.llm_budget {
            note = f"A ${self.gift} gift is {bps} basis points of this org's ${here.annual_budget} annual budget.";
            try {
                fit = score_fit(
                    values_statement=self.values_statement,
                    exclusions=self.exclusions,
                    mission=here.mission,
                    impact_metric=here.impact_metric,
                    leverage_note=note
                );
                self.llm_calls += 1;
                result.llm_score = fit.score;
                result.rationale = fit.rationale;
                result.concern = fit.concern;
                result.reasoned = True;
                result.score = blend(fit.score, base);
                self.trace.append(
                    f"       * {here.name}: by llm() {fit.score}/100  blended {DET_WEIGHT}% x {base} + {LLM_WEIGHT}% x {fit.score} = {result.score}/100"
                );
            } except Exception as e {
                # A demo must survive dead wifi. Losing the reasoning layer costs
                # us the rationale, not the ranking - the deterministic score
                # already in `result.score` stands and the walk carries on.
                result.signals.append(f"llm unavailable ({type(e).__name__}), deterministic score only");
                self.trace.append(f"       ! {here.name}: llm call failed ({type(e).__name__}), kept {base}/100");
            }
        } elif self.use_llm and base < self.llm_floor {
            self.trace.append(
                f"       - {here.name}: {base}/100 below llm floor {self.llm_floor}, no call made"
            );
        } else {
            self.trace.append(f"       + {here.name}: scored {base}/100");
        }

        self.scored.append(result);
    }

    # Exit abilities run post-order, so the spawn origin's exit fires last -
    # after every candidate has been visited and scored.
    can finish with Investor exit {
        ranked = sorted(
            self.scored,
            key=lambda(m: MatchResult) -> int { return m.score; },
            reverse=True
        );
        self.trace.append(
            f"done   {self.considered} considered, {len(self.rejected)} excluded, "
            + f"{self.llm_calls} reasoned by llm(), top {self.top_n} returned"
        );
        report MatchReport(
            investor=self.investor_name,
            considered=self.considered,
            rejected=self.rejected,
            matches=ranked[:self.top_n],
            trace=self.trace
        );
    }
}
