<!-- Parent: generating-custom-object/SKILL.md -->
# Multi-Skill Orchestration: generating-custom-object Perspective

This document details how generating-custom-object fits into the multi-skill workflow for Salesforce development.

---

## Standard Orchestration Order

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  STANDARD MULTI-SKILL ORCHESTRATION ORDER                                   │
├─────────────────────────────────────────────────────────────────────────────┤
│  1. generating-custom-object  ◀── YOU ARE HERE                                          │
│     └── Create object/field definitions (LOCAL files)                       │
│                                                                             │
│  2. generating-flow                                                                 │
│     └── Create flow definitions (LOCAL files)                               │
│                                                                             │
│  3. deploying-metadata                                                               │
│     └── Deploy all metadata (REMOTE)                                        │
│                                                                             │
│  4. handling-sf-data                                                                 │
│     └── Create test data (REMOTE - objects must exist!)                     │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Why generating-custom-object Goes First

| Step | Depends On generating-custom-object | What Fails Without It |
|------|------------------------|----------------------|
| generating-flow | ✅ Must exist | Flow references non-existent field/object |
| deploying-metadata | ✅ Must exist | Nothing to deploy |
| handling-sf-data | ✅ Must be deployed | `SObject type 'X' not supported` |

**generating-custom-object creates the foundation** that all other skills build upon.

---

## Integration + Agentforce Extended Order

When building agents with external API integrations:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  INTEGRATION + AGENTFORCE ORCHESTRATION ORDER                               │
├─────────────────────────────────────────────────────────────────────────────┤
│  1. generating-custom-object  ◀── YOU ARE HERE                                          │
│     └── Create object/field definitions                                     │
│                                                                             │
│  2. configuring-connected-apps                                                       │
│     └── Create OAuth Connected App (if external API needed)                 │
│                                                                             │
│  3. building-sf-integrations                                                          │
│     └── Create Named Credential + External Service                          │
│                                                                             │
│  4. generating-apex                                                                 │
│     └── Create @InvocableMethod (if custom logic needed)                    │
│                                                                             │
│  5. generating-flow                                                                 │
│     └── Create Flow wrapper (HTTP Callout or Apex wrapper)                  │
│                                                                             │
│  6. deploying-metadata                                                               │
│     └── Deploy all metadata                                                 │
│                                                                             │
│  7. sf-ai-agentforce                                                        │
│     └── Create agent with flow:// target                                    │
│                                                                             │
│  8. deploying-metadata                                                               │
│     └── Publish agent (sf agent publish authoring-bundle)                   │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## generating-custom-object Responsibilities in Orchestration

### Before generating-flow

generating-custom-object must create:
- Custom Objects (the flow will reference)
- Custom Fields (used in flow variables, assignments)
- Picklist Values (used in flow decisions)
- Record Types (used in flow record creates)

### Before generating-apex

generating-custom-object must create:
- Custom Objects (Apex queries/DML targets)
- Custom Fields (referenced in SOQL, field sets)
- Custom Metadata Types (configuration storage)

### Example: Quote Builder Flow

```
generating-custom-object creates:
├── Quote__c.object-meta.xml
├── Quote_Line_Item__c.object-meta.xml
├── Quote__c.Status__c.field-meta.xml (Picklist)
├── Quote_Line_Item__c.Product__c.field-meta.xml (Lookup)
└── Quote_Access.permissionset-meta.xml

generating-apex creates:
└── PricingCalculator.cls (@InvocableMethod)

generating-flow creates:
└── Quote_Builder_Flow.flow-meta.xml (references above)

deploying-metadata:
└── Deploys all to org
```

---

## Common Errors from Wrong Order

| Error | Cause | Correct Order |
|-------|-------|---------------|
| `Field does not exist: Status__c` | Flow created before field | generating-custom-object → generating-flow |
| `Invalid reference: Quote__c` | Flow created before object | generating-custom-object → generating-flow |
| `SObject type 'Quote__c' not supported` | Data created before deploy | deploying-metadata → handling-sf-data |
| `Cannot find FlowDefinition` | Agent references missing flow | generating-flow → sf-ai-agentforce |

---

## Invocation Pattern

After creating metadata with generating-custom-object:

```
# Deploy metadata
Skill(skill="deploying-metadata", args="Deploy to [target-org]")

# Then create test data
Skill(skill="handling-sf-data", args="Create 251 Quote__c records")
```

---

## Cross-Skill Integration Table

| From Skill | To generating-custom-object | When |
|------------|----------------|------|
| generating-apex | → generating-custom-object | "Describe Quote__c" (discover fields before coding) |
| generating-flow | → generating-custom-object | "Describe object fields, record types" (verify structure) |
| handling-sf-data | → generating-custom-object | "Describe Custom_Object__c fields" (discover structure) |
| sf-ai-agentforce | → generating-custom-object | "Create custom object for agent data" |

---

## Best Practices

1. **Always create Permission Sets** with object/field metadata
2. **Use sf sobject describe** to verify existing structure before creating
3. **Check sfdx-project.json** exists before generating metadata
4. **Use consistent naming** across related objects (Quote__c, Quote_Line_Item__c)
5. **Document relationships** in object descriptions

---

## Related Documentation

| Topic | Location |
|-------|----------|
| Metadata templates | `generating-custom-object/assets/` |
| Field types guide | `generating-custom-object/references/field-types-guide.md` |
| Naming conventions | `generating-custom-object/references/naming-conventions.md` |
| deploying-metadata skill | `deploying-metadata/SKILL.md` |
