# Annex tests for walkers.jac - run with `jac test walkers.jac`.
# Tests share one persisted root, so every fixture here uses a unique name and
# assertions filter on it rather than counting totals on root.
#
# CauseHubs built here hang off the test Investor, never off root: main.jac's
# Seeder treats "root has a CauseHub" as "already seeded", so attaching test
# hubs to root would make a later `jac run` silently skip seeding.
#
# The annex resolves walkers.jac's own declarations at run time but NOT the names
# walkers.jac imports, so `jac check` needs these spelled out here.

#
# The reasoned-path tests swap ai.jac's model for MockLLM. ai.jac declares no
# `glob llm` - it uses the ambient builtin - and assigning `ai.llm` from out here
# overrides it anyway, so no test needs an API key or the network.

import ai;
import from byllm.lib { MockLLM }
import from ai { FitAssessment }
import from nodes { Investor, Nonprofit, CauseHub, CaresAbout, TaggedAs, PledgedTo, Supports }
import from walkers { MatchFinder, PledgeCommitter, MAX_CAUSE, LLM_WEIGHT, DET_WEIGHT, blend, geo_points, gift_bps, leverage_points, cause_points, excluded_by }

test "region ladder scores containment, not string equality" {
    assert geo_points("San Francisco Bay Area", "San Francisco Bay Area") == 25;
    assert geo_points("San Francisco Bay Area", "California") == 18;
    assert geo_points("San Francisco Bay Area", "United States") == 12;
    assert geo_points("San Francisco Bay Area", "Global") == 8;
    # An org scoped narrower than the donor may not serve her at all.
    assert geo_points("United States", "San Francisco Bay Area") == 0;
    assert geo_points("San Francisco Bay Area", "Mars") == 0;
}

test "leverage rewards the org where the gift is a bigger share" {
    small = gift_bps(3000000, 10000);
    large = gift_bps(350000000, 10000);
    assert small > large;
    assert leverage_points(small) > leverage_points(large);
    assert leverage_points(gift_bps(0, 10000)) == 5;
}

test "cause points require an overlap and stay inside the cap" {
    weights = {"climate": 3};
    assert cause_points(["housing"], weights) == 0;
    assert cause_points(["climate"], weights) == 35;
    # Overlapping on more of her causes scores higher, but never past the cap.
    both = cause_points(["climate", "food_security"], {"climate": 3, "food_security": 3});
    assert both > 35;
    assert both <= MAX_CAUSE;
}

test "exclusions match on mission text, case-insensitively" {
    mission = "Funds disruptive climate PROTEST and advocacy movements.";
    assert excluded_by("Some Fund", mission, ["protest"]) == "protest";
    assert excluded_by("Some Fund", mission, ["nuclear"]) == "";
    # An empty or whitespace exclusion must not match everything.
    assert excluded_by("Some Fund", mission, ["  "]) == "";
}

test "walker scores a candidate reachable through two hubs exactly once" {
    inv = Investor(
        name="TEST_dedupe",
        cause_areas=["climate", "food_security"],
        annual_budget=10000,
        geography="San Francisco Bay Area"
    );
    root ++> inv;

    climate = CauseHub(tag="climate");
    food = CauseHub(tag="food_security");
    inv +>:CaresAbout(weight=3):+> climate;
    inv +>:CaresAbout(weight=2):+> food;

    org = Nonprofit(
        name="TEST_dual_tagged",
        mission="Rescues surplus food and avoids methane emissions.",
        cause_tags=["climate", "food_security"],
        geography="San Francisco Bay Area",
        annual_budget=3000000
    );
    root ++> org;
    org +>:TaggedAs:+> climate;
    org +>:TaggedAs:+> food;

    rpt = (inv spawn MatchFinder(use_llm=False)).reports[0];

    assert rpt.investor == "TEST_dedupe";
    # Two hubs both lead to this org; it must be considered and scored once.
    assert rpt.considered == 1;
    assert len(rpt.matches) == 1;
    assert rpt.matches[0].name == "TEST_dual_tagged";
    # Both of her causes matched, so cause points beat a single-tag match.
    assert rpt.matches[0].cause_points > 35;
}

test "excluded candidates are filtered before scoring, and the walk continues" {
    inv = Investor(
        name="TEST_exclusion",
        cause_areas=["climate"],
        annual_budget=10000,
        geography="San Francisco Bay Area",
        exclusions=["protest"]
    );
    root ++> inv;

    hub = CauseHub(tag="climate");
    inv +>:CaresAbout(weight=3):+> hub;

    banned = Nonprofit(
        name="TEST_protest_org",
        mission="Funds disruptive climate protest movements.",
        cause_tags=["climate"],
        geography="Global",
        annual_budget=5000000
    );
    keeper = Nonprofit(
        name="TEST_clean_org",
        mission="Destroys abandoned refrigerant stockpiles.",
        cause_tags=["climate"],
        geography="Global",
        annual_budget=5000000
    );
    root ++> banned;
    root ++> keeper;
    banned +>:TaggedAs:+> hub;
    keeper +>:TaggedAs:+> hub;

    rpt = (inv spawn MatchFinder(use_llm=False)).reports[0];

    assert len(rpt.rejected) == 1;
    assert "TEST_protest_org" in rpt.rejected[0];
    # `skip` must end only the current ability - the other candidate still scores.
    assert len(rpt.matches) == 1;
    assert rpt.matches[0].name == "TEST_clean_org";
}

test "matches come back ranked high to low" {
    inv = Investor(
        name="TEST_ranking",
        cause_areas=["climate"],
        annual_budget=10000,
        geography="San Francisco Bay Area"
    );
    root ++> inv;

    hub = CauseHub(tag="climate");
    inv +>:CaresAbout(weight=3):+> hub;

    for spec in [("TEST_rank_big", 350000000, "Global"),
                 ("TEST_rank_mid", 15000000, "United States"),
                 ("TEST_rank_small", 3000000, "San Francisco Bay Area")] {
        org = Nonprofit(
            name=spec[0],
            mission="Reduces emissions.",
            cause_tags=["climate"],
            geography=spec[2],
            annual_budget=spec[1]
        );
        root ++> org;
        org +>:TaggedAs:+> hub;
    }

    rpt = (inv spawn MatchFinder(top_n=3, use_llm=False)).reports[0];

    assert len(rpt.matches) == 3;
    assert rpt.matches[0].name == "TEST_rank_small";
    assert rpt.matches[0].score > rpt.matches[1].score;
    assert rpt.matches[1].score > rpt.matches[2].score;
}

test "top_n caps how many matches come back but not how many are considered" {
    inv = Investor(
        name="TEST_topn",
        cause_areas=["climate"],
        annual_budget=10000,
        geography="San Francisco Bay Area"
    );
    root ++> inv;

    hub = CauseHub(tag="climate");
    inv +>:CaresAbout(weight=3):+> hub;

    for i in range(5) {
        org = Nonprofit(
            name=f"TEST_topn_org_{i}",
            mission="Reduces emissions.",
            cause_tags=["climate"],
            geography="Global",
            annual_budget=1000000 * (i + 1)
        );
        root ++> org;
        org +>:TaggedAs:+> hub;
    }

    rpt = (inv spawn MatchFinder(top_n=2, use_llm=False)).reports[0];

    assert rpt.considered == 5;
    assert len(rpt.matches) == 2;
    # The trace is the demo's proof of traversal - it must cover every candidate.
    assert len([l for l in rpt.trace if "TEST_topn_org_" in l]) == 5;
}


test "blend weights the model's read above the graph's arithmetic" {
    assert LLM_WEIGHT + DET_WEIGHT == 100;
    # Agreement is a no-op; disagreement lands nearer the model.
    assert blend(80, 80) == 80;
    assert blend(90, 40) == 70;
    assert blend(40, 90) == 60;
}

test "a candidate above the floor is reasoned and blended, one below is not" {
    # Exactly one candidate can clear this floor, so MockLLM needs exactly one
    # output and the assertions never depend on which order the walk visits in.
    ai.llm = MockLLM(model_name="mock", config={"outputs": [
        FitAssessment(score=40, rationale="mock rationale", concern="mock concern")
    ]});

    inv = Investor(
        name="TEST_llm",
        cause_areas=["climate"],
        annual_budget=10000,
        geography="San Francisco Bay Area"
    );
    root ++> inv;

    hub = CauseHub(tag="climate");
    inv +>:CaresAbout(weight=3):+> hub;

    for spec in [("TEST_llm_local", 3000000, "San Francisco Bay Area"),
                 ("TEST_llm_global", 350000000, "Global")] {
        org = Nonprofit(
            name=spec[0],
            mission="Reduces emissions.",
            impact_metric="tons abated",
            cause_tags=["climate"],
            geography=spec[2],
            annual_budget=spec[1]
        );
        root ++> org;
        org +>:TaggedAs:+> hub;
    }

    rpt = (inv spawn MatchFinder(llm_floor=90)).reports[0];

    by_name = {m.name: m for m in rpt.matches};
    local = by_name["TEST_llm_local"];
    other = by_name["TEST_llm_global"];

    # Cleared the floor: called, blended, and carrying the model's prose.
    assert local.reasoned;
    assert local.base_score == 95;
    assert local.llm_score == 40;
    assert local.score == blend(40, 95);
    assert local.score != local.base_score;
    assert local.rationale == "mock rationale";
    assert local.concern == "mock concern";

    # Below the floor: no call spent, deterministic score untouched.
    assert not other.reasoned;
    assert other.llm_score == 0;
    assert other.score == other.base_score;
    assert other.rationale == "";

    assert "below llm floor" in " ".join(rpt.trace);
}

test "use_llm=False runs the whole walk with no model at all" {
    # No MockLLM outputs queued: if the walker called the model here it would
    # raise, so passing proves the deterministic fallback demo is truly offline.
    ai.llm = MockLLM(model_name="mock", config={"outputs": []});

    inv = Investor(
        name="TEST_nollm",
        cause_areas=["climate"],
        annual_budget=10000,
        geography="San Francisco Bay Area"
    );
    root ++> inv;

    hub = CauseHub(tag="climate");
    inv +>:CaresAbout(weight=3):+> hub;

    org = Nonprofit(
        name="TEST_nollm_org",
        mission="Reduces emissions.",
        impact_metric="tons abated",
        cause_tags=["climate"],
        geography="San Francisco Bay Area",
        annual_budget=3000000
    );
    root ++> org;
    org +>:TaggedAs:+> hub;

    rpt = (inv spawn MatchFinder(use_llm=False)).reports[0];

    assert len(rpt.matches) == 1;
    assert not rpt.matches[0].reasoned;
    assert rpt.matches[0].score == 95;
}

test "PledgeCommitter finds the org two hops out, writes back, and stops" {
    inv = Investor(
        name="TEST_pledge_donor",
        cause_areas=["climate"],
        annual_budget=10000,
        geography="San Francisco Bay Area"
    );
    root ++> inv;

    hub = CauseHub(tag="climate");
    inv +>:CaresAbout(weight=3):+> hub;

    target = Nonprofit(
        name="TEST_pledge_target",
        mission="Reduces emissions.",
        cause_tags=["climate"],
        geography="San Francisco Bay Area",
        annual_budget=3000000
    );
    other = Nonprofit(
        name="TEST_pledge_other",
        mission="Reduces emissions.",
        cause_tags=["climate"],
        geography="San Francisco Bay Area",
        annual_budget=3000000
    );
    root ++> target;
    root ++> other;
    target +>:TaggedAs:+> hub;
    other +>:TaggedAs:+> hub;

    walked = inv spawn PledgeCommitter(
        target_name="TEST_pledge_target",
        amount=10000,
        rationale="test rationale"
    );

    assert len(walked.reports) == 1;
    receipt = walked.reports[0];
    assert receipt.investor == "TEST_pledge_donor";
    assert receipt.nonprofit == "TEST_pledge_target";
    assert receipt.amount == 10000;
    assert receipt.timestamp != "";

    # Written back into the graph, not just returned in the report.
    pledges = [inv ->:PledgedTo:->];
    assert len(pledges) == 1;
    assert pledges[0].rationale == "test rationale";
    supported = [pledges[0] ->:Supports:->];
    assert len(supported) == 1;
    assert supported[0].name == "TEST_pledge_target";
}

test "PledgeCommitter reports nothing when the name never matches" {
    inv = Investor(
        name="TEST_pledge_miss",
        cause_areas=["climate"],
        annual_budget=10000,
        geography="San Francisco Bay Area"
    );
    root ++> inv;

    hub = CauseHub(tag="climate");
    inv +>:CaresAbout(weight=3):+> hub;

    org = Nonprofit(
        name="TEST_pledge_present",
        mission="Reduces emissions.",
        cause_tags=["climate"],
        geography="San Francisco Bay Area",
        annual_budget=3000000
    );
    root ++> org;
    org +>:TaggedAs:+> hub;

    walked = inv spawn PledgeCommitter(target_name="TEST_pledge_absent", amount=10000);

    assert len(walked.reports) == 0;
    assert len([inv ->:PledgedTo:->]) == 0;
}
