# AlmsMatch REST surface. `jac start api.jac --no_client` serves this.
#
# Anonymous callers land on the shared guest root (`root.shared`), which is a
# different persisted graph than `jac run main.jac`'s root - so every public
# endpoint seeds itself via `ensure_seeded`, the same idempotent logic
# main.jac's Seeder walker uses for the CLI demo.
#
# `ensure_seeded` is a plain `def`, not the `Seeder` walker, on purpose: a
# `report`-emitting walker spawned from inside a `walker:pub` ability still
# writes into that request's HTTP response report channel (verified
# empirically), so spawning Seeder here would inject a stray "already seeded"
# string ahead of every real MatchReport/PledgeReceipt in the API response.
#
# Nothing in this file makes the matching or pledging decision. It looks up
# the right Investor node and hands off to `spawn MatchFinder` / `spawn
# PledgeCommitter` - the walkers already doing that work in walkers.jac.

import from main { ensure_seeded, priya }
import from nodes { Investor, CauseHub, CaresAbout }
import from walkers { MatchFinder, MatchReport, PledgeCommitter, PledgeReceipt }


# Read-only prefill so Priya's profile is typed once, in main.jac, and never
# duplicated into frontend JS. The returned node is intentionally never
# attached to root - it is display data, not something we want persisted.
def:pub demo_profile() -> Investor {
    return priya();
}


walker:pub find_matches {
    has name: str = "";
    has cause_areas: list[str] = [];
    has annual_budget: int = 10000;
    has geography: str = "";
    has values_statement: str = "";
    has exclusions: list[str] = [];
    has top_n: int = 5;
    has use_llm: bool = True;

    has reports: list[MatchReport] = [];

    can run with Root entry {
        ensure_seeded(here);

        existing = [here -->[?:Investor, name == self.name]];
        if existing {
            investor = existing[0];
        } else {
            investor = Investor(
                name=self.name,
                cause_areas=self.cause_areas,
                annual_budget=self.annual_budget,
                geography=self.geography,
                values_statement=self.values_statement,
                exclusions=self.exclusions
            );
            here ++> investor;
            hub_by_tag = {h.tag: h for h in [here -->[?:CauseHub]]};
            for tag in self.cause_areas {
                if tag in hub_by_tag {
                    investor +>:CaresAbout(weight=3):+> hub_by_tag[tag];
                }
            }
        }

        result = investor spawn MatchFinder(top_n=self.top_n, use_llm=self.use_llm);
        if result.reports {
            self.reports.append(result.reports[0]);
        }
    }
}


walker:pub commit_pledge {
    has investor_name: str = "";
    has target_name: str = "";
    has amount: int = 0;
    has rationale: str = "";

    has reports: list[PledgeReceipt] = [];

    can run with Root entry {
        matches = [here -->[?:Investor, name == self.investor_name]];
        if matches {
            result = matches[0] spawn PledgeCommitter(
                target_name=self.target_name,
                amount=self.amount,
                rationale=self.rationale
            );
            if result.reports {
                self.reports.append(result.reports[0]);
            }
        }
    }
}
