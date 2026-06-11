---
name: to-prd
description: Turn the current conversation context into a PRD and publish it as a GitHub issue that is ready to receive sub-issues from /to-issues.
---

This skill writes a PRD and publishes it as a GitHub issue, creating the repo under the user's GitHub account if it does not yet exist. Labeling happens _after_ sub-issues have been created.

**Resolving the GitHub owner.** Do not hardcode an org. Resolve `<owner>` (used throughout below) in this order:

1. If the user passed an owner as an argument, use it.
2. Otherwise, resolve the authenticated account: `gh api user --jq '.login'` (or read it from `gh auth status`).
3. If that fails or the user belongs to multiple orgs and intent is ambiguous, ask the user which owner to publish under.

Do NOT interview the user — just synthesize what you already know from the conversation. If context is thin, ask the user to talk through the problem first; don't run the skill on an empty plate.

## Process

1. **Explore the repo** to understand the current state of the codebase, if you haven't already. Use the project's domain glossary (`CONTEXT.md`) and respect ADRs under `docs/adr/` for areas you're touching.

2. **Sketch the major modules** you'd build or modify. Actively look for opportunities to extract deep modules that can be tested in isolation. A deep module encapsulates a lot of functionality behind a simple, testable interface that rarely changes.

   Check with the user that these modules match their expectations and which they want tests written for.

3. **Ensure the working folder is a git repo wired to a GitHub remote.** `gh issue create` (and downstream tooling like `ralph/afk.sh`) resolves the target repo from the current directory's git remote, so this must exist before publishing.

   - If `git rev-parse --is-inside-work-tree` fails, the working folder is not yet a git repo: run `git init` in the working folder and use the **working folder's basename** as the repo name (e.g. `C:\Dev\Kim\TodoApp` → `TodoApp`) without asking the user.
   - If the folder is already a git repo, derive the repo name from its `origin` remote when one is set; otherwise fall back to the working folder's basename.
   - The repo lives under the resolved `<owner>` (see "Resolving the GitHub owner" above).
   - If the GitHub repo does not already exist, create it: `gh repo create <owner>/<repo> --private --source . --remote origin`. This both creates the remote repo and wires up `origin` in one step.
   - If the repo already exists but `origin` is not set locally, add it: `git remote add origin https://github.com/<owner>/<repo>.git`.
   - Verify with `git remote -v` and `gh repo view <owner>/<repo>` before continuing.

   Note: if a `GITHUB_TOKEN` environment variable is set but invalid, `gh` will fail auth even when the keyring login is valid. Check `gh auth status`; if `GITHUB_TOKEN` is the active-but-invalid source, instruct the user to `unset GITHUB_TOKEN` (or fix it) so the keyring account is used.

4. **Write the PRD** using the template below and publish it via `gh issue create`. Use a heredoc for the body. Add no labels unless the user asks.

5. **Output the issue URL** so the user can pass it to `/to-issues` next.

## PRD template

The PRD will be read by:

- **Humans** deciding whether the plan is sound.
- **`/to-issues`** when breaking it into sub-issues.
- The **PRD-mode implement workflow** at the start of each sub-issue run (the prompt pulls in the PRD body for context).
- The **review workflow** when checking "does the PR match the spec?"

So the PRD must be a _spec_, not a sketch — concrete enough that a sub-issue agent can implement against it without re-deriving decisions.

<prd-template>

## Problem Statement

The problem the user is facing, from the user's perspective.

## Solution

The solution to the problem, from the user's perspective.

## User Stories

A LONG, numbered list of user stories. Each in the format:

1. As a &lt;actor&gt;, I want &lt;feature&gt;, so that &lt;benefit&gt;

This list should cover all aspects of the feature.

## Implementation Decisions

A list of implementation decisions, including:

- The modules to build/modify
- The interfaces of those modules
- Technical clarifications from the developer
- Architectural decisions
- Schema changes
- API contracts
- Specific interactions

Do **not** include specific file paths or code snippets. They go stale fast.

Exception: if a prototype produced a snippet that encodes a decision more precisely than prose can (state machine, reducer, schema, type shape), inline it within the relevant decision and note that it came from a prototype. Trim to the decision-rich parts.

## Testing Decisions

- What makes a good test in this codebase (only external behavior, not implementation details)
- Which modules will be tested
- Prior art (similar tests in the codebase)

## Out of Scope

Things explicitly excluded from this PRD. Be specific — "we are not building X" rather than "X is out of scope."

## Further Notes

Anything else worth recording: open questions, known risks, deferred decisions.

</prd-template>

## After publishing

- Tell the user: "PRD published at &lt;URL&gt;. Run `/to-issues &lt;issue-number&gt;` to break it into sub-issues, then run a Ralph loop to start work."