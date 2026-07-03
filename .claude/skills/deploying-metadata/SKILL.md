---
name: deploying-metadata
description: "Salesforce DevOps automation using sf CLI v2. TRIGGER when: user deploys metadata, creates/manages scratch orgs or sandboxes, sets up CI/CD pipelines, or troubleshoots deployment errors with sf project deploy. DO NOT TRIGGER when: writing Apex code (use generating-apex), building LWC components (use generating-lwc-components), creating metadata definitions (use generating-custom-object or generating-custom-field), or querying org data (use handling-sf-data)."
metadata:
  version: "1.1"
---

# deploying-metadata: Comprehensive Salesforce DevOps Automation

Use this skill when the user needs **deployment orchestration**: dry-run validation, targeted or manifest-based deploys, CI/CD workflow advice, scratch-org management, failure triage, or safe rollout sequencing for Salesforce metadata.

## When This Skill Owns the Task

Use `deploying-metadata` when the work involves:
- `sf project deploy start`, `quick`, `report`, or retrieval workflows
- release sequencing across objects, permission sets, Apex, and Flows
- CI/CD gates, test-level selection, or deployment reports
- troubleshooting deployment failures and dependency ordering

Delegate elsewhere when the user is:
- authoring Apex code → [generating-apex](../generating-apex/SKILL.md)
- authoring LWC components → [generating-lwc-components](../generating-lwc-components/SKILL.md)
- creating custom objects or fields → [generating-custom-object](../generating-custom-object/SKILL.md), [generating-custom-field](../generating-custom-field/SKILL.md)
- building Flows → [generating-flow](../generating-flow/SKILL.md)
- doing org data operations → [handling-sf-data](../handling-sf-data/SKILL.md)
- authoring or testing Agentforce agents → [developing-agentforce](../developing-agentforce/SKILL.md)

---

## Critical Operating Rules

- Use **`sf` CLI v2 only**.
- On non-source-tracking orgs, deploy/retrieve commands require an explicit scope such as `--source-dir`, `--metadata`, or `--manifest`.
- Prefer **`--dry-run` first** before real deploys.
- For Flows, deploy safely and activate only after validation.
- Keep test-data creation guidance delegated to **`handling-sf-data`** after metadata is validated or deployed.

### Default deployment order
| Phase | Metadata |
|---|---|
| 1 | Custom objects / fields |
| 2 | Permission sets |
| 3 | Apex |
| 4 | Flows as Draft |
| 5 | Flow activation / post-verify |

This ordering prevents many dependency and FLS failures.

---

## Deployment Constraints

Hard rules that MUST be followed when deploying, promoting, or packaging Salesforce metadata to any sandbox or production org. Violations are blocking.

### Never

| # | Rule |
|---|------|
| N1 | **Never deploy without validation-only first.** Run `sf project deploy validate` (or `--dry-run`) before every real deployment to production. Quick-deploy is valid only within 10 days and only if no Apex has been deployed to the org since validation. |
| N2 | **Never skip `--test-level`.** Every `sf project deploy start` to a shared org MUST include `--test-level`. Omitting it may silently default to `NoTestRun` with zero coverage. |
| N3 | **Never deploy Profiles alongside other metadata.** Profiles depend on every other metadata type. Deploy Profiles in a separate, final step after all dependencies are confirmed in the target org. |
| N4 | **Never use `--ignore-errors` or `--ignore-conflicts` against production.** Fix root causes; force flags are acceptable only in developer sandboxes during active prototyping. |
| N5 | **Never deploy destructive changes without a pre-deploy snapshot.** Before any `--post-destructive-changes` or `--pre-destructive-changes` deployment, retrieve the current state of affected components. |
| N6 | **Never use `--use-most-recent` for quick deploy in multi-team orgs.** Another team's deployment between your validate and quick-deploy invalidates the job. Always pass `--job-id` explicitly. |

### Always

| # | Rule |
|---|------|
| A1 | Always validate before deploy — run `--dry-run` first. |
| A2 | Always specify an appropriate test level: developer sandbox (no Apex) `NoTestRun` · developer sandbox (with Apex) `RunLocalTests` · staging/UAT `RunLocalTests` · production minimum `RunLocalTests` · major release `RunAllTestsInOrg` · CI/CD PR validation `RunRelevantTests`. |
| A3 | Always follow metadata dependency order: CustomObject → CustomField → RecordType → ValidationRule → Layout → ApexClass → ApexTrigger → LightningComponentBundle → FlexiPage → PermissionSet → Profile. |
| A4 | Always have a rollback plan before any production deployment. |
| A5 | Always confirm 75%+ org-wide code coverage before deploying to production. |
| A6 | Always include test classes in the deployment package when Apex is present. |

### Production Deploy Sequence

1. Pre-deploy snapshot (`snapshot_org.sh`)
2. Validate (`--dry-run`)
3. Confirm all tests pass and coverage ≥ 75%
4. Quick deploy (`sf project deploy quick --job-id <ID>`)
5. Smoke test critical paths
6. Confirm success or execute rollback

---

## Required Context to Gather First

Ask for or infer:
- target org alias and environment type
- deployment scope: source-dir, metadata list, or manifest
- whether this is validate-only, deploy, quick deploy, retrieve, or CI/CD guidance
- required test level and rollback expectations
- whether special metadata types are involved (Flow, permission sets, agents, packages)

Preflight checks:
```bash
sf --version
sf org list
sf org display --target-org <alias> --json
test -f sfdx-project.json
```

---

## Recommended Workflow

### 1. Preflight
Confirm auth, repo shape, package directories, and target scope.

### 2. Validate first
```bash
sf project deploy start --dry-run --source-dir force-app --target-org <alias> --wait 30 --json
```
Use manifest- or metadata-scoped validation when the change set is targeted.

### 3. If validation succeeds, offer the next safe workflow
After a successful validation, guide the user to the correct next action:
1. deploy now
2. assign permission sets
3. create test data via [handling-sf-data](../handling-sf-data/SKILL.md)
4. run tests / smoke checks
5. orchestrate multiple post-deploy steps in order

### 4. Pre-deploy snapshot check

**Before executing any real deployment (without `--dry-run`), always ask the user:**

> 部署前是否需要为目标 org 创建快照？
> - **Yes** — 先执行快照，完成后再部署（推荐用于 sandbox 以上环境）
> - **No** — 跳过快照，直接部署

If the user chooses **Yes**, run the following and wait for it to complete before proceeding:

```bash
.claude/skills/deploying-metadata/scripts/snapshot_org.sh <org-alias> ./backups/<org-alias>-$(date +%Y-%m-%d)
```

The snapshot saves metadata to `./backups/` and generates a `snapshot-info.json` for rollback reference.

### 5. Deploy the smallest correct scope
```bash
# source-dir deploy
sf project deploy start --source-dir force-app --target-org <alias> --wait 30 --json

# manifest deploy
sf project deploy start --manifest manifest/package.xml --target-org <alias> --test-level RunLocalTests --wait 30 --json

# manifest deploy with Spring '26 relevant-test selection
sf project deploy start --manifest manifest/package.xml --target-org <alias> --test-level RunRelevantTests --wait 30 --json

# quick deploy after successful validation
sf project deploy quick --job-id <validation-job-id> --target-org <alias> --json
```

### 6. Verify
```bash
sf project deploy report --job-id <job-id> --target-org <alias> --json
```
Then verify tests, Flow state, permission assignments, and smoke-test behavior.

### 7. Report clearly
Summarize what deployed, what failed, what was skipped, and what the next safe action is.

Output template: [references/deployment-report-template.md](references/deployment-report-template.md)

---

## High-Signal Failure Patterns

| Error / symptom | Likely cause | Default fix direction |
|---|---|---|
| `FIELD_CUSTOM_VALIDATION_EXCEPTION` | validation rule or bad test data | adjust data or rule timing |
| `INVALID_CROSS_REFERENCE_KEY` | missing dependency | include referenced metadata first |
| `CANNOT_INSERT_UPDATE_ACTIVATE_ENTITY` | trigger / Flow / validation side effect | inspect automation stack and failing logic |
| tests fail during deploy | broken code or fragile tests | run targeted tests, fix root cause, revalidate |
| field/object not found in permset | wrong order | deploy objects/fields before permission sets |
| Flow invalid / version conflict | dependency or activation problem | deploy as Draft, verify, then activate |
| `CANNOT_DELETE_MANAGED_OBJECT` | component belongs to an installed managed package | managed components cannot be deleted via Metadata API — uninstall the package from Setup instead |

Full workflows: [references/orchestration.md](references/orchestration.md), [references/trigger-deployment-safety.md](references/trigger-deployment-safety.md)

---

## Build Error Resolution

When `sf project deploy validate` returns errors, classify them first, then fix in priority order.

### Error Priority and Fix Order

| Priority | Error type | Fix strategy |
|---|---|---|
| 1 | Missing object or field metadata | Deploy objects and fields **before** the Apex classes that reference them |
| 2 | Missing class or interface reference | Check spelling, verify the class exists, check API version compatibility |
| 3 | Type mismatch | Add explicit cast, check null handling, verify generic types |
| 4 | Method signature changed | Update all callers; check for overloaded methods with different parameter types |
| 5 | Metadata conflict | Retrieve latest from org, then merge (see below) |

> For test failures (Priority 6) and governor-limit failures in tests (Priority 7), delegate to `running-apex-tests`. For Apex compilation error message patterns (Variable does not exist, Illegal assignment, etc.), see `generating-apex` `## Compilation Error Reference`.

### Metadata Conflict Resolution

When `sf project deploy` reports a conflict with an existing org component:

1. **Retrieve current org state**: `sf project retrieve start --metadata <type>:<name> --target-org <alias>`
2. **Compare**: `diff force-app/main/default/<path> <retrieved-path>`
3. **Merge**: preserve production changes, layer your local modifications on top
4. **Never force-overwrite** production metadata without understanding the diff — `--ignore-conflicts` is acceptable only in developer sandboxes during active prototyping

---

## Rollback Procedure

Trigger this section when:
- A deployment **fails** (Step 6 Verify or Step 7 Report shows failure)
- The user says "回滚", "rollback", "还原", "revert", or "出问题了"

### Step 1: Check for available snapshots

```bash
ls -lt ./backups/ 2>/dev/null
```

**If no `./backups/` directory or it is empty:**

> 部署失败了，但检测到本次部署前**没有创建快照备份**，无法执行自动回滚。
>
> 建议手动检查变更内容并修复后重新部署，或联系管理员手动恢复。

Stop here. Do not proceed further.

**If snapshots exist**, show the available backups and ask:

> 部署失败了。检测到以下可用快照：
> `<列出 ./backups/ 下的目录>`
>
> 是否要回滚到其中某个快照？

### Step 2: Confirm and execute rollback

After the user confirms which snapshot to use, run:

```bash
echo "yes" | .claude/skills/deploying-metadata/scripts/rollback_deployment.sh <org-alias> <snapshot-dir>
```

The script will:
1. Create a pre-rollback backup of current state
2. Deploy the selected snapshot back to the org
3. Run `RunLocalTests` to verify

---

## Development Iteration Loops

Quick patterns for iterative local development (not CI/CD):

### LWC Loop
```bash
# Edit .html / .js / .css, then deploy component
sf project deploy start --source-dir force-app/main/default/lwc/myComponent
sf org open
# No tests needed for pure LWC changes
```

### Apex Loop
```bash
# Deploy without tests (fastest)
sf project deploy start \
  --metadata ApexClass:MyClass \
  --metadata ApexClass:MyClassTest \
  --test-level NoTestRun
# Run tests separately
sf apex run test --tests MyClassTest --result-format human --code-coverage
# Iterate
```

### Custom Object Loop
```bash
# Modify object fields / validation rules
sf project deploy start --source-dir force-app/main/default/objects/MyObject__c
sf org open
```

---

## Deployment Time Estimates

| Operation | Duration |
|-----------|----------|
| LWC / Visualforce | 30 sec – 2 min |
| Apex without tests | 1–2 min |
| Apex with specific tests | 2–10 min |
| Apex with all local tests | **15–60+ min (warn user!)** |
| Large metadata deployment | 5–15 min |

Always confirm before running `RunLocalTests` — it can take 15–60+ minutes.

---

## CI/CD Guidance

Default pipeline shape:
1. authenticate
2. validate repo / org state
3. static analysis
4. dry-run deploy
5. tests + coverage gates
6. deploy
7. verify + notify

- When org policy and release risk allow it, consider `--test-level RunRelevantTests` for Apex-heavy deployments.
- Pair this with modern Apex test annotations such as `@IsTest(testFor=...)` and `@IsTest(isCritical=true)` — see [generating-apex](../generating-apex/SKILL.md) for authoring guidance.

Static analysis now uses **Code Analyzer v5** (`sf code-analyzer`), not retired `sf scanner`.

Full CI/CD patterns (JWT setup, GitHub Actions YAMLs, scratch-org-per-branch, sfdx-git-delta, Docker): [references/cicd-workflows.md](references/cicd-workflows.md)

---

## Agentforce Deployment Note

Use this skill to orchestrate **deployment/publish sequencing** around agents, but use the agent-specific skill for authoring decisions:
- [developing-agentforce](../developing-agentforce/SKILL.md) for `.agent` authoring, Agent Builder, Prompt Builder, and metadata config

For full agent DevOps details, including `Agent:` pseudo metadata, publish/activate, and sync-between-orgs, see:
- [references/agent-deployment-guide.md](references/agent-deployment-guide.md)

---

## Cross-Skill Integration

| Need | Delegate to | Reason |
|---|---|---|
| custom object creation | [generating-custom-object](../generating-custom-object/SKILL.md) | define objects before deploy |
| custom field creation | [generating-custom-field](../generating-custom-field/SKILL.md) | define fields before deploy |
| Apex authoring / fixes | [generating-apex](../generating-apex/SKILL.md) | code authoring and repair |
| Flow creation / repair | [generating-flow](../generating-flow/SKILL.md) | Flow authoring and activation guidance |
| test data or seed records | [handling-sf-data](../handling-sf-data/SKILL.md) | describe-first data setup and cleanup |
| Agent authoring and publish readiness | [developing-agentforce](../developing-agentforce/SKILL.md) | agent-specific correctness |
| sf CLI command lookup (auth, packages, config, utilities) | [using-sf-cli](../using-sf-cli/SKILL.md) | unified command reference |

---

## Reference Map

### Start here
- [references/orchestration.md](references/orchestration.md)
- [references/deployment-workflows.md](references/deployment-workflows.md)
- [references/deployment-report-template.md](references/deployment-report-template.md)

### CI/CD and automation
- [references/cicd-workflows.md](references/cicd-workflows.md) — JWT setup, GitHub Actions YAMLs (validate-PR, deploy-production, scratch-org-per-branch), branch strategy, sfdx-git-delta, Docker, CI security hardening

### Specialized deployment safety
- [references/trigger-deployment-safety.md](references/trigger-deployment-safety.md)
- [references/agent-deployment-guide.md](references/agent-deployment-guide.md)
- [references/deploy.sh](references/deploy.sh)

### Metadata reference
- [references/metadata-types.md](references/metadata-types.md) — Complete metadata type table (package.xml names, suffixes, wildcards), deployment order, source vs metadata format, sfdx-project.json, .forceignore patterns, profiles vs permission sets, CMDT record XML

### Asset templates
- [assets/package.xml](assets/package.xml) — manifest template covering common metadata types
- [assets/destructiveChanges.xml](assets/destructiveChanges.xml) — template for removing metadata from target orgs

---

## Score Guide

| Score | Meaning |
|---|---|
| 90+ | strong deployment plan and execution guidance |
| 75–89 | good deploy guidance with minor review items |
| 60–74 | partial coverage of deployment risk |
| < 60 | insufficient confidence; tighten plan before rollout |

---

## Completion Format

```text
Deployment goal: <validate / deploy / retrieve / pipeline>
Target org: <alias>
Scope: <source-dir / metadata / manifest>
Result: <passed / failed / partial>
Key findings: <errors, ordering, tests, skipped items>
Next step: <safe follow-up action>
```
