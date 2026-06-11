---
name: tdd
description: "End-to-end implementation workflow. Use when user wants to implement a feature, fix a bug, or make changes and have everything validated and committed."
---

# Do Work

Complete implementation workflow from exploration to commit.

## Workflow

### Phase 1: Explore & Plan

### Phase 2: Implement

If you're touching code that interacts with the database, follow the [DB TDD workflow](db-tdd.md).

If you're touching frontend code with complex state (creating/modifying reducers, complex state transitions, non-trivial state management), follow the [Frontend TDD workflow](frontend-tdd.md).

### Phase 3: Feedback Loops

Run each check, fix issues, and re-run until clean. Do these sequentially:

1. **Type checking**: `npm run typecheck`
2. **Tests**: `npm test`

If a check fails, fix the issue and re-run that check before moving to the next one. Do not move on with failing checks.

### Phase 4: Commit and push your changes with a descriptive commit message. Follow the project's commit message guidelines if they exist.
