# ISSUES

Open GitHub issues are provided at the start of context (fetched via the `gh` CLI). Parse them to understand the open issues. You can also query GitHub directly at any time, e.g. `gh issue list --state open` or `gh issue view <number>`.

You will work on issues labeled `afk` only. Ignore issues labeled `hitl` (those are human-in-the-loop and not for you).

You've also been passed the last few commits. Review these to understand what work has been done.

If there are no open `afk` issues left, output <promise>NO MORE TASKS</promise>.

# TASK SELECTION

Pick the next task. Prioritize tasks in this order:

1. Critical bugfixes
2. Development infrastructure

Getting development infrastructure like tests and types and dev scripts ready is an important precursor to building features.

3. Tracer bullets for new features

Tracer bullets are small slices of functionality that go through all layers of the system, allowing you to test and validate your approach early. This helps in identifying potential issues and ensures that the overall architecture is sound before investing significant time in development.

TL;DR - build a tiny, end-to-end slice of the feature first, then expand it out.

4. Polish and quick wins
5. Refactors

# EXPLORATION

Explore the repo.

# IMPLEMENTATION

Use /tdd to complete the task.

# FEEDBACK LOOPS

Before committing, run the feedback loops:

- `dotnet test` to build and run the tests
- `dotnet build` to verify a clean, warning-free build

Do not modify the output paths in `Directory.Build.props`, pass `-o`/`--output`, or set
`BaseOutputPath`/`BaseIntermediateOutputPath`. Build with a plain `dotnet build` / `dotnet test`
so output works in both the Linux sandbox and on the developer's Windows machine. Never commit
`obj/`, `bin/`, or `.build/`.

# COMMIT

Make a git commit. The commit message must:

1. Include key decisions made
2. Include files changed
3. Blockers or notes for next iteration

# PUSH

Puish the commit to github

# THE ISSUE

If the task is complete, close the issue on GitHub via `gh issue close <number>` (optionally with a `--comment` summarizing the resolution).

If the task is not complete, do NOT close the issue. Record what was done, what's left, and any blockers in the commit message so the next iteration can pick up where you left off.

# FINAL RULES

ONLY WORK ON A SINGLE TASK.