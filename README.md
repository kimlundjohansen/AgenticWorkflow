# Agentic Workflow

An opinionated, end-to-end loop for going from a rough idea to merged code with
AI coding agents. You do the **thinking and planning interactively** with an
assistant (Claude Code or GitHub Copilot), then hand the resulting work off to
an **autonomous "Ralph loop"** that grinds through the issues unattended.

The flow has two phases:

1. **Plan, interactively** — using three skills, in order: `/grill-me` →
   `/to-prd` → `/to-issues`.
2. **Execute, autonomously** — exit the assistant and start the Ralph loop with
   `afk-claude.sh` or `afk-copilot.sh`.

The skills live in [`.claude/skills/`](.claude/skills) and the loop scripts in
[`ralph/`](ralph).

---

## Phase 1 — Plan (interactive, inside the assistant)

Run these three skills in this exact order, in a single working session with
your AI assistant. Each one feeds the next.

### 1. `/grill-me` — stress-test the idea

> Interview me relentlessly about every aspect of this plan until we reach a
> shared understanding.

Start here with nothing more than a rough idea. The assistant interviews you
**one question at a time**, walking down each branch of the design tree and
resolving dependencies between decisions before moving on. For every question it
offers a recommended answer (numbered), and it explores the codebase rather than
asking you things it can find out itself.

**Goal:** leave this step with the plan fully pinned down — no hand-waving, no
unresolved forks. The conversation you build here is the raw material for the
PRD.

### 2. `/to-prd` — capture the plan as a PRD

> Turn the current conversation context into a PRD and publish it as a GitHub
> issue.

This synthesizes the grilling conversation into a **Product Requirements
Document** and publishes it as a GitHub issue. It does **not**
re-interview you — it works from what `/grill-me` already established.

Along the way it will:

- Sketch the major modules to build/modify and confirm them with you.
- Ensure the working folder is a git repo wired to a GitHub remote (running
  `git init` / `gh repo create` if needed) — because all downstream tooling
  resolves the target repo from the git remote.
- Write the PRD (problem, solution, user stories, implementation & testing
  decisions, out-of-scope) and create the issue.

**Output:** a PRD issue URL. It deliberately does **not** label the PRD yet.

### 3. `/to-issues <PRD-number>` — break the PRD into sub-issues

> Break a PRD into native GitHub sub-issues attached to the parent PRD.

Pass the PRD issue number from the previous step. This breaks the PRD into a
flat, ordered list of **tracer-bullet vertical slices** — each a thin but
complete cut through every layer (schema → API → UI → tests) that's demoable on
its own. It quizzes you on granularity and ordering until you approve, then
publishes each slice as a native GitHub sub-issue attached to the PRD.

**Important:** every sub-issue is created with the **`afk`** label. That label is
exactly what the Ralph loop picks up — so when `/to-issues` finishes, your work
is already queued and ready to run. No manual triage step is required.

---

## Phase 2 — Execute (autonomous, the Ralph loop)

Once the sub-issues exist, **exit the AI coding assistant** and hand the queue to
the Ralph loop. The loop runs an agent inside a Docker sandbox, picks up the next
`afk`-labeled issue, implements it, runs the feedback loops, commits, pushes, and
closes the issue — then repeats for the number of iterations you give it.

Pick the runner for your agent of choice (both are equivalent in behavior):

```bash
# Claude Code, in a docker sandbox
./ralph/afk-claude.sh <iterations>

# GitHub Copilot, in a docker sandbox
./ralph/afk-copilot.sh <iterations>
```

`<iterations>` is a positive integer — the maximum number of issues to work
through in this run.

### What each iteration does

Driven by [`ralph/prompt.md`](ralph/prompt.md), every iteration:

1. **Loads context** — the last few git commits and all open issues labeled
   `afk` (issues labeled `hitl` are human-in-the-loop and ignored).
2. **Selects one task**, prioritized: critical bugfixes → dev infrastructure →
   tracer bullets for new features → polish/quick wins → refactors.
3. **Implements it** using the `/tdd` (red-green-refactor) skill.
4. **Runs feedback loops** — `dotnet test` and a clean, warning-free
   `dotnet build` — before committing.
5. **Commits** with a message recording key decisions, files changed, and notes
   for the next iteration; then **pushes**.
6. **Closes the issue** if complete; otherwise leaves it open with notes so the
   next iteration resumes where it left off.

The loop works on **a single task per iteration** and stops early — emitting
`<promise>NO MORE TASKS</promise>` — once no open `afk` issues remain.

### Prerequisites for the loop

- **Docker** (Docker Desktop) running — the agent executes in `docker sandbox`.
- **GitHub CLI (`gh`)** authenticated. If a stale `GITHUB_TOKEN` is set in your
  environment it will override the keyring login and cause 401s; the scripts
  `unset` it for you, but if you need a token set `GH_TOKEN` instead.
- The relevant agent CLI available to the sandbox (`claude` or `copilot`).


---

## The label model at a glance

| Label             | Triggers                          | Where it runs                    |
| ----------------- | --------------------------------- | -------------------------------- |
| `afk`             | The local Ralph loop (this repo)  | Docker sandbox on your machine   |
| `hitl`            | Nothing — human-in-the-loop only  | Skipped by the Ralph loop        |

`/to-issues` applies **`afk`** automatically, so the Ralph loop is ready to go
straight after planning. **`agent:implement`** is an optional, parallel
execution path: instead of (or in addition to) running the loop locally, you can
apply `agent:implement` to the **parent PRD** and let GitHub Actions implement
the sub-issues in the cloud. Both consume the same sub-issues — pick whichever
runner you prefer.

---

## TL;DR

```text
idea
  └─ /grill-me            interview until the plan is fully resolved
       └─ /to-prd         publish the plan as a PRD issue
            └─ /to-issues <PRD#>   break it into afk-labeled sub-issues
                 └─ exit the assistant
                      └─ ./ralph/afk-claude.sh <n>   (or afk-copilot.sh)
                           └─ autonomous: implement → test → commit → push → close
```
