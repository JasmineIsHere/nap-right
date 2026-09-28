# Feature development workflow

For every new feature, follow **Explore → Plan → Code → Commit** in order.
Treat the requirements below as gates: do not proceed until the preceding gate
is satisfied. Do not silently omit a step or claim a check was performed without
evidence. Report unavailable prerequisites and stop work that depends on them.

## Explore and Plan

1. Read applicable repository instructions and inspect the relevant code, tests,
   dependencies, and call sites before proposing an implementation.
2. Use Plan mode for exploration and planning. If the session cannot enable it,
   ask the user to enable it; do not describe ordinary planning as Plan mode or
   silently substitute it. An explicitly authorized substitute is acceptable.
3. Write a concrete plan covering requirements, scope, implementation approach,
   success criteria, validation, and material risks.
4. Have a reviewer agent review the plan using the `review-agent` skill with
   custom instructions to assess requirement coverage, feasibility, and critical
   issues. Resolve actionable findings and obtain explicit plan approval before
   starting the Code phase.

## Code

1. Confirm measurable success criteria before writing code. Derive any missing
   criteria from the approved plan and clarify unresolved requirements.
2. Identify required tools and verify access to them before dependent work.
3. Create the feature's test suite before implementation. Tests must exercise
   success criteria, relevant failure cases, and regression risks. Verify that
   new-behavior tests fail for the intended reason before implementation where
   applicable, rather than because of unrelated setup failures.
4. Have a reviewer agent review the test suite at least once using the
   `review-agent` skill. Give custom instructions to check for false positives,
   false negatives, missing requirement coverage, and meaningful assertions.
   Resolve actionable findings before implementation begins.
5. Implement the approved plan and continuously validate with the reviewed tests.
   If requirements or the approach materially change, update the plan and tests
   and repeat the affected review gates.
6. Run the complete feature test suite and relevant existing checks after
   implementation. Fix failures before requesting final approval.

## Commit

1. Request at least one final code review from a fresh reviewer agent session
   without inherited main-agent conversation history (use `fork_turns="none"`
   when spawning a subagent).
2. Supply the requirements, approved plan, success criteria, review target, and
   validation evidence. Let the reviewer independently inspect the full change
   and surrounding code rather than relying on the author's conclusions.
3. Resolve actionable findings, rerun affected checks, and obtain review of the
   fixes before committing. Commit only after required tests pass and the
   reviewer explicitly approves the final change. Do not treat silence or an
   incomplete review as approval.
4. Commit the feature changes to the repository, preserving unrelated user work.
   This workflow does not authorize pushing, merging, or publishing.

## Reviewer skill and independence

Use the built-in `review-agent` skill at:

`/Users/jasminetan/.codex/skills/.system/review-agent/SKILL.md`

Read the skill when applying it. If unavailable, search for it and report the
missing prerequisite rather than silently substituting a different review.
The workflow explicitly authorizes reviewer subagents for these review steps.
Reviewers must remain read-only: they must not edit files, commit, push, post
external review comments, or delegate their review to another agent.

For plan reviews, adapt the target and findings format to the plan using custom
review instructions. For test and code reviews, inspect the complete requested
diff and relevant tests and call sites. Follow the skill's defect-first approach,
severity ordering, and requirement to report every concrete actionable finding.
Report `No findings.` when appropriate, followed by an overall assessment and
material test gaps or residual risks. Request an explicit approval decision in
addition to the findings.

## Evidence and enforcement

Maintain a visible gate checklist in the task and record:

- The plan and measurable success criteria.
- Required tools and verified availability.
- Each reviewer result and how findings were resolved.
- Validation commands and their actual outcomes.
- Final reviewer approval and the resulting commit hash.

Do not mark a gate complete without supporting evidence. If blocked, state the
specific prerequisite and what is needed to continue. These instructions are
procedural safeguards, not mechanical enforcement. Do not claim that CI,
branch protection, or automated merge checks exist unless verified; configuring
them is separate work.
