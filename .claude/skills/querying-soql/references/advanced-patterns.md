<!-- Parent: querying-soql/SKILL.md -->
# Advanced SOQL Patterns

Patterns for dynamic queries, large data volumes, polymorphic lookups, and set-based subqueries. Read when standard query patterns are insufficient for the use case.

---

## Dynamic SOQL — Safe Pattern

Always whitelist-validate every dynamic component (object name, field names) via `Schema.describe`. Only filter *values* use bind variables.

```apex
public List<SObject> buildDynamicQuery(
    String objectName,
    List<String> fields,
    String whereClause,
    Integer maxRecords
) {
    // Validate object name against schema
    Schema.DescribeSObjectResult describe =
        Schema.getGlobalDescribe().get(objectName)?.getDescribe();
    if (describe == null) {
        throw new InvalidQueryException('Unknown object: ' + objectName);
    }

    // Whitelist field names against schema — reject anything not in the describe
    Map<String, Schema.SObjectField> fieldMap = describe.fields.getMap();
    List<String> validatedFields = new List<String>();
    for (String field : fields) {
        if (fieldMap.containsKey(field.toLowerCase())) {
            validatedFields.add(field);
        }
    }
    if (validatedFields.isEmpty()) validatedFields.add('Id');

    String soql = 'SELECT ' + String.join(validatedFields, ', ') +
                  ' FROM ' + objectName;

    // Note: whereClause must NOT contain user-controlled values — use bind map for those
    if (String.isNotBlank(whereClause)) {
        soql += ' WHERE ' + whereClause;
    }
    soql += ' LIMIT ' + Math.min(maxRecords, 2000);

    return Database.queryWithBinds(soql, new Map<String, Object>(), AccessLevel.USER_MODE);
}
```

**Rules:**
- Object and field names must be validated against `Schema.getGlobalDescribe()` — never trust external input
- Filter values go in bind maps via `Database.queryWithBinds()`, not in the WHERE string
- Sort fields / directions must match an allowlist (`ASC`, `DESC`, known field names)
- Always cap with `LIMIT` to prevent unbounded results

---

## Trigger Context — Bulkified Map Pattern

Standard pattern for fetching related records in trigger handlers. Zero SOQL inside the processing loop.

```apex
trigger OpportunityTrigger on Opportunity (after update) {
    // Step 1: collect all IDs needed
    Set<Id> oppIds = Trigger.newMap.keySet();

    // Step 2: single query, group results by parent ID
    Map<Id, List<OpportunityLineItem>> itemsByOppId = new Map<Id, List<OpportunityLineItem>>();
    for (OpportunityLineItem item : [
        SELECT Id, OpportunityId, Quantity, UnitPrice
        FROM OpportunityLineItem
        WHERE OpportunityId IN :oppIds
        WITH USER_MODE
    ]) {
        if (!itemsByOppId.containsKey(item.OpportunityId)) {
            itemsByOppId.put(item.OpportunityId, new List<OpportunityLineItem>());
        }
        itemsByOppId.get(item.OpportunityId).add(item);
    }

    // Step 3: iterate — zero SOQL queries inside this loop
    for (Opportunity opp : Trigger.new) {
        List<OpportunityLineItem> items = itemsByOppId.get(opp.Id);
        if (items == null) items = new List<OpportunityLineItem>();
        // process items...
    }
}
```

---

## Large Data Volume (LDV) Patterns

### Batch Apex for LDV Processing

Use `Database.Batchable` with `QueryLocator` for objects with >1M records. QueryLocator supports up to 50M rows (vs 50K for standard SOQL).

```apex
public class LargeDataProcessingBatch implements Database.Batchable<SObject> {
    public Database.QueryLocator start(Database.BatchableContext bc) {
        // QueryLocator: up to 50M rows — does NOT consume SOQL row limit
        return Database.getQueryLocator([
            SELECT Id, Status__c FROM Account
            WHERE CreatedDate < :Date.today().addYears(-5)
              AND Status__c = 'Active'
        ]);
    }

    public void execute(Database.BatchableContext bc, List<Account> scope) {
        // scope is 200 records by default — fully bulkified
        for (Account acc : scope) {
            acc.Status__c = 'Archived';
        }
        Database.update(scope, false, AccessLevel.USER_MODE);
    }

    public void finish(Database.BatchableContext bc) {}
}
```

### SOQL Cursor for Paged Processing (API v66.0+)

Alternative to Batch for cases where you need explicit page control without the 5-concurrent-job limit.

```apex
Database.Cursor cursor = Database.getCursor(
    'SELECT Id, Name FROM Account WHERE Industry = \'Technology\' ORDER BY Name'
);

Integer totalRows = cursor.getNumRecords();
for (Integer offset = 0; offset < totalRows; offset += 2000) {
    List<Account> page = cursor.fetch(offset, 2000);
    // process page (each fetch() counts against the 10-fetch-per-transaction limit)
}
```

### Requesting Custom Indexes

When a query on a non-indexed field produces a `TableScan` on an object with >100K records, contact Salesforce Support to request a custom index. Provide:
- Object API name
- Field API name
- Sample SOQL query
- Cardinality estimate (number of unique values)

### Skinny Tables

For objects with >10M records that repeatedly query a small subset of fields, Salesforce Support can create a **skinny table** — a narrow materialized copy with only the most-queried fields. Eliminates join overhead and dramatically improves query speed. Request via Salesforce Support case.

---

## SOSL — Full-Text Search Across Objects

Use SOSL (`FIND`) instead of `LIKE '%term%'` for text search. SOSL uses the search index; leading-wildcard `LIKE` forces a full table scan.

```apex
String searchTerm = 'Acme Holdings';

List<List<SObject>> searchResults = [
    FIND :searchTerm
    IN ALL FIELDS
    RETURNING
        Account(Id, Name, Type WHERE Type = 'Customer' LIMIT 20),
        Contact(Id, FirstName, LastName, AccountId LIMIT 20)
    LIMIT 50
];

List<Account> matchingAccounts = (List<Account>) searchResults[0];
List<Contact> matchingContacts = (List<Contact>) searchResults[1];
```

**When to use SOSL vs SOQL:**

| Use Case | Pattern |
|---|---|
| Text search across multiple objects | SOSL `FIND` |
| Exact match on indexed field | SOQL `WHERE field = :value` |
| Trailing wildcard on Name (`Name LIKE 'Acme%'`) | SOQL — trailing wildcard uses index |
| Contains / leading wildcard (`Name LIKE '%Corp%'`) | SOSL — `LIKE '%...'` defeats index |

---

## TYPEOF — Polymorphic Lookup Queries

Use `TYPEOF` when querying objects with polymorphic lookups (`Task.WhatId`, `Task.WhoId`, `Event.WhatId`, `Event.WhoId`) to fetch type-specific fields in a single query.

```apex
List<Task> tasks = [
    SELECT Id, Subject,
        TYPEOF What
            WHEN Account THEN Name, Phone
            WHEN Opportunity THEN Amount, StageName
            ELSE Id
        END
    FROM Task
    WHERE OwnerId = :UserInfo.getUserId()
      AND ActivityDate = TODAY
    WITH USER_MODE
];

for (Task t : tasks) {
    if (t.What instanceof Account) {
        Account acc = (Account) t.What;
        System.debug('Account: ' + acc.Name);
    } else if (t.What instanceof Opportunity) {
        Opportunity opp = (Opportunity) t.What;
        System.debug('Opp amount: ' + opp.Amount);
    }
}
```

**Constraints:** Cannot combine `TYPEOF` with `GROUP BY`, `ROLLUP`, `CUBE`, `HAVING`, or `COUNT()`.

---

## Semi-Join and Anti-Join Subqueries

Filter records based on the existence (or absence) of related records — more efficient than querying both objects and filtering in Apex.

```soql
-- Semi-join: Accounts that HAVE at least one Contact with an email
SELECT Id, Name FROM Account
WHERE Id IN (SELECT AccountId FROM Contact WHERE Email != null)

-- Anti-join: Accounts that have NO closed Opportunities
SELECT Id, Name FROM Account
WHERE Id NOT IN (SELECT AccountId FROM Opportunity WHERE IsClosed = true)

-- Semi-join with additional filter on outer query
SELECT Id, Name FROM Account
WHERE Type = 'Customer'
  AND Id IN (SELECT AccountId FROM Opportunity
             WHERE StageName = 'Closed Won'
               AND CloseDate = THIS_YEAR)
```

**Rules:**
- Inner subquery can return only **one field** (the relationship field)
- Maximum **one level** of subquery nesting
- More efficient than: query both objects → load into Sets → filter in Apex
- `NOT IN` (anti-join) is non-optimizable as a standalone filter — always pair with a selective indexed filter on the outer query
