<!-- Parent: querying-soql/SKILL.md -->

# Query Optimization & Governor Limits

## Indexing Strategy

**Indexed Fields** (Always Selective):
- Id, Name, OwnerId, CreatedDate, LastModifiedDate, RecordTypeId
- External ID fields, Master-Detail relationship fields
- Lookup fields (when unique)

**Standard Indexed Fields by Object**:
- Account: AccountNumber, Site
- Contact: Email
- Lead: Email
- Case: CaseNumber

## Selectivity Rules

The Force.com optimizer evaluates every WHERE filter against selectivity thresholds. If no filter is selective, the query does a full table scan (fails in trigger context on objects >200,000 rows).

| Index Type | First 1M Records | Records Beyond 1M | Max Target Rows |
|---|---|---|---|
| Standard index | < 30% | < 15% | 1,000,000 |
| Custom index | < 10% | < 5% | 333,333 |

Multiple non-selective AND filters can combine to be selective if their intersection falls below the threshold.

### Optimizable vs Non-Optimizable Operators

| Optimizable | Non-Optimizable |
|---|---|
| `=`, `<`, `>`, `<=`, `>=` | `!=`, `NOT` |
| `IN`, `LIKE` (no leading `%`) | `NOT IN`, `EXCLUDES` |
| `INCLUDES` | `LIKE '%term%'` (leading wildcard) |

## Optimization Patterns

```sql
-- ❌ NON-SELECTIVE (scans all records)
SELECT Id FROM Lead WHERE Status = 'Open'

-- ✅ SELECTIVE (uses index + selective filter)
SELECT Id FROM Lead
WHERE Status = 'Open'
AND CreatedDate = LAST_N_DAYS:30
LIMIT 10000

-- ❌ LEADING WILDCARD (can't use index)
SELECT Id FROM Account WHERE Name LIKE '%corp'

-- ✅ TRAILING WILDCARD (uses index)
SELECT Id FROM Account WHERE Name LIKE 'Acme%'
```

## Query Plan Analysis

```bash
# Get query plan
sf data query \
  --query "SELECT Id FROM Account WHERE Name = 'Test'" \
  --target-org my-org \
  --use-tooling-api \
  --plan
```

**Plan Output Interpretation**:
- `Cardinality`: Estimated rows returned
- `Cost`: Relative query cost (lower is better)
- `Fields`: Index fields used
- `LeadingOperationType`: How the query starts (Index vs TableScan)

---

## Governor Limits

> Source: Apex Governor Limits, API v66.0 (Spring '26)

| Resource | Synchronous | @future / Queueable | Batch execute() |
|---|---|---|---|
| SOQL queries | 100 | 200 | 200 |
| SOQL rows returned | 50,000 | 50,000 | 50,000 |
| DML statements | 150 | 150 | 150 |
| DML rows | 10,000 | 10,000 | 10,000 |
| CPU time (ms) | 10,000 | 60,000 | 60,000 |
| Heap size | 6 MB | 12 MB | 12 MB |
| QueryLocator rows (Batch only) | N/A | N/A | 50,000,000 |

Use `Limits.getQueries()` / `Limits.getLimitQueries()` to check remaining budget at runtime.

### Efficient Patterns

```sql
-- ❌ Query all, filter in Apex
SELECT Id, Name FROM Account
-- Then filter 50,000 records in Apex

-- ✅ Filter in SOQL
SELECT Id, Name FROM Account
WHERE Industry = 'Technology' AND IsActive__c = true
LIMIT 1000

-- ❌ Multiple queries in loop
for (Contact c : contacts) {
    Account a = [SELECT Name FROM Account WHERE Id = :c.AccountId];
}

-- ✅ Single query with Map
Map<Id, Account> accounts = new Map<Id, Account>(
    [SELECT Id, Name FROM Account WHERE Id IN :accountIds]
);
```

## SOQL Cursor API (API v66.0+, Spring '26)

For paginating very large datasets without hitting the 50,000-row query result limit:

```apex
// Create cursor — does not fetch rows yet
Database.Cursor cursor = Database.getCursor(
    'SELECT Id, Name FROM Account WHERE Industry = \'Technology\' ORDER BY Name'
);

Integer totalRows = cursor.getNumRecords();
Integer pageSize = 2000;

for (Integer offset = 0; offset < totalRows; offset += pageSize) {
    List<Account> page = cursor.fetch(offset, pageSize);
    // process page...
}
```

| Cursor Limit | Value |
|---|---|
| Max records per cursor | 50,000,000 |
| `fetch()` max page size | 2,000 rows |
| Max `fetch()` calls per transaction | 10 |
| Cursor lifetime (sync) | 10 minutes |
| Cursor lifetime (async) | 60 minutes |
| Max cursors per day (org-wide) | 10,000 |

Use `Database.PaginationCursor` for `@AuraEnabled`-compatible LWC pagination.

---

## SOQL FOR Loops

```apex
// For large datasets - doesn't load all into heap
for (Account acc : [SELECT Id, Name FROM Account WHERE Industry = 'Technology']) {
    // Process one record at a time
    // Governor: Uses queryMore internally (200 at a time)
}

// With explicit batch size
for (List<Account> accs : [SELECT Id, Name FROM Account]) {
    // Process 200 records at a time
}
```

## Security Patterns

### WITH SECURITY_ENFORCED

```sql
-- Throws exception if user lacks FLS
SELECT Id, Name, Phone
FROM Account
WITH SECURITY_ENFORCED
```

### WITH USER_MODE / SYSTEM_MODE

```sql
-- Respects sharing rules (default in Apex)
SELECT Id, Name FROM Account WITH USER_MODE

-- Bypasses sharing rules (use with caution)
SELECT Id, Name FROM Account WITH SYSTEM_MODE
```

### In Apex: stripInaccessible

```apex
// Strip inaccessible fields instead of throwing
SObjectAccessDecision decision = Security.stripInaccessible(
    AccessType.READABLE,
    [SELECT Id, Name, SecretField__c FROM Account]
);
List<Account> safeAccounts = decision.getRecords();
```
