---
name: using-sf-cli
description: "Unified Salesforce CLI quick-reference for all sf commands — org auth, project deploy/retrieve, apex run test, data query, scratch org management, package management, Agentforce agent commands, code generation, and utilities. TRIGGER when: user needs to find the right sf command or correct flag syntax, or asks how to do any Salesforce task from the command line. DO NOT TRIGGER when: user needs a deployment workflow (use deploying-metadata), Apex test execution (use running-apex-tests), or data operations (use handling-sf-data)."
origin: SCC
user-invocable: true
---

# using-sf-cli: Salesforce CLI Command Reference

Quick-reference decision tables for all `sf` CLI commands. Use when you need the right command and flags for any Salesforce task — authentication, deployment, Apex, data, scratch orgs, packages, agents, code generation, or utilities.

## When to Use

- When you need to find the right `sf` command for a Salesforce task
- When constructing CLI commands with correct flags and syntax
- When choosing between similar commands (e.g., `deploy start` vs `deploy validate`)
- When setting up org authentication (web, JWT, sfdx-url)
- When running Apex tests or querying data from the command line
- When managing scratch orgs, packages, or metadata via CLI

---

## Authenticate to an Org

| Scenario | Command | Key flags |
|---|---|---|
| Interactive browser login | `sf org login web` | `--alias`, `--set-default` |
| CI/CD non-interactive login | `sf org login jwt` | `--client-id`, `--jwt-key-file`, `--username` |
| Auth URL from file | `sf org login sfdx-url` | `--sfdx-url-file` |
| Log out of an org | `sf org logout` | `--target-org`, `--no-prompt` |
| List all connected orgs | `sf org list` | `--all` |
| Open org in browser | `sf org open` | `--target-org`, `--path` |
| Display org details | `sf org display` | `--target-org`, `--verbose` |

---

## Deploy or Retrieve Source

| Scenario | Command | Key flags |
|---|---|---|
| Deploy source directory | `sf project deploy start` | `--source-dir`, `--target-org` |
| Deploy with manifest | `sf project deploy start` | `--manifest`, `--target-org` |
| Deploy specific metadata | `sf project deploy start` | `--metadata "ApexClass:MyClass"` |
| Validate without deploying | `sf project deploy validate` | `--test-level`, `--target-org` |
| Quick deploy after validation | `sf project deploy quick` | `--job-id`, `--target-org` |
| Check deploy status | `sf project deploy report` | `--job-id` |
| Resume failed deploy | `sf project deploy resume` | `--job-id` |
| Cancel in-progress deploy | `sf project deploy cancel` | `--job-id` |
| Retrieve from org | `sf project retrieve start` | `--source-dir`, `--target-org` |
| Retrieve by manifest | `sf project retrieve start` | `--manifest` |
| Preview retrieval | `sf project retrieve preview` | `--target-org` |
| List all metadata types in org | `sf org list metadata-types` | `--target-org` |
| List components of a type | `sf org list metadata` | `--metadata-type`, `--target-org` |
| Generate manifest | `sf project generate manifest` | `--source-dir`, `--output-dir` |
| Convert source to mdapi | `sf project convert source` | `--root-dir`, `--output-dir` |
| Convert mdapi to source | `sf project convert mdapi` | `--root-dir`, `--output-dir` |
| Create new project | `sf project generate` | `--name`, `--template` |

---

## Run Apex Code and Tests

| Scenario | Command | Key flags |
|---|---|---|
| Execute anonymous Apex | `sf apex run` | `--file`, `--target-org` |
| Run all local tests | `sf apex run test` | `--test-level RunLocalTests` |
| Run specific test classes | `sf apex run test` | `--class-names "MyTest,OtherTest"` |
| Run specific test methods | `sf apex run test` | `--tests "MyTest.testMethod"` |
| Run tests with coverage | `sf apex run test` | `--code-coverage`, `--output-dir` |
| Run test suite | `sf apex run test` | `--suite-names "MySuite"` |
| Stream debug logs live | `sf apex tail log` | `--target-org`, `--debug-level` |
| Get a specific log | `sf apex get log` | `--log-id` |
| List recent logs | `sf apex list log` | `--target-org` |

---

## Work with Data

| Scenario | Command | Key flags |
|---|---|---|
| Run SOQL query | `sf data query` | `--query`, `--target-org` |
| Run SOQL from file | `sf data query` | `--file`, `--result-format` |
| Bulk SOQL query | `sf data query` | `--query`, `--bulk`, `--wait` |
| Run SOSL search | `sf data search` | `--query` |
| Create a record | `sf data create record` | `--sobject`, `--values` |
| Update a record | `sf data update record` | `--sobject`, `--record-id`, `--values` |
| Delete a record | `sf data delete record` | `--sobject`, `--record-id` |
| Bulk upsert from CSV | `sf data upsert bulk` | `--file`, `--sobject`, `--external-id` |
| Bulk delete from CSV | `sf data delete bulk` | `--file`, `--sobject` |
| Export data as tree | `sf data export tree` | `--query`, `--plan` |
| Import tree data | `sf data import tree` | `--plan`, `--target-org` |

---

## Manage Scratch Orgs and Sandboxes

| Scenario | Command | Key flags |
|---|---|---|
| Create scratch org | `sf org create scratch` | `--definition-file`, `--alias`, `--duration-days` |
| Delete scratch org | `sf org delete scratch` | `--target-org`, `--no-prompt` |
| Create sandbox | `sf org create sandbox` | `--name`, `--definition-file`, `--alias` |
| Clone sandbox | `sf org create sandbox` | `--clone`, `--name` |
| Delete sandbox | `sf org delete sandbox` | `--target-org`, `--no-prompt` |
| Resume sandbox creation | `sf org resume sandbox` | `--name`, `--target-org` |
| Assign permission set | `sf org assign permset` | `--name`, `--target-org` |
| Create user | `sf org create user` | `--definition-file`, `--target-org` |

---

## Manage Packages

| Scenario | Command | Key flags |
|---|---|---|
| Create package | `sf package create` | `--name`, `--package-type`, `--path` |
| Create version | `sf package version create` | `--package`, `--installation-key`, `--code-coverage` |
| Promote version | `sf package version promote` | `--package` |
| Install package | `sf package install` | `--package`, `--target-org` |
| Uninstall package | `sf package uninstall` | `--package`, `--target-org` |
| List versions | `sf package version list` | `--packages`, `--verbose` |
| List installed | `sf package installed list` | `--target-org` |

---

## Work with Agentforce / AI Agents

| Scenario | Command | Key flags |
|---|---|---|
| Create agent | `sf agent create` | `--target-org` |
| Generate agent spec | `sf agent generate spec` | `--output-dir` |
| Generate agent tests | `sf agent generate test` | `--spec-file`, `--output-dir` |
| Run agent tests | `sf agent test run` | `--name`, `--target-org` |
| Preview agent | `sf agent preview` | `--name`, `--target-org` |
| Activate agent | `sf agent activate` | `--target-org` |
| Deactivate agent | `sf agent deactivate` | `--target-org` |

> `sf agent` commands are actively evolving. Run `sf agent <command> --help` for the latest flags.

---

## Generate Code from Templates

| Scenario | Command | Key flags |
|---|---|---|
| Generate Apex class | `sf apex generate class` | `--name`, `--output-dir`, `--template` |
| Generate Apex trigger | `sf apex generate trigger` | `--name`, `--sobject`, `--output-dir` |
| Generate LWC | `sf lightning generate component` | `--name`, `--type lwc` |
| Generate Aura component | `sf lightning generate component` | `--name`, `--type aura` |
| Generate Lightning event | `sf lightning generate event` | `--name`, `--output-dir` |
| Generate SObject | `sf schema generate sobject` | `--label`, `--output-dir` |
| Generate field | `sf schema generate field` | `--label`, `--object` |
| Generate platform event | `sf schema generate platformevent` | `--label`, `--output-dir` |
| Generate project | `sf project generate` | `--name`, `--template` |

---

## Other Utilities

| Scenario | Command | Key flags |
|---|---|---|
| Set default org | `sf config set` | `target-org=myOrg` |
| List config values | `sf config list` | |
| Set alias | `sf alias set` | `myAlias=user@org.com` |
| Describe SObject | `sf sobject describe` | `--sobject`, `--target-org` |
| List SObjects | `sf sobject list` | `--sobject-type`, `--target-org` |
| REST API request | `sf api request rest` | (URL path), `--method`, `--body` |
| GraphQL request | `sf api request graphql` | `--body` |
| Run Flow tests | `sf logic run test` | `--target-org` |
| Diagnose CLI issues | `sf doctor` | |
| Install plugin | `sf plugins install` | (plugin name) |
| Update CLI | `sf update` | |

---

## Workflow Patterns

### Authenticate + Deploy

```bash
sf org login web --alias myOrg --set-default
sf project deploy start --source-dir force-app --target-org myOrg --wait 30
```

### CI/CD: Validate Then Quick Deploy

```bash
# Authenticate in CI
sf org login jwt \
    --client-id $SF_CLIENT_ID \
    --jwt-key-file server.key \
    --username $SF_USERNAME \
    --alias prod

# Validate (runs tests without committing changes)
sf project deploy validate \
    --source-dir force-app \
    --test-level RunLocalTests \
    --target-org prod \
    --wait 60

# Quick deploy using the job ID from validation output
sf project deploy quick --job-id $JOB_ID --target-org prod
```

### Scratch Org Development Cycle

```bash
# Create scratch org
sf org create scratch \
    --definition-file config/project-scratch-def.json \
    --alias dev \
    --duration-days 7 \
    --set-default

# Deploy source and assign permissions
sf project deploy start --source-dir force-app --target-org dev
sf org assign permset --name MyPermSet --target-org dev

# Import sample data
sf data import tree --plan data/sample-data-plan.json --target-org dev

# Run tests
sf apex run test --test-level RunLocalTests --target-org dev --code-coverage

# Clean up
sf org delete scratch --target-org dev --no-prompt
```

---

## Cross-Skill Integration

| Need | Delegate to | Reason |
|---|---|---|
| Deployment workflow, error triage, rollback | [deploying-metadata](../deploying-metadata/SKILL.md) | full deployment orchestration |
| Apex test execution and fix loops | [running-apex-tests](../running-apex-tests/SKILL.md) | test analysis and coverage |
| Debug log retrieval and analysis | [debugging-apex-logs](../debugging-apex-logs/SKILL.md) | root-cause from logs |
| Data CRUD, bulk import/export | [handling-sf-data](../handling-sf-data/SKILL.md) | data operations |
| Official Salesforce CLI documentation | [fetching-salesforce-docs](../fetching-salesforce-docs/SKILL.md) | authoritative docs lookup |
