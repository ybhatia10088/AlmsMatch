# AlmsMatch - entry point, graph bootstrap, and graph inspection.
# Phase 1: schema + seed data. The matching walker lands in walkers.jac (Phase 2).

import json;
import io;
import from contextlib { redirect_stdout }
import from nodes { Investor, Nonprofit, CauseHub, Region, TaggedAs, CaresAbout, OperatesIn }
import from walkers { MatchFinder, MatchReport, MatchResult }


def load_seed(path: str) -> dict[str, any] {
    with open(path) as fh {
        return json.load(fh) as dict[str, any];
    }
}


# Priya - the one named user the whole product is built around. Seeded into the
# graph so the demo never depends on typing a profile on stage.
def priya() -> Investor {
    return Investor(
        name="Priya",
        cause_areas=["climate"],
        annual_budget=10000,
        geography="San Francisco Bay Area",
        values_statement="I want my giving to go where a small amount of money still changes the outcome. I care about measurable carbon reduction over awareness campaigns, and I would rather fund an unglamorous operational fix than a brand name.",
        exclusions=["protest"]
    );
}


walker Seeder {
    has data_path: str = "seed_data.json";
    has hubs_created: int = 0;
    has regions_created: int = 0;
    has orgs_created: int = 0;
    has already_seeded: bool = False;
    has reports: list[str] = [];

    can seed with Root entry {
        # `jac run` persists the graph in .jac/, so a second run would duplicate
        # every node. Bail out if the hubs are already there.
        if [here -->[?:CauseHub]] {
            self.already_seeded = True;
            skip;
        }

        payload = load_seed(self.data_path);

        hub_by_tag: dict[str, CauseHub] = {};
        for tag in (payload["cause_areas"] as list[str]) {
            hub = CauseHub(tag=tag);
            here ++> hub;
            hub_by_tag[tag] = hub;
            self.hubs_created += 1;
        }

        region_by_name: dict[str, Region] = {};
        for rname in (payload["regions"] as list[str]) {
            region = Region(name=rname);
            here ++> region;
            region_by_name[rname] = region;
            self.regions_created += 1;
        }

        for rec in (payload["nonprofits"] as list[dict[str, any]]) {
            org_tags = rec["cause_tags"] as list[str];
            geo = rec["geography"] as str;

            org = Nonprofit(
                name=rec["name"] as str,
                mission=rec["mission"] as str,
                cause_tags=org_tags,
                geography=geo,
                annual_budget=rec["annual_budget"] as int,
                impact_metric=rec["impact_metric"] as str,
                ein=rec["ein"] as str
            );
            here ++> org;
            self.orgs_created += 1;

            for tag in org_tags {
                if tag in hub_by_tag {
                    org +>:TaggedAs(weight=1):+> hub_by_tag[tag];
                }
            }
            if geo in region_by_name {
                org +>:OperatesIn:+> region_by_name[geo];
            }
        }

        investor = priya();
        here ++> investor;
        for tag in investor.cause_areas {
            if tag in hub_by_tag {
                investor +>:CaresAbout(weight=3):+> hub_by_tag[tag];
            }
        }
    }

    can finish with Root exit {
        if self.already_seeded {
            report "seed: graph already populated, no changes made";
        } else {
            report f"seed: {self.hubs_created} CauseHub, {self.regions_created} Region, {self.orgs_created} Nonprofit, 1 Investor";
        }
    }
}


walker GraphStats {
    has lines: list[str] = [];
    has reports: list[list[str]] = [];

    can survey with Root entry {
        investors = [here -->[?:Investor]];
        hubs = [here -->[?:CauseHub]];
        regions = [here -->[?:Region]];
        orgs = [here -->[?:Nonprofit]];

        self.lines.append(
            f"nodes: {len(investors)} Investor | {len(hubs)} CauseHub | {len(regions)} Region | {len(orgs)} Nonprofit"
        );

        self.lines.append("cause hubs (incoming TaggedAs):");
        for hub in hubs {
            members = [hub <-:TaggedAs:<-];
            names = [o.name for o in members];
            self.lines.append(f"  {hub.tag}: {len(members)} -> {', '.join(names)}");
        }

        self.lines.append("regions (incoming OperatesIn):");
        for region in regions {
            based = [region <-:OperatesIn:<-];
            self.lines.append(f"  {region.name}: {len(based)}");
        }

        self.lines.append("investors (outgoing CaresAbout):");
        for inv in investors {
            cares = [inv ->:CaresAbout:->];
            tags = [h.tag for h in cares];
            self.lines.append(
                f"  {inv.name}: budget ${inv.annual_budget}, {inv.geography}, cares about {tags}, excludes {inv.exclusions}"
            );
        }

        # Hop-1 then hop-2 in a single multi-hop read - the candidate pool the
        # Phase 2 MatchFinder will actually walk.
        for inv in investors {
            pool = [inv ->:CaresAbout:-> <-:TaggedAs:<-];
            self.lines.append(f"  {inv.name} two-hop candidate pool: {len(pool)} nonprofits");
        }
    }

    can finish with Root exit {
        report self.lines;
    }
}


def show_matches(rpt: MatchReport) {
    print("");
    print(f"--- traversal trace for {rpt.investor} ---");
    for line in rpt.trace {
        print(line);
    }
    print("");
    print(f"--- top {len(rpt.matches)} matches ---");
    rank = 1;
    for m in rpt.matches {
        print(f"{rank}. {m.name}  [{m.score}/100]  {m.geography}");
        for s in m.signals {
            print(f"      {s}");
        }
        rank += 1;
    }
    if rpt.rejected {
        print("");
        print("--- filtered out before scoring ---");
        for r in rpt.rejected {
            print(f"  {r}");
        }
    }
}


with entry:__main__ {
    # Every `report` is echoed to stdout at the spawn boundary, which buries the
    # readable output under raw reprs. No walker here prints - they all
    # accumulate into `has` fields - so muting stdout across the spawns drops
    # only the echo. Under `jac start` reports become the HTTP body instead.
    bootstrap = io.StringIO();
    with redirect_stdout(bootstrap) {
        seeded = root spawn Seeder();
        stats = root spawn GraphStats();
    }

    print("--- AlmsMatch graph ---");
    print(seeded.reports[0] if seeded.reports else "seed: no report");
    for line in (stats.reports[0] if stats.reports else []) {
        print(line);
    }

    # The match itself: spawn the walker ON Priya's node and let it walk.
    # Select her by name, not "every Investor under root" - `jac test` leaves its
    # own fixture investors attached to the same persisted root, and the demo
    # must show one person's matches, not whatever the last test run left behind.
    for inv in [root -->[?:Investor, name == "Priya"]] {
        sink = io.StringIO();
        with redirect_stdout(sink) {
            found = inv spawn MatchFinder(top_n=5);
        }
        if found.reports {
            show_matches(found.reports[0]);
        }
    }
}
