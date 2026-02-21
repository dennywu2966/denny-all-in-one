---
name: codebase-tour
description: Systematically read a codebase and produce an architecture tour (modules, key flows, gotchas, and open questions). Use when onboarding to a repo, reviewing unfamiliar code, or preparing a technical walkthrough.
allowed-tools: Read, Grep, Glob, Bash(git *), Bash(rg *), Bash(ls *), Bash(tree *), Bash(cat *), Bash(sed *), Bash(awk *)
---

# Codebase Tour

You are doing a **read-first** investigation. Do not modify files unless explicitly asked.

## Inputs
- $ARGUMENTS: optional. Can be a focus area (e.g. "auth", "vector search", "ingestion") or an entry file path.

## Process (strict)

### 1) Clarify scope (brief)
Infer from $ARGUMENTS what the user is trying to understand: feature exploration, bug investigation, general onboarding, or preparing a technical walkthrough.

### 2) Repo map
Identify the codebase's foundation:
- **Language/tooling**: package manager (package.json, pom.xml, go.mod, Cargo.toml, etc.), build commands (Makefile, scripts/, package.json scripts), test commands
- **Top-level folders**: source code organization (src/, lib/, app/, etc.), configuration, documentation
- **Entry points**: service main files, CLI entry points, web server bootstrap, job scripts

### 3) Module decomposition
Name 5–12 core modules with their responsibilities. For each module:
- **Public API surface**: key functions, classes, or routes exposed
- **Key data types**: important interfaces, types, or data structures
- **Dependencies**: what other modules or external libs it depends on

### 4) Trace critical flows
Select 1–2 critical flows and trace them end-to-end. Examples:
- Request → handler → domain logic → storage → response
- CLI command → parser → executor → output
- Event → listener → processor → side effect

For each flow, produce a Mermaid sequence diagram with annotations on "where to set breakpoints" for debugging.

### 5) Gotchas & risks
Identify common pitfalls:
- **Concurrency**: race conditions, deadlocks, shared state
- **Caching**: cache invalidation, staleness, warm-up
- **Error handling**: uncaught errors, silent failures, retry logic
- **Configuration**: default values, environment-specific settings
- **Security boundaries**: authentication, authorization, input validation

### 6) Deliverables

**If `docs/` directory exists and is writable**, create these files:
- `docs/TOUR_OVERVIEW.md` - Executive summary of the codebase
- `docs/TOUR_MODULE_MAP.md` - Module decomposition with Mermaid dependency graph
- `docs/TOUR_KEY_FLOWS.md` - Critical flow traces with Mermaid sequence diagrams
- `docs/TOUR_GOTCHAS.md` - Gotchas and risk areas
- `docs/TOUR_OPEN_QUESTIONS.md` - Unanswered questions and areas needing investigation

**Otherwise**, print results in chat using the format below.

## Output format (when printing in chat)

### Executive Summary (10 lines)
- What this codebase does
- Primary language and framework
- Architecture pattern (monolith, microservices, serverless, etc.)
- Key external dependencies
- Deployment model

### Module List
Bulleted list of 5–12 core modules with one-line responsibilities.

### Visualizations
- 1 Mermaid graph showing module dependencies
- 1 Mermaid sequence diagram showing a critical flow

### Where Bugs Hide (Top 10 Checklist)
1. [ ] Race condition in concurrent code
2. [ ] Unhandled error paths
3. [ ] Missing input validation
4. [ ] Incorrect error handling
5. [ ] Resource leaks (unclosed connections, file handles)
6. [ ] Authentication/authorization bypass
7. [ ] Cache coherency issues
8. [ ] Missing/incorrect timeout handling
9. [ ] Incorrect state machine transitions
10. [ ] Data migration or schema evolution issues
