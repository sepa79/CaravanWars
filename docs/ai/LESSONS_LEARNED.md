# Lessons Learned

Prefer storing lessons in HiveMind.

Use this file only:
- when HiveMind is unavailable,
- for portable repository-level lessons,
- for recurring production/project failure patterns that should travel with the repo.

Keep entries short and actionable.

## Template

```text
Date: YYYY-MM-DD
Area: TODO
Lesson: TODO
Trigger: TODO
Rule/Action: TODO
```

Date: 2026-07-23
Area: Devbox Git history
Lesson: A full clone from the Devbox worktree can fail because historical promisor blobs are no longer available from the original lazy-fetch remote, even while the checked-out active worktree is healthy.
Trigger: Preparing an isolated worktree or migration from `/home/sepa/CaravanWars`.
Rule/Action: Verify the canonical worktree first. Keep feature work separate from history repair; transfer an explicit current-file set or repair the promisor history as its own reviewed task. Never hide missing objects with a fallback clone.
