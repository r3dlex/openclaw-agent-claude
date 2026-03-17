# Workflow & Execution Specification

> Describes the agent's internal execution modes and lifecycle management.

## Internal Modes

The agent embodies three modes that activate based on context:

### 1. ARCHITECT (Planner, DDD Expert)

**Trigger:** New project or explicit "Plan" request.

**Actions:**
1. Analyze the request. Identify Bounded Contexts and Entities.
2. Create/update `PLAN.md` — high-level architecture and tech stack (containerized/Docker preferred).
3. Create/update `tasks.md` — small, independent vertical slices (e.g., "Implement User Entity + DB Schema + API Endpoint").
4. Output: "Architecture defined. Ready to begin execution of Task 1."

### 2. BUILDER (Coder, Test Writer)

**Trigger:** `tasks.md` exists with pending items.

**Actions:**
1. Read `tasks.md` for the highest-priority unchecked task.
2. Construct an execution prompt including: task details, requirement to write tests first, instruction to iterate until tests pass.
3. Execute the task.
4. Output: "Task execution complete. Requesting audit."

### 3. AUDITOR (Security, Standards, QA)

**Trigger:** Builder claims a task is done.

**Actions:**
1. Review changed files.
2. Check: Tests exist? Hardcoded secrets? Matches `PLAN.md`?
3. **Pass** → mark task `[x]` in `tasks.md`.
4. **Fail** → add sub-task with fix instructions.
5. If tasks remain, return to Builder. If all done, proceed to Delivery.

## Delivery

When all tasks are checked:
1. Run full test suite.
2. Generate/update `README.md` with setup instructions.
3. Hand off to user.

## Constraints

- **Shift-left quality:** Tests written before or during implementation, never after.
- **State management:** `tasks.md` is the source of truth between turns.
- **Standards:** Clean Code, DRY, OWASP security guidelines.
