# Shortage Consequences v0

Status: active contract.

Shortage consequences belong to a cohort need, Facility recipe, or process definition. A goods id has no global social meaning. Every required Facility resource declares exactly one `block` or `reduced_output` consequence, optionally one positive-delay `retry`, explicit `cohort_delta` effects, or `none` when there is no social effect.

`block` preserves atomicity. `reduced_output` uses an explicit permille multiplier. `retry` creates a new WorldClock event with a new id and positive delay and never guarantees success. `cohort_delta` names the cohort, condition, unrest/workforce deltas, and `once_per_episode` or `each_attempt` application. `none` cannot accompany a cohort delta.

Blocked, degraded, shortage, and recovered results are explicit. Active episode keys are saved. Recovery clears an episode, preventing duplicate once-per-episode effects while allowing a genuinely later shortage to start another episode. JSON snapshots retain policies, episodes, queue state, and processed event ids for deterministic continuation.

Final balance and a historical goods catalogue are outside v0.
