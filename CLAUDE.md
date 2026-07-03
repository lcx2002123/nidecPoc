# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
npm run lint                   # ESLint on all Aura and LWC JS
npm run test:unit              # LWC Jest unit tests
npm run test:unit:watch        # Tests in watch mode
npm run test:unit:debug        # Tests in debug mode
npm run test:unit:coverage     # Tests with coverage
npm run prettier               # Format all supported files
npm run prettier:verify        # Check formatting without modifying
```

Pre-commit hooks (Husky + lint-staged) automatically run Prettier, ESLint, and Jest on staged files. Run `npm run precommit` to trigger manually.

## Architecture

**Salesforce DX project** (API v66.0). All deployable metadata lives in `force-app/main/default/`:

- `lwc/` — Lightning Web Components (primary component framework)
- `aura/` — Aura Components (legacy)
- `classes/` — Apex business logic
- `triggers/` — Apex triggers
- `objects/` — Custom object and field definitions
- `flexipages/`, `layouts/` — Page layout metadata
- `staticresources/`, `contentassets/` — Binary/static assets
- `permissionsets/` — Access control definitions

`scripts/apex/` and `scripts/soql/` contain development snippets (not deployed).
`config/project-scratch-def.json` defines scratch org configuration (Developer edition, Lightning Experience enabled).

## Code Quality

lint-staged enforces on commit:
- **Prettier** on all `.cls`, `.trigger`, `.html`, `.js`, `.json`, `.xml`, `.yaml`, `.yml`, `.cmp`
- **ESLint** on `aura/**/*.js` (via `@salesforce/eslint-plugin-aura`) and `lwc/**/*.js` (via `@salesforce/eslint-config-lwc`)
- **Jest** on changed LWC files (`--bail --findRelatedTests`)

## Salesforce CLI

```bash
sf org create scratch -f config/project-scratch-def.json -a <alias>
sf project deploy start        # Push source to org
sf project retrieve start      # Pull from org
sf apex run -f scripts/apex/<file>.apex
```
