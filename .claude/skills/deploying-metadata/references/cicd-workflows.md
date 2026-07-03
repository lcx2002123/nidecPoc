# CI/CD Workflows — Salesforce Reference

> Last verified: API v66.0 (Spring '26)

Full CI/CD pipeline patterns for Salesforce: JWT authentication, GitHub Actions workflows, scratch-org-per-branch strategies, change detection, Docker, and security hardening.

---

## JWT Authentication Setup

JWT Bearer Flow is the **only recommended method** for CI/CD pipelines — no browser required.

### Step 1: Generate Certificate and Private Key

```bash
openssl genrsa -out server.key 2048
openssl req -new -key server.key -out server.csr
openssl x509 -req -days 3650 -in server.csr -signkey server.key -out server.crt

# Encode key for secret storage (single-line, no newlines)
base64 -i server.key | tr -d '\n'
```

### Step 2: Create Connected App in Salesforce

1. Setup → App Manager → **New Connected App**
2. Enable OAuth Settings; Callback URL: `http://localhost:1717/OauthRedirect`
3. Selected OAuth Scopes: `api`, `refresh_token`, `offline_access`
4. Enable **Use digital signatures** → upload your `.crt` file
5. Manage → Edit Policies → IP Relaxation: **Relax IP restrictions**
6. Note the **Consumer Key** (Client ID)

### Step 3: Store Secrets in CI

| Secret Name | Value |
|---|---|
| `SALESFORCE_JWT_SECRET_KEY` | base64-encoded `server.key` content |
| `SALESFORCE_CONSUMER_KEY` | Connected App Consumer Key |
| `SALESFORCE_USERNAME` | Target org username |

---

## CI Authentication Methods

| Method | Command | Best For |
|---|---|---|
| JWT Bearer Flow | `sf org login jwt --client-id $KEY --jwt-key-file server.key --username $USER` | CI/CD (headless, recommended) |
| SFDX Auth URL | `sf org login sfdx-url --sfdx-url-file auth.txt` | CI/CD (simpler setup, less secure) |
| Web Login | `sf org login web` | Local dev only — requires browser |

---

## CI Pipeline Structure

Salesforce CI/CD should split into two parallel jobs:

| Job | Tools | Purpose |
|---|---|---|
| **Job 1: Lint & LWC Tests** | Node.js, ESLint, Jest, Prettier | Format, lint, Jest unit tests |
| **Job 2: Deploy & Apex Tests** | SF CLI, Scratch Org or Sandbox | Deploy metadata, run Apex tests |

---

## Branch Strategy

```
feature/ABC-123-my-feature
        │
        ▼
   develop  ──── CI: validate + deploy to dev sandbox
        │
        ▼
   staging  ──── CI: validate + deploy to staging (RunLocalTests)
        │
        ▼
    main     ──── CI: deploy to production (RunLocalTests)
```

| Branch | Org Target | CI Action |
|---|---|---|
| `feature/*` | scratch org (per developer) | create → push → test → delete |
| `develop` | dev sandbox | auto-deploy on merge |
| `staging` | staging sandbox | RunLocalTests validation + deploy |
| `main` | production | validate → quick deploy (requires PR review + CI green) |

---

## GitHub Actions: PR Validation + Production Deploy

```yaml
# .github/workflows/ci.yml
name: Salesforce CI/CD

on:
  push:
    branches: [develop, staging, main]
  pull_request:
    branches: [develop, staging, main]

jobs:
  validate-pr:
    name: Validate Pull Request
    runs-on: ubuntu-latest
    if: github.event_name == 'pull_request'
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Install SF CLI
        run: npm install -g @salesforce/cli

      - name: Authenticate to sandbox
        env:
          JWT_SECRET_KEY: ${{ secrets.SALESFORCE_JWT_SECRET_KEY }}
          CONSUMER_KEY: ${{ secrets.SALESFORCE_CONSUMER_KEY }}
          USERNAME: ${{ secrets.SALESFORCE_USERNAME_SANDBOX }}
        run: |
          echo "$JWT_SECRET_KEY" | base64 --decode > server.key
          sf org login jwt \
            --client-id "$CONSUMER_KEY" \
            --jwt-key-file server.key \
            --username "$USERNAME" \
            --alias validation-org \
            --set-default
          rm server.key

      - name: Validate deployment
        run: |
          sf project deploy validate \
            --source-dir force-app \
            --test-level RunLocalTests \
            --target-org validation-org \
            --wait 30

  deploy-production:
    name: Deploy to Production
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main' && github.event_name == 'push'
    environment: production
    steps:
      - uses: actions/checkout@v4

      - name: Install SF CLI
        run: npm install -g @salesforce/cli

      - name: Authenticate to Production
        env:
          JWT_SECRET_KEY: ${{ secrets.SALESFORCE_PROD_JWT_SECRET_KEY }}
          CONSUMER_KEY: ${{ secrets.SALESFORCE_PROD_CONSUMER_KEY }}
          USERNAME: ${{ secrets.SALESFORCE_PROD_USERNAME }}
        run: |
          echo "$JWT_SECRET_KEY" | base64 --decode > server.key
          sf org login jwt \
            --client-id "$CONSUMER_KEY" \
            --jwt-key-file server.key \
            --username "$USERNAME" \
            --instance-url https://login.salesforce.com \
            --alias prod \
            --set-default
          rm server.key

      - name: Validate deployment
        id: validate
        run: |
          VALIDATION_RESULT=$(sf project deploy validate \
            --source-dir force-app \
            --test-level RunLocalTests \
            --target-org prod \
            --wait 60 \
            --json)
          echo "VALIDATION_JOB_ID=$(echo "$VALIDATION_RESULT" | jq -r '.result.id')" >> "$GITHUB_ENV"

      - name: Quick deploy
        run: |
          sf project deploy quick \
            --job-id "$VALIDATION_JOB_ID" \
            --target-org prod \
            --wait 10
```

> Never use `--use-most-recent` for quick deploy in multi-team orgs. Another team's deployment between validate and quick-deploy invalidates the job — always pass `--job-id` explicitly.

---

## GitHub Actions: Scratch Org Per-Branch (feature/*)

```yaml
test-in-scratch-org:
  name: Test in Scratch Org
  runs-on: ubuntu-latest
  if: startsWith(github.ref, 'refs/heads/feature/')
  steps:
    - uses: actions/checkout@v4

    - name: Install SF CLI and authenticate Dev Hub
      env:
        JWT_SECRET_KEY: ${{ secrets.DEVHUB_JWT_SECRET_KEY }}
        CONSUMER_KEY: ${{ secrets.DEVHUB_CONSUMER_KEY }}
        USERNAME: ${{ secrets.DEVHUB_USERNAME }}
      run: |
        npm install -g @salesforce/cli
        echo "$JWT_SECRET_KEY" | base64 --decode > server.key
        sf org login jwt \
          --client-id "$CONSUMER_KEY" \
          --jwt-key-file server.key \
          --username "$USERNAME" \
          --alias devhub \
          --set-default-dev-hub
        rm server.key

    - name: Create scratch org
      run: |
        sf org create scratch \
          --definition-file config/project-scratch-def.json \
          --alias ci-scratch \
          --set-default \
          --duration-days 1 \
          --no-ancestors

    - name: Push source and run tests
      run: |
        sf project deploy start --source-dir force-app --target-org ci-scratch
        sf apex run test \
          --test-level RunLocalTests \
          --result-format human \
          --code-coverage \
          --target-org ci-scratch

    - name: Delete scratch org
      if: always()
      run: sf org delete scratch --target-org ci-scratch --no-prompt
```

### Scratch Org Lifecycle Timing

| Step | Typical Duration | Notes |
|---|---|---|
| Create | 60–120 s | Use `--duration-days 1` for auto-cleanup if delete step fails |
| Deploy | varies | Full source push |
| Test | varies | `RunLocalTests` excludes managed package tests |
| Delete | ~10 s | Always run in `if: always()` to prevent DevHub limit exhaustion |

---

## Deployment Test Level by Environment

| Environment | Test Level | Rationale |
|---|---|---|
| feature/* CI | `RunLocalTests` | Fast feedback, catches regressions |
| dev sandbox | `RunLocalTests` | Full local test suite |
| staging | `RunLocalTests` | Near-production confidence |
| production | `RunLocalTests` | Required by Salesforce (75% minimum) |
| major release | `RunAllTestsInOrg` | Full org-wide regression |
| CI/CD PR validation | `RunRelevantTests` | Faster feedback via `@testFor` annotation |

---

## Change Detection: Deploy Only Changed Metadata

Use `sfdx-git-delta` to build a minimal deployment package from the git diff.

```bash
# Install plugin (once)
sf plugins install sfdx-git-delta

# Verify command syntax
sf sgd --help
```

```bash
#!/bin/bash
# scripts/get-changed-metadata.sh
BASE_BRANCH=${1:-main}

CHANGED_FILES=$(git diff --name-only origin/$BASE_BRANCH...HEAD)
SF_CHANGED=$(echo "$CHANGED_FILES" | grep "^force-app/")

if [ -z "$SF_CHANGED" ]; then
    echo "No Salesforce metadata changes detected"
    exit 0
fi

sf sgd:source:delta \
    --to HEAD \
    --from origin/$BASE_BRANCH \
    --output-dir changed-sources \
    --generate-delta

TEST_CLASSES=$(cat changed-sources/test-classes.txt 2>/dev/null | tr '\n' ',' | sed 's/,$//')

if [ -n "$TEST_CLASSES" ]; then
    sf project deploy start \
        --source-dir changed-sources/force-app \
        --test-level RunSpecifiedTests \
        --tests "$TEST_CLASSES" \
        --target-org "$TARGET_ORG"
else
    sf project deploy start \
        --source-dir changed-sources/force-app \
        --test-level RunLocalTests \
        --target-org "$TARGET_ORG"
fi
```

---

## Docker / Container CI

### Image Selection

| Option | Recommendation |
|---|---|
| `node:20-slim` + `npm install -g @salesforce/cli` | **Preferred** — full control, smaller footprint |
| `salesforce/cli:latest` | Acceptable — weekly releases, may lag on node version |
| `salesforce/salesforcedx` | **Deprecated** — do not use |

Pin versions for reproducible builds: `node:20.19-slim` not `node:20-slim`.

### GitHub Actions with Container

```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    container:
      image: node:20-slim
    steps:
      - uses: actions/checkout@v4
      - run: npm install -g @salesforce/cli
      - name: Auth DevHub
        run: |
          echo "${{ secrets.SFDX_AUTH_URL }}" > auth.txt
          sf org login sfdx-url --sfdx-url-file auth.txt --set-default-dev-hub
          rm auth.txt
      - name: Create Scratch Org
        run: sf org create scratch --definition-file config/project-scratch-def.json --alias ci --duration-days 1
      - name: Deploy
        run: sf project deploy start --target-org ci
      - name: Test
        run: sf apex run test --test-level RunLocalTests --code-coverage --result-format human --target-org ci
      - name: Cleanup
        if: always()
        run: sf org delete scratch --target-org ci --no-prompt
```

### npm Cache Optimization

```yaml
- uses: actions/cache@v4
  with:
    path: ~/.npm
    key: ${{ runner.os }}-npm-${{ hashFiles('package-lock.json') }}
```

---

## CI Security Hardening

| Practice | Implementation |
|---|---|
| Credential cleanup | `rm -f auth.txt server.key` immediately after auth step |
| Secret storage | GitHub Secrets / CI vault — never commit credentials |
| Non-root container user | `RUN adduser --system appuser` then `USER appuser` |
| Static analysis | `sf code-analyzer run --target force-app --format table` (Code Analyzer v5) |

---

## Supported CI Platforms

| Platform | Notes |
|---|---|
| GitHub Actions | `forcedotcom/sfdx-github-actions` reference repo |
| Jenkins | Salesforce DX Developer Guide: CI with Jenkins |
| CircleCI | Salesforce DX Developer Guide: CI with CircleCI |
| GitLab CI | Community examples; same CLI commands |
| Bitbucket Pipelines | Community examples; same CLI commands |

All platforms use the same `sf` CLI commands — only the YAML syntax differs.
