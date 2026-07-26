# The reasoning layer. `score_fit` has no body: `by llm()` IS the implementation,
# and the Jac type system is the output schema - byLLM turns FitAssessment into a
# strict JSON schema, sends it with the request, and validates the reply against it.
# A malformed reply is retried with corrective feedback before it ever reaches the
# walker, so MatchFinder only ever sees a well-typed FitAssessment.
#
# No `glob llm` here on purpose. `llm` is an ambient builtin whose model comes from
# jac.toml [plugins.byllm.model], so the model is swappable from the environment
# (LLM_MODEL=claude-haiku-4-5) with no edit to this file.

obj FitAssessment {
    has score: int;
    has rationale: str;
    has concern: str;
}

# These `sem` strings are not comments - they are shipped to the model twice: as the
# `description` on each JSON-schema property, and as a prose "Schema requirements"
# block appended to the prompt. This is the whole quality lever on the output.
sem FitAssessment.score = """
How well this nonprofit fits this specific donor, 1-100. Judge only from the mission
text and impact metric provided. Reserve 85+ for a mission that directly serves what
the donor said they want; score below 40 when the text does not support a real match.
""";
sem FitAssessment.rationale = """
One sentence, addressed to the donor as "you", that quotes or names something concrete
from the mission text or impact metric - a specific activity, mechanism, or unit of
measurement. Never generic praise, never outside knowledge about the organization.
""";
sem FitAssessment.concern = """
One honest, specific reason this might not be the right fit for this donor, drawn from
the same text. Never fabricate a flaw; if the real concern is scale or fit with the
donor's stated priorities, say that plainly.
""";

def score_fit(
    values_statement: str,
    exclusions: list[str],
    mission: str,
    impact_metric: str,
    leverage_note: str
) -> FitAssessment by llm(temperature=None);
# `temperature=None` is load-bearing, not a leftover. claude-sonnet-5 rejects the
# parameter outright - HTTP 400 "`temperature` is deprecated for this model" - and
# byLLM ALWAYS puts a temperature in the request, defaulting to 0.7 from
# [plugins.byllm.call_params] when the call site omits it (basellm.impl.jac:1119).
# So plain `by llm()` still 400s. Passing None is what drops the key on the wire.
# litellm's own `drop_params` does not catch this: its capability map still
# believes every Anthropic model takes a temperature.

sem score_fit = """
Assess how well one nonprofit fits one individual donor. Ground every claim in the
mission text and impact metric given to you - never in general knowledge about the
organization, and never in its reputation. If the mission text does not support a
strong match, say so honestly and score low. An unglamorous operational fix that
directly serves the donor's stated goal outranks a famous organization whose text
only vaguely relates.
""";
sem score_fit.values_statement = "The donor's own words about what they want their giving to accomplish.";
sem score_fit.exclusions = "Kinds of work this donor does not want to fund. Treat as hard limits.";
sem score_fit.mission = "The nonprofit's mission statement, verbatim. The only source of truth about what it does.";
sem score_fit.impact_metric = "The unit this nonprofit measures its own results in.";
sem score_fit.leverage_note = "How large the donor's gift is relative to this nonprofit's annual budget.";
