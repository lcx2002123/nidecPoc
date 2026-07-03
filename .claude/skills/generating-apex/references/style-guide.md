# Apex Style Guide

NimbleUser Apex Style Guide (fork of Google Java Style Guide) に基づく。

## Source File Structure

**Required Order:**
1. ApexDoc class comment
2. Class declaration
3. Constants → Static fields → Instance fields → Constructors → Public methods → Private methods → Inner classes

One top-level class per file. File name must match class name with `.cls` extension. UTF-8, no tabs (4 spaces).

## Braces (K&R Style)

Always required for `if`, `else`, `for`, `do`, `while` — even single-line bodies.

```apex
// ✅ CORRECT
if (isValid) {
    processRecord();
}

if (count > 0) {
    updateRecords();
} else {
    createRecords();
}

// Empty block allowed
public void emptyMethod() {}

// ❌ WRONG — missing braces
if (isValid)
    processRecord();

// ❌ WRONG — opening brace on new line
if (isValid)
{
    processRecord();
}
```

## Indentation & Line Length

- Block indent: **+4 spaces**, no tabs
- Column limit: **120 characters**
- Continuation lines: minimum +4 spaces
- Non-assignment operators: break **before** the symbol

```apex
// ✅ Method call wrapping
Account newAccount = AccountFactory.createAccount(
    accountName,
    industryType,
    annualRevenue
);

// ✅ Long condition wrapping
if (account.AnnualRevenue > THRESHOLD
    && account.Industry == 'Technology'
    && account.Rating == 'Hot') {
    processHighValueAccount(account);
}
```

## SOQL Formatting

Reserved words in ALL UPPERCASE. Break before reserved words. Standard +4 space indent.

```apex
List<Account> accounts = [
    SELECT Id, Name, Industry, AnnualRevenue,
        (SELECT Id, FirstName, LastName FROM Contacts)
    FROM Account
    WHERE Industry = :targetIndustry
        AND AnnualRevenue > :minRevenue
    ORDER BY Name
    LIMIT 200
];
```

## Naming Conventions

| Element | Convention | Example |
|---------|-----------|---------|
| Class | UpperCamelCase | `AccountService` |
| Test Class | `<Class>Test` | `AccountServiceTest` |
| Method | lowerCamelCase verb | `getAccountById` |
| Test Method | `<method>_<condition>_<expectation>` | `getById_withValidId_returnsAccount` |
| Constant | CONSTANT_CASE | `MAX_RETRY_COUNT` |
| Field | lowerCamelCase | `accountRepository` |
| Property | UpperCamelCase | `AccountName` |
| Parameter/Local | lowerCamelCase | `accountToUpdate` |

## ApexDoc

Required on all `global` and `public` classes and their `public`/`protected` members.

At-clauses order: `@description` → `@param` → `@return` → `@throws`

```apex
/**
 * @description Retrieves active accounts for the specified industry
 * @param industry The industry to filter accounts
 * @param minRevenue The minimum annual revenue threshold
 * @return List of active accounts matching criteria, or empty list
 * @throws QueryException if database query fails
 */
public List<Account> getActiveAccounts(String industry, Decimal minRevenue) {
    // implementation
}
```

## Exception Handling

```apex
// ❌ WRONG — silent failure
try {
    processRecords();
} catch (Exception e) {}

// ✅ CORRECT — log and rethrow
try {
    processRecords();
} catch (DmlException e) {
    System.debug(LoggingLevel.ERROR, 'Failed to process records: ' + e.getMessage());
    throw new ProcessingException('Unable to complete processing', e);
}
```

## Bulkification & Governor Limits

| Limit | Sync | Async |
|-------|------|-------|
| SOQL queries | 100 | 200 |
| DML statements | 150 | 150 |
| Records per DML | 10,000 | 10,000 |
| Heap size | 6 MB | 12 MB |
| CPU time | 10,000 ms | 60,000 ms |

```apex
// ✅ CORRECT — query and DML outside loops
Map<Id, Account> accountMap = new Map<Id, Account>(
    [SELECT Id, Name FROM Account WHERE Id IN :accountIds]
);
List<Account> toUpdate = new List<Account>();
for (Contact con : contacts) {
    Account acc = accountMap.get(con.AccountId);
    if (acc != null && acc.AnnualRevenue > 1000000) {
        acc.Rating = 'Hot';
        toUpdate.add(acc);
    }
}
if (!toUpdate.isEmpty()) {
    update toUpdate;
}

// ❌ WRONG — SOQL in loop
for (Contact con : contacts) {
    Account acc = [SELECT Id, Name FROM Account WHERE Id = :con.AccountId];
}
```

## Testing Best Practices

```apex
@isTest
private class AccountServiceTest {

    @isTest
    static void getAccountById_withValidId_returnsAccount() {
        // Setup
        Account testAccount = TestDataFactory.createAccount('Test Corp');
        insert testAccount;

        // Execute
        Test.startTest();
        Account result = AccountService.getAccountById(testAccount.Id);
        Test.stopTest();

        // Verify
        System.assertNotEquals(null, result, 'Account should be found');
        System.assertEquals('Test Corp', result.Name, 'Account name should match');
    }
}
```

Rules:
- All test classes are `private` and annotated `@isTest`
- Wrap the operation under test with `Test.startTest()` / `Test.stopTest()`
- Avoid `@isTest(SeeAllData=true)` — use test data factories

## Common Patterns

**Service Class:**
```apex
public with sharing class AccountService {
    private AccountRepository repository;

    public AccountService() {
        this.repository = new AccountRepository();
    }

    public List<Account> getActiveAccounts() {
        return repository.findActiveAccounts();
    }
}
```

**Trigger Handler:**
```apex
public class AccountTriggerHandler extends TriggerHandler {
    public override void beforeInsert() {
        for (Account acc : (List<Account>) Trigger.new) {
            validateAccount(acc);
        }
    }

    private void validateAccount(Account acc) {
        // validation logic
    }
}
```
