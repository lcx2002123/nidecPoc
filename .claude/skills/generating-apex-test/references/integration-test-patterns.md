# Integration Test Patterns

Full-stack Apex test patterns that verify complete business workflows, including trigger chains, Flow automation, Platform Events, async jobs, and multi-user access control. Use these when unit tests and isolated service tests are already passing and you need to verify end-to-end behavior.

---

## Multi-Step Workflow Test

Verifies that a business process executes correctly across multiple DML operations and that downstream automation fires at each stage.

```apex
@IsTest
private class OpportunityWorkflowTest {

    @TestSetup
    static void setup() {
        Account acc = TestDataFactory.createAccount('E2E Test Account', true);
        TestDataFactory.createOpportunity(acc.Id, 'E2E Test Opp', 'Prospecting', 50000, true);
    }

    @IsTest
    static void shouldProgressThroughFullSalesCycle() {
        Opportunity opp = [SELECT Id, StageName FROM Opportunity LIMIT 1];

        Test.startTest();
        opp.StageName = 'Qualification';
        update opp;

        opp.StageName = 'Proposal/Price Quote';
        update opp;

        opp.StageName = 'Closed Won';
        update opp;
        Test.stopTest();

        Opportunity result = [SELECT StageName, IsClosed, IsWon FROM Opportunity WHERE Id = :opp.Id];
        Assert.areEqual('Closed Won', result.StageName, 'Stage should be Closed Won');
        Assert.isTrue(result.IsClosed, 'Should be closed');
        Assert.isTrue(result.IsWon, 'Should be won');

        // Verify downstream automation fired
        List<Task> followUpTasks = [SELECT Id FROM Task WHERE WhatId = :opp.Id];
        Assert.isFalse(followUpTasks.isEmpty(), 'Trigger/Flow should have created follow-up tasks');
    }

    @IsTest
    static void shouldHandleBulkStageChanges() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        List<Opportunity> opps = new List<Opportunity>();
        for (Integer i = 0; i < 200; i++) {
            opps.add(TestDataFactory.buildOpportunity(acc.Id, 'Bulk Opp ' + i, 'Prospecting', 0));
        }
        insert opps;

        Test.startTest();
        for (Opportunity opp : opps) opp.StageName = 'Closed Won';
        update opps;
        Test.stopTest();

        Integer closedCount = [SELECT COUNT() FROM Opportunity WHERE StageName = 'Closed Won'];
        Assert.isTrue(closedCount >= 200, '200 opportunities should be closed, found: ' + closedCount);
    }
}
```

---

## Flow Integration Test

Verifies that a record-triggered Flow fired and produced the expected downstream side effects (created records, field updates, notifications).

```apex
@IsTest
private class CaseEscalationFlowTest {

    @IsTest
    static void shouldEscalateHighPriorityCases() {
        Account acc = TestDataFactory.createAccount('Flow E2E Account', true);
        Case c = new Case(
            AccountId = acc.Id,
            Subject   = 'Urgent Issue',
            Priority  = 'High',
            Status    = 'New'
        );
        insert c;

        Test.startTest();
        c.Status = 'Escalated';
        update c;
        Test.stopTest();

        List<Task> tasks = [
            SELECT Subject, Priority FROM Task
            WHERE WhatId = :c.Id AND Subject LIKE '%Escalation%'
        ];
        Assert.isFalse(tasks.isEmpty(), 'Flow should have created an escalation task');
        Assert.areEqual('High', tasks[0].Priority,
            'Task priority should inherit from case priority');
    }
}
```

> If the Flow has asynchronous paths (Screen Flows, some Wait elements), you may need `Test.stopTest()` to flush deferred execution before asserting.

---

## Platform Event — Publish and Subscriber Verification

Two distinct test methods: one verifies the event publishes without error; the second forces the subscriber trigger to execute and verifies its side effects.

```apex
@IsTest
private class OrderEventTest {

    @IsTest
    static void shouldPublishEventOnOrderCompletion() {
        Order_Complete__e event = new Order_Complete__e(
            Order_Id__c    = 'ORD-001',
            Total_Amount__c = 5000.00
        );

        Test.startTest();
        Database.SaveResult sr = EventBus.publish(event);
        Test.stopTest();

        Assert.isTrue(sr.isSuccess(), 'Platform Event should publish successfully');
    }

    @IsTest
    static void shouldProcessEventInSubscriber() {
        Order_Complete__e event = new Order_Complete__e(
            Order_Id__c    = 'ORD-002',
            Total_Amount__c = 10000.00
        );

        Test.startTest();
        EventBus.publish(event);
        Test.getEventBus().deliver(); // Forces the subscriber trigger to execute synchronously
        Test.stopTest();

        List<Fulfillment__c> fulfillments = [
            SELECT Order_Id__c FROM Fulfillment__c WHERE Order_Id__c = 'ORD-002'
        ];
        Assert.areEqual(1, fulfillments.size(),
            'Subscriber trigger should have created one fulfillment record');
    }
}
```

> `Test.getEventBus().deliver()` must be called **inside** `Test.startTest()` / `Test.stopTest()` to flush the event bus synchronously.

---

## Async Job (Queueable) Chain Verification

`Test.stopTest()` forces all enqueued Queueable jobs to execute synchronously. Assert on the final state after the chain completes.

```apex
@IsTest
private class AsyncWorkflowTest {

    @IsTest
    static void shouldProcessQueueableChain() {
        Account acc = TestDataFactory.createAccount('Async E2E', true);

        Test.startTest();
        System.enqueueJob(new AccountEnrichmentJob(acc.Id));
        Test.stopTest(); // AccountEnrichmentJob runs here; any chained jobs also run

        Account result = [SELECT Description, Industry FROM Account WHERE Id = :acc.Id];
        Assert.isNotNull(result.Description,
            'AccountEnrichmentJob should populate Description');
    }
}
```

> In test context, only the **first** Queueable in a chain executes. If the job enqueues a second job, that second job also runs (chain depth = 1). Test the final state, not intermediate states.

---

## Multi-User / Permission Testing

Use `System.runAs()` to verify that sharing rules, permission sets, and record visibility behave correctly for different user profiles.

```apex
@IsTest
private class PermissionE2ETest {

    @IsTest
    static void shouldRestrictAccessForStandardUser() {
        // Note: Profile names are locale-dependent.
        // For non-English orgs, query by Profile.UserType instead.
        Profile stdProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User testUser = new User(
            Alias             = 'stdu',
            Email             = 'stduser@test.example.com',
            EmailEncodingKey  = 'UTF-8',
            LastName          = 'StdUser',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey      = 'en_US',
            ProfileId         = stdProfile.Id,
            TimeZoneSidKey    = 'America/Los_Angeles',
            UserName          = 'stduser' + DateTime.now().getTime() + '@test.example.com'
        );
        insert testUser;

        System.runAs(testUser) {
            Test.startTest();
            try {
                ConfidentialRecord__c rec = new ConfidentialRecord__c(Name = 'Secret');
                insert rec;
                Assert.fail('Should have thrown insufficient access exception');
            } catch (DmlException e) {
                Assert.isTrue(
                    e.getMessage().containsIgnoreCase('INSUFFICIENT_ACCESS') ||
                    e.getMessage().containsIgnoreCase('access'),
                    'Expected access-denied error, got: ' + e.getMessage()
                );
            }
            Test.stopTest();
        }
    }

    @IsTest
    static void shouldAllowAccessForAdminUser() {
        // Admin test counterpart — verify the positive case too
        ConfidentialRecord__c rec = new ConfidentialRecord__c(Name = 'Admin Record');
        insert rec;

        ConfidentialRecord__c result = [SELECT Id, Name FROM ConfidentialRecord__c WHERE Id = :rec.Id];
        Assert.areEqual('Admin Record', result.Name,
            'Running user (System Admin) should have full read access');
    }
}
```

> Always test both the **restricted** and **permitted** paths. A test that only verifies the negative case gives false confidence if the object's OWD changes.

---

## Performance Assertions

Measure governor limit consumption inside `Test.startTest()` / `Test.stopTest()` to catch regressions before they reach production.

```apex
@IsTest
private class PerformanceE2ETest {

    @IsTest
    static void shouldStayWithinGovernorLimits() {
        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < 200; i++) {
            accounts.add(TestDataFactory.buildAccount('Perf Test ' + i));
        }
        insert accounts;
        Set<Id> accountIds = new Map<Id, Account>(accounts).keySet();

        Test.startTest();
        Integer queriesBefore = Limits.getQueries();
        AccountService.processAccounts(accountIds);
        Integer queriesUsed = Limits.getQueries() - queriesBefore;
        Test.stopTest();

        Assert.isTrue(queriesUsed <= 5,
            'processAccounts() should use <= 5 SOQL queries for 200 records. Actual: ' + queriesUsed);
    }
}
```

> Capture `Limits.getQueries()` **after** `Test.startTest()` so the counter reflects only the code under test, not setup queries.

---

## Anti-Patterns

| Anti-Pattern | Problem | Fix |
|---|---|---|
| Testing with 1 record only | Misses bulkification bugs | Always include a 200+ record variant |
| No `Test.startTest()`/`Test.stopTest()` | Setup queries consume test's governor budget | Wrap code under test in start/stop |
| `@IsTest(SeeAllData=true)` | Tests depend on org data, fail on sandbox refresh | Use `@TestSetup` with `TestDataFactory` |
| Hardcoded record IDs | Break across orgs and sandboxes | Query for IDs or create records |
| Asserting only that DML succeeded | Automation may have silently failed | Assert on records created by automation |
| Ignoring async results | Queueable/Batch results invisible | `Test.stopTest()` forces execution; assert after |
| Single test method for multiple scenarios | Masks which scenario fails | One scenario per test method |
