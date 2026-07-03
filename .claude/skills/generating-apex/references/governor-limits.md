# Governor Limits — Reference and Optimization Patterns

> Last verified: API v66.0 (Spring '26)

Salesforce governor limits prevent any single Apex transaction from monopolizing shared infrastructure. Hitting a limit throws `System.LimitException`, which **cannot be caught** — it terminates the transaction immediately.

---

## Per-Transaction Limits

| Resource | Synchronous | @future / Queueable | Batch execute() | Batch start/finish |
|---|---|---|---|---|
| **SOQL queries** | 100 | 200 | 200 | 200 |
| **SOQL rows returned** | 50,000 | 50,000 | 50,000 | 50,000 |
| **SOQL rows for `FOR UPDATE`** | 200 | 200 | 200 | 200 |
| **DML statements** | 150 | 150 | 150 | 150 |
| **DML rows** | 10,000 | 10,000 | 10,000 | 10,000 |
| **CPU time (ms)** | 10,000 | 60,000 | 60,000 | 60,000 |
| **Heap size** | 6 MB | 12 MB | 12 MB | 12 MB |
| **Callouts** | 100 | 100 | 100 | 100 |
| **Total callout time (s)** | 120 | 120 | 120 | 120 |
| **Response size per callout** | 12 MB | 12 MB | 12 MB | 12 MB |
| **Email invocations** | 10 | 10 | 10 | 10 |
| **@future calls** | 50 | 0 (can't chain) | 50 | 50 |
| **Queueable jobs** | 50 | 1 (chain in prod) | 1 | 1 |
| **Push notifications** | 10 | 10 | 10 | 10 |
| **QueryLocator rows (Batch)** | N/A | N/A | 50M | N/A |

## SOQL Cursor Limits (Spring '26+, API v66.0)

| Constraint | Value |
|---|---|
| Max records per cursor | 50,000,000 |
| Cursor lifetime (sync) | 10 minutes |
| Cursor lifetime (async / Queueable) | 60 minutes |
| `fetch()` max page size | 2,000 rows per call |
| Max open cursors per transaction | 10 |

## Org-Wide Limits

| Resource | Limit |
|---|---|
| Scheduled Apex jobs | 100 jobs scheduled at once |
| Concurrent long-running requests (>5s) | 10 |
| Batch jobs active (executing) | 5 concurrent; up to 100 in flex queue |
| Platform event publishes per hour | 250,000 |

---

## Limits Class — Programmatic Checking

| Method | Returns |
|---|---|
| `Limits.getQueries()` / `Limits.getLimitQueries()` | SOQL queries used / limit |
| `Limits.getQueryRows()` / `Limits.getLimitQueryRows()` | SOQL rows used / limit |
| `Limits.getDmlStatements()` / `Limits.getLimitDmlStatements()` | DML statements used / limit |
| `Limits.getDmlRows()` / `Limits.getLimitDmlRows()` | DML rows used / limit |
| `Limits.getCpuTime()` / `Limits.getLimitCpuTime()` | CPU ms used / limit |
| `Limits.getHeapSize()` / `Limits.getLimitHeapSize()` | Heap bytes used / limit |
| `Limits.getCallouts()` / `Limits.getLimitCallouts()` | Callouts used / limit |
| `Limits.getFutureCalls()` / `Limits.getLimitFutureCalls()` | @future calls used / limit |
| `Limits.getEmailInvocations()` / `Limits.getLimitEmailInvocations()` | Emails used / limit |
| `Limits.getQueueableJobs()` / `Limits.getLimitQueueableJobs()` | Queueable jobs used / limit |

### LimitAwareProcessor — Defensive Pre-Check Pattern

Use before expensive operations in complex transactions where limit budgets may be partially consumed by earlier callers.

```apex
public class LimitAwareProcessor {

    public void processIfSafe(List<Account> accounts) {
        Integer soqlRemaining = Limits.getLimitQueries() - Limits.getQueries();
        if (soqlRemaining < 5) {
            System.debug(LoggingLevel.WARN,
                'Low SOQL budget: ' + Limits.getQueries() + '/' +
                Limits.getLimitQueries() + '. Deferring to async.');
            if (Limits.getQueueableJobs() < Limits.getLimitQueueableJobs()
                && !System.isBatch() && !System.isFuture()) {
                System.enqueueJob(new AccountProcessorJob(extractIds(accounts)));
            }
            return;
        }

        Integer dmlRemaining = Limits.getLimitDmlStatements() - Limits.getDmlStatements();
        if (dmlRemaining < 3) {
            throw new LimitSafetyException(
                'Insufficient DML budget. ' +
                Limits.getDmlStatements() + '/' + Limits.getLimitDmlStatements() + ' used.'
            );
        }

        if (Limits.getHeapSize() > Limits.getLimitHeapSize() * 0.75) {
            System.debug(LoggingLevel.WARN, 'Heap at 75% — skipping optional enrichment.');
        }

        processInternal(accounts);
    }

    public class LimitSafetyException extends Exception {}
}
```

---

## SOQL Limit Strategies

### Query Once, Store in Map

The single most impactful optimization in Salesforce Apex.

```apex
public void processAccounts(List<Account> accounts) {
    Set<Id> accountIds = new Set<Id>();
    for (Account acc : accounts) accountIds.add(acc.Id);

    Map<Id, List<Contact>> contactsByAccountId = new Map<Id, List<Contact>>();
    for (Contact con : [SELECT Id, Email, AccountId FROM Contact WHERE AccountId IN :accountIds]) {
        if (!contactsByAccountId.containsKey(con.AccountId)) {
            contactsByAccountId.put(con.AccountId, new List<Contact>());
        }
        contactsByAccountId.get(con.AccountId).add(con);
    }

    for (Account acc : accounts) {
        List<Contact> contacts = contactsByAccountId.get(acc.Id);
        if (contacts != null) sendEmailsToContacts(contacts);
    }
}
```

### Use Aggregate Queries to Replace Multiple Queries

```apex
// 1 query instead of N
Map<String, Integer> countsByType = new Map<String, Integer>();
for (AggregateResult ar : [
    SELECT Type, COUNT(Id) cnt FROM Account WHERE Type != null GROUP BY Type
]) {
    countsByType.put((String) ar.get('Type'), (Integer) ar.get('cnt'));
}
```

---

## DML Limit Strategies

### Collect Records, Single DML After Loop

```apex
public void setDefaultTitle(List<Contact> contacts) {
    List<Contact> toUpdate = new List<Contact>();
    for (Contact con : contacts) {
        if (String.isBlank(con.Title)) {
            toUpdate.add(new Contact(Id = con.Id, Title = 'Business Contact'));
        }
    }
    if (!toUpdate.isEmpty()) {
        update toUpdate; // 1 DML regardless of list size
    }
}
```

### Partial Success DML

Use when processing a batch where some records may be invalid — fail individual records without rolling back the entire set.

```apex
List<Database.SaveResult> results = Database.insert(accounts, false);
List<String> errors = new List<String>();
for (Integer i = 0; i < results.size(); i++) {
    if (!results[i].isSuccess()) {
        for (Database.Error err : results[i].getErrors()) {
            errors.add(accounts[i].Name + ': ' + err.getMessage());
        }
    }
}
if (!errors.isEmpty()) ErrorLogger.log(errors);
```

### Unit of Work Pattern

For complex transactions creating related records across multiple objects — collect all records and commit once to minimize DML statements.

```apex
SimpleUnitOfWork uow = new SimpleUnitOfWork();
Account acc = new Account(Name = 'New Customer');
uow.registerNew(acc);
Contact primary = new Contact(LastName = 'Primary');
uow.registerNew(primary, Contact.AccountId, acc);
uow.commitWork(); // Inserts parent first, resolves IDs, then children
```

---

## Heap Limit Strategies

### Select Minimal Fields

```apex
// COUNT() uses no heap — never load full sObjects just to count
Integer count = [SELECT COUNT() FROM Account WHERE Industry = 'Tech'];

// Select only fields the calling code actually uses
List<Account> accounts = [SELECT Id, Name FROM Account WHERE Id IN :accountIds];
```

### Use Maps Instead of Parallel Lists

```apex
// One Map replaces two synchronized List + index bookkeeping
Map<Id, String> accountNameById = new Map<Id, String>();
for (Account acc : accounts) {
    accountNameById.put(acc.Id, acc.Name);
}
```

### Nullify Large References When Done

```apex
List<SObject> largeDataSet = loadLargeDataSet();
List<String> results = extractResults(largeDataSet);
largeDataSet = null; // Eligible for garbage collection before saveResults()
saveResults(results);
```

---

## CPU Time Strategies

### Use Maps Instead of Nested Loops

```apex
// O(n) using Set lookup instead of O(n²) nested loop
Set<Id> validAccountIds = new Set<Id>(new Map<Id, Account>(validAccounts).keySet());
List<Contact> orphaned = new List<Contact>();
for (Contact con : contacts) {
    if (!validAccountIds.contains(con.AccountId)) {
        orphaned.add(con);
    }
}
```

### Use String.join Instead of Concatenation in Loops

```apex
// One allocation instead of O(n) intermediate String objects
List<String> names = new List<String>();
for (Account acc : accounts) names.add(acc.Name);
String output = String.join(names, ', ');
```

### Offload to Async When CPU Budget Is Low

```apex
if (Limits.getCpuTime() > 8000) { // 8 of 10 seconds used
    System.enqueueJob(new AccountProcessorJob(
        new List<Id>(new Map<Id, Account>(accounts).keySet())
    ));
    return;
}
performExpensiveProcessing(accounts);
```

---

## Callout Limit Strategies

### @future(callout=true) from Triggers

Triggers cannot make synchronous callouts. Use `@future` to defer — or prefer Queueable for new code.

```apex
public class AccountERPSyncService {
    @future(callout=true)
    public static void syncToERP(List<Id> accountIds) {
        List<Account> accounts = [
            SELECT Id, Name, External_Id__c FROM Account WHERE Id IN :accountIds
        ];
        for (Account acc : accounts) ERPClient.syncAccount(acc);
    }
}
```

### Queueable for Callout Chains

Use when the number of records exceeds the per-job callout limit (100) or when sequential ordering is required.

```apex
public class SequentialCalloutJob implements Queueable, Database.AllowsCallouts {

    private final List<Id> accountIds;
    private final Integer  currentIndex;

    public SequentialCalloutJob(List<Id> accountIds) { this(accountIds, 0); }
    private SequentialCalloutJob(List<Id> ids, Integer startIndex) {
        this.accountIds   = ids;
        this.currentIndex = startIndex;
    }

    public void execute(QueueableContext ctx) {
        final Integer CALLOUTS_PER_JOB = 90; // leave buffer below 100 limit
        Integer end = Math.min(currentIndex + CALLOUTS_PER_JOB, accountIds.size());
        for (Integer i = currentIndex; i < end; i++) {
            ERPClient.syncAccount(accountIds[i]);
        }
        if (end < accountIds.size()) {
            System.enqueueJob(new SequentialCalloutJob(accountIds, end));
        }
    }
}
```

---

## Async Decision Tree

```
Completes in < 5s with sync limits?         → Synchronous Apex
Processing > 200 records?                    → Batch Apex
Callouts required from trigger context?      → @future(callout=true) or Queueable + AllowsCallouts
CPU exceeding 8,000ms regularly?             → Profile first; offload tail work to Queueable
Recurring scheduled operation?              → Schedulable wrapping Batch or Queueable
```

---

## Testing at Limits

### 200-Record Bulk Test — Standard Trigger Validation

`Test.startTest()` resets all governor limit counters. Always test triggers with 200 records (the standard trigger batch size).

```apex
@isTest
static void testTrigger_200RecordBulkInsert_noLimitException() {
    List<Account> accounts = new List<Account>();
    for (Integer i = 0; i < 200; i++) {
        accounts.add(new Account(Name = 'Bulk Test ' + i, Type = 'Customer'));
    }

    Test.startTest();
    insert accounts;
    Test.stopTest();

    Assert.areEqual(200,
        [SELECT COUNT() FROM Account WHERE Type = 'Customer'],
        'All 200 accounts should be inserted');
}
```

### Query Count Assertion — Catch Regressions Early

```apex
@isTest
static void testService_queriesStayWithinLimits() {
    List<Account> accounts = TestDataFactory.createAccounts(50);
    insert accounts;

    Test.startTest();
    Integer queriesBefore = Limits.getQueries();
    AccountService.processAll(new Map<Id, Account>(accounts).keySet());
    Integer queriesUsed = Limits.getQueries() - queriesBefore;
    Test.stopTest();

    Assert.isTrue(queriesUsed <= 5,
        'processAll() should use at most 5 SOQL queries. Actual: ' + queriesUsed);
}
```

> **Note:** Async work enqueued inside `Test.startTest()` / `Test.stopTest()` runs synchronously at `stopTest()`. This means Queueable and `@future` jobs execute within the test transaction and their limit consumption is visible after `stopTest()`.
