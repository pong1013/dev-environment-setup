---
name: harness-feedback
description: Turn evidence from a completed change, bug fix, review, or repeated agent mistake into a focused improvement to this repository's AGENTS.md, Skills, tests, or verification. Use for Harness retrospectives and maintenance, not as a mandatory step for every ordinary edit.
---

# Harness Feedback

Inspect the concrete evidence first: the failed test, review comment, correction, or recent commit. For a working-tree audit, inspect `git status`, unstaged changes, staged changes, and relevant untracked files so new Harness files are not omitted. Do not add a rule based only on speculation.

## Route the lesson

- Add or strengthen a deterministic test/check when a machine can recognize the failure.
- Update root `AGENTS.md` only for a short, repository-wide rule that should affect nearly every future task.
- Update an existing Skill for recurring, task-specific judgment or workflow knowledge.
- Create a new Skill only when the capability has a distinct trigger and enough reusable guidance to justify a separate entry.
- Put architecture explanations in `PROJECT_STRUCTURE.md`; keep them out of always-loaded instructions unless they change routine decisions.

Prefer the smallest durable update. State each rule once, replace obsolete guidance, and avoid recording one-off implementation details. Phrase guidance as an observable behavior or decision boundary rather than a vague aspiration.

## Close the loop

- Check that `AGENTS.md` remains short and that each Skill description has a precise trigger.
- Run `make verify` after repository changes.
- Treat `scripts/validate-skills.rb`, invoked by `make verify`, as this repository's canonical Skill validator. Extend its tests when adding a new validation rule.
- Summarize the evidence that justified the Harness change. If the current controls already cover the lesson, recommend no update.
