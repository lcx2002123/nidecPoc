# Common Salesforce Apex Errors — Quick Reference

For deep root-cause analysis from log files, delegate to [debugging-apex-logs](../../debugging-apex-logs/SKILL.md). This file is a quick lookup for known patterns and their fixes.

---

## System.LimitException: Too many SOQL queries: 101

**Root cause:** SOQL query inside a loop.

```apex
// WRONG
for (Account acc : Trigger.new) {
    List<Contact> contacts = [SELECT Id FROM Contact WHERE AccountId = :acc.Id];
}

// FIX — single bulk query, then map lookup
Map<Id, List<Contact>> contactsByAccount = new Map<Id, List<Contact>>();
for (Contact c : [SELECT Id, AccountId FROM Contact
                  WHERE AccountId IN :Trigger.newMap.keySet()]) {
    contactsByAccount.computeIfAbsent(c.AccountId, k -> new List<Contact>()).add(c);
}
```

---

## Apex CPU time limit exceeded

**Root cause:** O(n²) nested loops or excessive string operations.

```apex
// WRONG — O(n²)
for (Account acc : accounts) {
    for (Contact con : allContacts) {
        if (con.AccountId == acc.Id) { /* process */ }
    }
}

// FIX — O(n) with Map
Map<Id, List<Contact>> contactsByAccount = buildContactMap(allContacts);
for (Account acc : accounts) {
    List<Contact> mine = contactsByAccount.get(acc.Id);
}
```

---

## System.NullPointerException

**Root cause:** Unchecked null reference — accessing a method on a null object.

```apex
// FIX — null-safe navigation (API 56.0+)
String upperName  = account.Name?.toUpperCase() ?? '';
String parentName = contact?.Account?.Name ?? 'No Account';
```

For older API versions: `if (account != null && account.Name != null)` guards.

---

## UNABLE_TO_LOCK_ROW

**Root cause:** Two concurrent transactions updating the same record(s).

Fix options (in order of preference):
1. Reduce batch size so fewer records are locked at once.
2. Add `FOR UPDATE` to the SOQL query to acquire the lock up front and fail fast.
3. Move processing to Queueable with exponential back-off retry.

---

## MIXED_DML_OPERATION

**Root cause:** Setup objects (User, Profile, PermissionSet, etc.) and non-setup objects modified in the same transaction.

```apex
// FIX — separate into different execution contexts
System.runAs(testUser) {
    // Setup DML here (in tests)
}
// Non-setup DML outside runAs

// In production code, move setup DML to @future
@future
public static void updateUserSettings(Id userId, Boolean flag) {
    User u = new User(Id = userId, IsActive = flag);
    update u;
}
```

---

## Too many DML rows: 10001

**Root cause:** Attempting to DML more than 10,000 rows in a single transaction.

Fix: use **Batch Apex** with a batch size of 200 (default) to process large datasets in chunks.

---

## Callout from triggers are not supported

**Root cause:** Synchronous HTTP callout attempted in a trigger context.

Fix: move the callout to `@future(callout=true)`, Queueable, or a Platform Event handler — see [callout-debugging.md](callout-debugging.md) for patterns.

---

## System.QueryException: List has no rows for assignment to SObject

**Root cause:** `SObject s = [SELECT ... LIMIT 1]` returned zero rows.

```apex
// FIX — use a List instead
List<Account> accounts = [SELECT Id FROM Account WHERE Name = :name LIMIT 1];
if (!accounts.isEmpty()) {
    Account acc = accounts[0];
}
```
