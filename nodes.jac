# Graph schema for AlmsMatch.
# Every edge declares its endpoint types so traversal reads infer the right node
# type with no per-read [?:NodeType] filter (see CLAUDE.md convention 4).

node Investor {
    has name: str;
    has cause_areas: list[str] = [];
    has annual_budget: int = 0;
    has geography: str = "";
    has values_statement: str = "";
    has exclusions: list[str] = [];
}

node Nonprofit {
    has name: str;
    has mission: str = "";
    has cause_tags: list[str] = [];
    has geography: str = "";
    has annual_budget: int = 0;
    has impact_metric: str = "";
    has ein: str = "";

    # 501(c)(3) tax-exempt status, resolved from the IRS Business Master File via
    # ProPublica and cached in fixtures/irs_verification.json. This is live registry
    # data, not something a language model can answer from training data - which is
    # exactly why it is a graph field and a deterministic gate rather than an LLM
    # question.
    #
    # "verified"   - currently in the BMF as a 501(c)(3), exemption in force,
    #                contributions deductible.
    # "unverified" - could not confirm the above. NOT an accusation of wrongdoing;
    #                it also covers orgs that are simply not 501(c)(3)s at all.
    # "revoked"    - tax-exempt status revoked, so gifts are no longer deductible.
    #                Applied ONLY to the synthetic test fixture, never to a real org.
    has verification_status: str = "unverified";
    has last_990_filing_year: int = 0;
    # When the verification snapshot was taken, so a stale cache is visible rather
    # than silently presented as current.
    has verification_source: str = "";
    # True only for the single clearly-labeled fictional record used to demonstrate
    # the revoked-exclusion path. Real organizations always have this False.
    has synthetic: bool = False;
}

# One hub per cause area. This is what makes the match traversal a real two-hop
# graph walk (Investor -> CauseHub -> Nonprofit) instead of a flat list scan.
node CauseHub {
    has tag: str;
}

node Region {
    has name: str;
}

node Pledge {
    has amount: int;
    has rationale: str = "";
    has timestamp: str = "";
}

edge CaresAbout: Investor --> CauseHub {
    has weight: int = 1;
}

edge TaggedAs: Nonprofit --> CauseHub {
    has weight: int = 1;
}

edge OperatesIn: Nonprofit --> Region {}

# A Pledge is a first-class node, so the investor->nonprofit link is two typed
# edges through it rather than one edge carrying the payload.
edge PledgedTo: Investor --> Pledge {}

edge Supports: Pledge --> Nonprofit {}
