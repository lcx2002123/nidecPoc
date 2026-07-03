# Developer Console

Open via: `sf org open --target-org myOrg` → gear icon → **Developer Console**

---

## Anonymous Apex Execution

Use to run ad-hoc Apex in the org context without deploying a class.

**Open:** Debug → Execute Anonymous (Ctrl+E / Cmd+E)

```apex
// Inspect a service method result
Account acc = [SELECT Id FROM Account WHERE Name = 'Test Corp' LIMIT 1];
AccountService svc = new AccountService();
AccountService.AccountResult result = svc.getAccount(acc.Id);
System.debug(LoggingLevel.ERROR, JSON.serializePretty(result));
```

Tips:
- Use `LoggingLevel.ERROR` so the output appears regardless of the configured log level.
- `JSON.serializePretty(obj)` works on any Apex object; useful for inspecting complex return types.
- The log pane at the bottom shows results immediately — double-click a log entry to open the full log viewer.

---

## Query Editor

**Open:** Query Editor tab at the bottom of Developer Console

```sql
SELECT Id, Name, StageName, Amount, CloseDate
FROM Opportunity
WHERE StageName = 'Negotiation'
  AND CloseDate = THIS_QUARTER
ORDER BY Amount DESC
LIMIT 25
```

- Results appear in the grid below the query.
- Click a row to open the record in Setup (Inspector panel).
- Use **Query Plan** button (not Execute) to analyze query performance without running the query.

---

## SOQL Query Plan (Explain Plan)

1. Write a query in the Query Editor.
2. Click **Query Plan** (instead of Execute).
3. Read the output:

| Column | Meaning |
|---|---|
| Cost | Relative cost estimate — lower is better. Cost > 1 usually means a table scan |
| Cardinality | Estimated number of rows scanned |
| Fields | Index(es) used |
| Leading operation type | `Index` = selective, `TableScan` = non-selective |

### Interpreting costs

```soql
-- BAD: Cost ≈ 2.5  (TableScan — Description is not indexed)
SELECT Id FROM Account WHERE Description LIKE '%enterprise%'

-- GOOD: Cost ≈ 0.1  (Index on ExternalId__c)
SELECT Id FROM Account WHERE ExternalId__c = 'ACC-001'

-- GOOD: Cost ≈ 0.3  (Index on OwnerId — standard indexed field)
SELECT Id FROM Account WHERE OwnerId = :currentUserId
```

**Fields that are always indexed:** `Id`, `Name`, `OwnerId`, `CreatedDate`, `SystemModstamp`, external ID fields, lookup fields, and any field marked "Unique" or "External ID" in field metadata.

**When the plan still shows TableScan:** Add a more selective filter, limit the result set, or consider whether Batch Apex is more appropriate than a single query.

---

## Checkpoints (Heap Inspection)

Checkpoints let you inspect variable values and heap contents at a specific line without a live debugger.

1. Open a class in the Developer Console source editor.
2. Debug → **Add/Remove Checkpoint** on the target line (or click the margin dot).
3. Execute code that runs through the checkpointed line (via Anonymous Apex or a UI action).
4. Debug → **Checkpoint Inspector** — browse heap objects, their field values, and collection contents.

Limit: up to 5 active checkpoints per transaction. Remove unused checkpoints before running; otherwise the system may skip them silently.
