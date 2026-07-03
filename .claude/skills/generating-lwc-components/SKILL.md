---
name: generating-lwc-components
description: "Lightning Web Components with PICKLES methodology and 165-point scoring. Use this skill when the user creates or edits LWC components, builds wire service patterns, or writes Jest tests for LWC. TRIGGER when: user creates/edits LWC components, touches lwc/**/*.js, .html, .css, .js-meta.xml files, or asks about wire service, SLDS, or Jest LWC tests. DO NOT TRIGGER when: Apex classes (use generating-apex), Aura components, or Visualforce."
license: MIT
metadata:
  version: "1.1"
---

# generating-lwc-components: Lightning Web Components Development

Use this skill when the user needs **Lightning Web Components**: LWC bundles, wire patterns, Apex/GraphQL integration, SLDS 2 styling, accessibility, performance work, or Jest unit tests.

## When This Skill Owns the Task

Use `generating-lwc-components` when the work involves:
- `lwc/**/*.js`, `.html`, `.css`, `.js-meta.xml`
- component scaffolding and bundle design
- wire service, Apex integration, GraphQL integration
- SLDS 2, dark mode, and accessibility work
- Jest unit tests for LWC

Delegate elsewhere when the user is:
- writing Apex controllers or business logic first → [generating-apex](../generating-apex/SKILL.md)
- building Flow XML rather than an LWC screen component → [generating-flow](../generating-flow/SKILL.md)
- deploying metadata → [deploying-metadata](../deploying-metadata/SKILL.md)

---

## Required Context to Gather First

Ask for or infer:
- component purpose and target surface
- data source: LDS, Apex, GraphQL, LMS, or external system via Apex
- whether the user needs tests
- whether the component must run in Flow, App Builder, Experience Cloud, or dashboard contexts
- accessibility and styling expectations

---

## Recommended Workflow

### 1. Choose the right architecture
Use the **PICKLES** mindset:
- prototype
- integrate the right data source
- compose component boundaries
- define interaction model
- use platform libraries
- optimize execution
- enforce security

### 2. Choose the right data access pattern
| Need | Default pattern |
|---|---|
| single-record UI | LDS / `getRecord` |
| simple CRUD form | base record form components |
| complex server query | Apex `@AuraEnabled(cacheable=true)` |
| related graph data | GraphQL wire adapter |
| cross-DOM communication | Lightning Message Service |

### 3. Start from an asset when useful
Use provided assets for:
- basic component bundles
- datatables
- modal patterns
- Flow screen components
- GraphQL components
- LMS message channels
- Jest tests
- TypeScript-enabled components

### 4. Validate for frontend quality
Check:
- accessibility
- SLDS 2 / dark mode compliance
- event contracts
- performance / rerender safety
- Jest coverage when required

### 5. Hand off supporting backend or deploy work
Use:
- [generating-apex](../generating-apex/SKILL.md) for controllers / services
- [deploying-metadata](../deploying-metadata/SKILL.md) for deployment
- [running-apex-tests](../running-apex-tests/SKILL.md) only for Apex-side test loops, not Jest

---

## Constraints

### Naming Conventions

| Element | Convention | Example |
|---------|-----------|---------|
| Component folder & files | camelCase | `accountList/accountList.js` |
| HTML tag in markup | kebab-case with namespace | `<c-account-list>` |
| `@api` properties (JS) | camelCase | `@api maxRecords` |
| `@api` properties (HTML attribute) | kebab-case | `max-records="10"` |
| Private backing fields | camelCase with `_` prefix | `_wiredResult` |
| Custom events | lowercase, hyphens allowed, no spaces | `opportunityselect`, `row-action` |
| CSS classes | SLDS utilities or BEM for custom | `slds-p-around_medium`, `card__title` |

Never use PascalCase or UPPER_CASE for component folder names or file names.

### Never Do

| Rule | Reason |
|------|--------|
| Direct DOM manipulation (`innerHTML`, `document.createElement`, `appendChild`) | Breaks Shadow DOM encapsulation and LWS security model |
| Imperative Apex when `@wire` works | Wire provides LDS caching, auto-reprovisioning, and offline support |
| Inline styles (`style="color:red"`) | Violates SLDS theming; breaks SLDS 2 dark mode |
| `querySelector('#id')` for shadow or slotted elements | IDs are transformed at render time — use `.class` selectors |
| Update `@wire` config in `renderedCallback()` | Creates infinite re-render loop |
| Mutate `@wire` result data directly | Wire data is immutable; shallow-copy (`{...data}`) before mutating |
| Use deprecated `if:true` / `if:false` directives | Replaced by `lwc:if` / `lwc:elseif` / `lwc:else` (GA) |
| Skip `super()` in `constructor()` | Required by Custom Elements spec; omitting throws a runtime error |
| Access DOM in `constructor()` | Shadow DOM is not attached — no `this.template`, no attributes |
| Dispatch events with `bubbles:true, composed:true` without namespacing | Composed events cross all shadow boundaries and become public API |
| Heavy logic in `renderedCallback()` without a guard | Fires every render cycle — causes degradation or infinite loops |

### Always Do

| Rule | Detail |
|------|--------|
| Use `@api` for all public properties and methods | Defines the component's contract; without it, properties are invisible to parents |
| Use kebab-case for component tags in HTML | `<c-account-list>`, never `<c-accountList>` |
| Provide `alternative-text` on `<lightning-spinner>` | Required for screen-reader accessibility (WCAG) |
| Provide `label` on all `<lightning-input>` | Use `variant="label-hidden"` to visually hide — never omit `label` |
| Set `key` on iterated elements | Use record `Id`, not array index — missing keys cause rendering bugs |
| Use `lwc:if` / `lwc:elseif` / `lwc:else` | Modern GA directive — always prefer over deprecated `if:true` |
| Implement `errorCallback(error, stack)` or error boundary | Prevents a child error from crashing the entire component tree |
| Clean up in `disconnectedCallback()` | Remove listeners, `unsubscribe()` from message channels, clear timers |
| Store bound references for event listeners | `this._boundHandler = this.handler.bind(this)` for proper cleanup |
| Set `<apiVersion>66.0</apiVersion>` in `.js-meta.xml` | Targets Spring '26; required for LWS, SLDS 2.0, new wire adapters |
| Use `WITH USER_MODE` in backing Apex SOQL | Enforces FLS/CRUD for running user — required for security review |
| Prefer SLDS utility classes over custom CSS | Ensures dark mode compatibility (SLDS 2.0) and responsive layout |

### Wire Service Constraints

1. All `$`-prefixed reactive params must be defined (non-`undefined`) before the wire adapter fires.
2. Wire data arrives non-deterministically — never assume it is available in `connectedCallback`.
3. Wire chains (`$record.data.fieldName`) are valid but add latency; keep chains to two hops max.
4. Use `refreshApex(wiredResult)` after imperative DML — store the full wire result reference for this purpose.
5. For `@wire` with Apex, the method must be annotated `@AuraEnabled(cacheable=true)`.

### Accessibility Constraints

1. Every interactive element must be keyboard-operable (focusable, activatable via Enter/Space).
2. Every `<lightning-spinner>` must have `alternative-text`.
3. Every `<lightning-input>` must have `label`.
4. Every `<lightning-icon>` used as a meaningful indicator must have `alternative-text`; decorative icons set `aria-hidden="true"`.
5. Color must never be the sole indicator of state — pair with text, icon, or ARIA attributes.

### Meta XML Constraints

1. Always include `<apiVersion>66.0</apiVersion>` (Spring '26).
2. Set `<isExposed>true</isExposed>` for components intended for App Builder, Flow, or Experience Cloud.
3. Declare every intended surface in `<targets>`.
4. Expose configurable `@api` properties via `<targetConfigs>` with `label`, `type`, and `description`.

---

## Output Format

When finishing, report in this order:
1. **Component(s) created or updated**
2. **Data access pattern chosen**
3. **Files changed**
4. **Accessibility / styling / testing notes**
5. **Next implementation or deploy step**

Suggested shape:

```text
LWC work: <summary>
Pattern: <wire / apex / graphql / lms / flow-screen>
Files: <paths>
Quality: <a11y, SLDS2, dark mode, Jest>
Next step: <deploy, add controller, or run tests>
```

---

## Local Development Server

Preview LWC components locally with hot reload — no deployment needed. Run the commands in `scripts/local-dev-preview.sh` to start a local dev session for a component, app, or Experience Cloud site.

Local Dev commands install just-in-time on first run. They are long-running processes that open a browser with live preview. Changes to `.js`, `.html`, and `.css` files auto-reload instantly. Requires an active org connection for data and Apex callouts.

---

## Migrating from Aura

Use this section when converting existing Aura components to LWC.

### Migration Strategy

1. **Inventory** — list all Aura components, dependencies, and usage locations (App Builder pages, layouts, other Aura components)
2. **Prioritize** — start with leaf components (no Aura children); avoid touching components with many dependents first
3. **Wrap** — replace Aura parent shells with LWC while keeping Aura children in place via the interop layer
4. **Convert** — rewrite each component using LWC patterns (see key mappings below)
5. **Test** — validate behavior parity in a sandbox; check App Builder pages, mobile, and Experience Cloud if applicable
6. **Deploy** — replace Aura component references on pages/apps with the new LWC equivalents

### Aura → LWC Key Mappings

| Aura | LWC equivalent |
|------|----------------|
| `aura:handler name="init"` | `connectedCallback()` |
| `aura:handler name="destroy"` | `disconnectedCallback()` |
| `aura:attribute` | `@api` property |
| `aura:if` / `aura:set attribute="else"` | `lwc:if` / `lwc:elseif` / `lwc:else` |
| `aura:iteration` | `for:each` with `key` |
| `$A.enqueueAction()` | `@wire` adapter or imperative `await import()` |
| `component.get("v.attr")` | `this.propertyName` |
| `component.set("v.attr", val)` | `this.propertyName = val` |
| `component.find("auraId")` | `this.template.querySelector('.class')` |
| Component events | `CustomEvent` with `bubbles: false` |
| Application events | Lightning Message Service (`@salesforce/messageChannel`) |
| `$A.getCallback()` | Not needed — LWC handles async natively |
| `Helper.js` (separate file) | Class methods in the single `.js` file |
| `$A.createComponent()` | `lwc:component` with `lwc:is` (dynamic components) |

> For full Aura authoring reference and LWC-Aura interop patterns, see [developing-aura-components](../developing-aura-components/SKILL.md).

---

## Cross-Skill Integration

| Need | Delegate to | Reason |
|---|---|---|
| Apex controller or service | [generating-apex](../generating-apex/SKILL.md) | backend logic |
| embed in Flow screens | [generating-flow](../generating-flow/SKILL.md) | declarative orchestration |
| deploy component bundle | [deploying-metadata](../deploying-metadata/SKILL.md) | org rollout |
| create supporting metadata (message channels, objects) | [deploying-metadata](../deploying-metadata/SKILL.md) | metadata deployment |
| maintain or debug existing Aura components | [developing-aura-components](../developing-aura-components/SKILL.md) | Aura-specific patterns |

---

## Reference File Index

### Start here
- [references/component-patterns.md](references/component-patterns.md) — component architecture patterns and bundle design
- [references/slds-design-guide.md](references/slds-design-guide.md) — SLDS 2 styling, dark mode, CSS hooks
- [references/lwc-best-practices.md](references/lwc-best-practices.md) — high-signal rules and anti-patterns
- [references/scoring-and-testing.md](references/scoring-and-testing.md) — 165-point scoring rubric across 8 categories
- [references/jest-testing.md](references/jest-testing.md) — Jest unit test patterns and async rendering helpers
- [references/slds-blueprints.json](references/slds-blueprints.json) — machine-readable SLDS component blueprints
- [references/cli-commands.md](references/cli-commands.md) — SF CLI commands for LWC development

### Accessibility / performance / state
- [references/accessibility-guide.md](references/accessibility-guide.md) — WCAG, ARIA, keyboard navigation patterns
- [references/performance-guide.md](references/performance-guide.md) — lazy loading, debouncing, rerender safety
- [references/state-management.md](references/state-management.md) — reactive state patterns and LMS
- [references/template-anti-patterns.md](references/template-anti-patterns.md) — common HTML template mistakes to avoid

### Integration / advanced features
- [references/lms-guide.md](references/lms-guide.md) — Lightning Message Service patterns
- [references/flow-integration-guide.md](references/flow-integration-guide.md) — Flow screen component design
- [references/advanced-features.md](references/advanced-features.md) — Spring '26 features: TypeScript, lwc:on, GraphQL mutations
- [references/async-notification-patterns.md](references/async-notification-patterns.md) — toast, notifications, async flows
- [references/triangle-pattern.md](references/triangle-pattern.md) — parent-child-sibling communication triangle

### Asset templates
- [assets/basic-component/basicComponent.js](assets/basic-component/basicComponent.js) — wire service, error/loading states, event dispatching
- [assets/datatable-component/datatableComponent.js](assets/datatable-component/datatableComponent.js) — datatable with inline editing
- [assets/flow-screen-component/flowScreenComponent.js](assets/flow-screen-component/flowScreenComponent.js) — Flow screen with input/output properties
- [assets/form-component/formComponent.js](assets/form-component/formComponent.js) — form validation and DML patterns
- [assets/graphql-component/graphqlComponent.js](assets/graphql-component/graphqlComponent.js) — GraphQL wire adapter with cursor-based pagination
- [assets/jest-test/componentName.test.js.example](assets/jest-test/componentName.test.js.example) — Jest test template (copy and rename, remove `.example` suffix)
- [assets/message-channel/lmsPublisher.js](assets/message-channel/lmsPublisher.js) — LMS publisher pattern
- [assets/message-channel/lmsSubscriber.js](assets/message-channel/lmsSubscriber.js) — LMS subscriber pattern
- [assets/modal-component/modalComponent.js](assets/modal-component/modalComponent.js) — modal with focus trap and ESC handling
- [assets/record-picker/recordPicker.js](assets/record-picker/recordPicker.js) — record picker with search
- [assets/state-store/store.js](assets/state-store/store.js) — reactive state store for cross-component state
- [assets/typescript-component/typescriptComponent.ts](assets/typescript-component/typescriptComponent.ts) — TypeScript-enabled component (Spring '26)
- [assets/workspace-api/workspaceComponent.js](assets/workspace-api/workspaceComponent.js) — workspace API for tab and focus management
- [assets/apex-controller/LwcController.cls](assets/apex-controller/LwcController.cls) — Apex controller with `@AuraEnabled(cacheable=true)` patterns

### Scripts
- [scripts/local-dev-preview.sh](scripts/local-dev-preview.sh) — local dev server commands for component, app, and site preview

---

## Score Guide

| Score | Meaning |
|---|---|
| 150+ | production-ready LWC bundle |
| 125–149 | strong component with minor polish left |
| 100–124 | functional but review recommended |
| < 100 | needs significant improvement |
