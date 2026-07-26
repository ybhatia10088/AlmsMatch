node Cause { has tag: str; }
node Org { has name: str; }
edge TaggedAs: Org --> Cause { has weight: int = 1; }

walker Probe {
    has seen: list[str] = [];
    has reports: list[list[str]] = [];

    can start with Cause entry {
        self.seen.append(f"cause:{here.tag}");
        visit [<-:TaggedAs:<-];
    }

    can org with Org entry { self.seen.append(f"org:{here.name}"); }

    can done with Cause exit { report self.seen; }
}

with entry:__main__ {
    climate = Cause(tag="climate");
    org = Org(name="Rainforest Trust");
    root ++> climate;
    org +>:TaggedAs(weight=3):+> climate;
    res = climate spawn Probe();
    print(res.reports[0] if res.reports else "NO REPORTS");
}
