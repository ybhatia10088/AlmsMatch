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
