# Trigger Framework Implementations

Full reference implementations for the three main Salesforce trigger framework patterns. Use when adopting a new framework, refactoring bare trigger logic, or troubleshooting recursion and bypass issues.

---

## The Pragmatic TriggerHandler Pattern

A clean, dependency-free framework. The base class provides context-aware routing, bypass mechanism, and recursion depth control.

### TriggerHandler Base Class

```apex
public virtual class TriggerHandler {

    // Bypass Registry
    private static Set<String> bypassedHandlers = new Set<String>();

    // Recursion Control
    private static Map<String, Integer> depthMap = new Map<String, Integer>();
    private static final Integer MAX_DEPTH = 2;

    // Context Properties
    @TestVisible protected Boolean isBefore   { get { return Trigger.isBefore; } }
    @TestVisible protected Boolean isAfter    { get { return Trigger.isAfter; } }
    @TestVisible protected Boolean isInsert   { get { return Trigger.isInsert; } }
    @TestVisible protected Boolean isUpdate   { get { return Trigger.isUpdate; } }
    @TestVisible protected Boolean isDelete   { get { return Trigger.isDelete; } }
    @TestVisible protected Boolean isUndelete { get { return Trigger.isUndelete; } }

    protected List<SObject>    newList { get { return Trigger.new; } }
    protected Map<Id, SObject> newMap  { get { return Trigger.newMap; } }
    protected List<SObject>    oldList { get { return Trigger.old; } }
    protected Map<Id, SObject> oldMap  { get { return Trigger.oldMap; } }

    public void run() {
        String handlerName = getHandlerName();
        if (isBypassed(handlerName)) return;
        if (exceedsMaxDepth(handlerName)) return;

        incrementDepth(handlerName);
        try { dispatch(); }
        finally { decrementDepth(handlerName); }
    }

    private void dispatch() {
        if (isBefore) {
            if (isInsert) onBeforeInsert();
            if (isUpdate) onBeforeUpdate();
            if (isDelete) onBeforeDelete();
        } else if (isAfter) {
            if (isInsert)   onAfterInsert();
            if (isUpdate)   onAfterUpdate();
            if (isDelete)   onAfterDelete();
            if (isUndelete) onAfterUndelete();
        }
    }

    // Virtual Methods — Override in Concrete Handlers
    @TestVisible protected virtual void onBeforeInsert()   {}
    @TestVisible protected virtual void onBeforeUpdate()   {}
    @TestVisible protected virtual void onBeforeDelete()   {}
    @TestVisible protected virtual void onAfterInsert()    {}
    @TestVisible protected virtual void onAfterUpdate()    {}
    @TestVisible protected virtual void onAfterDelete()    {}
    @TestVisible protected virtual void onAfterUndelete()  {}

    // Bypass API
    public static void bypass(String handlerName)        { bypassedHandlers.add(handlerName); }
    public static void clearBypass(String handlerName)   { bypassedHandlers.remove(handlerName); }
    public static void clearAllBypasses()                { bypassedHandlers.clear(); }
    public static Boolean isBypassed(String handlerName) { return bypassedHandlers.contains(handlerName); }

    // Private Helpers
    private String  getHandlerName()            { return String.valueOf(this).split(':')[0]; }
    private Boolean exceedsMaxDepth(String h)   { return getDepth(h) >= MAX_DEPTH; }
    private Integer getDepth(String h)          { return depthMap.containsKey(h) ? depthMap.get(h) : 0; }
    private void    incrementDepth(String h)    { depthMap.put(h, getDepth(h) + 1); }
    private void    decrementDepth(String h)    { Integer c = getDepth(h); if (c > 0) depthMap.put(h, c - 1); }
}
```

### Concrete Handler

```apex
public class AccountTriggerHandler extends TriggerHandler {

    private List<Account>    newAccounts;
    private Map<Id, Account> oldAccountMap;

    public AccountTriggerHandler() {
        newAccounts   = (List<Account>) newList;
        oldAccountMap = (Map<Id, Account>) oldMap;
    }

    override protected void onBeforeInsert() {
        AccountDefaults.setDefaults(newAccounts);
        AccountValidator.validateForInsert(newAccounts);
    }

    override protected void onBeforeUpdate() {
        AccountValidator.validateForUpdate(newAccounts, oldAccountMap);
    }

    override protected void onAfterInsert() {
        AccountOpportunityCreator.createDefaultOpportunities(newAccounts);
    }

    override protected void onAfterUpdate() {
        AccountRelatedUpdater.syncContactOwnership(
            (Map<Id, Account>) newMap, oldAccountMap
        );
    }
}
```

### Trigger File

```apex
trigger AccountTrigger on Account (
    before insert, before update, before delete,
    after insert, after update, after delete, after undelete
) {
    new AccountTriggerHandler().run();
}
```

---

## FFLIB Domain Layer

For orgs using the FFLIB Apex Commons library, the Domain layer is the preferred trigger handling mechanism.

```apex
public with sharing class Accounts extends fflib_SObjectDomain {

    public Accounts(List<Account> sObjectList) {
        super(sObjectList);
        Configuration.disableTriggerCRUDSecurity();
    }

    public override void onBeforeInsert() {
        setDefaultCustomerTier();
    }

    public override void onBeforeUpdate(Map<Id, SObject> existingRecords) {
        preventPremiumTierDowngrade((Map<Id, Account>) existingRecords);
    }

    public class Constructor implements fflib_SObjectDomain.IConstructable {
        public fflib_SObjectDomain construct(List<SObject> sObjectList) {
            return new Accounts(sObjectList);
        }
    }
}
```

> `Configuration.disableTriggerCRUDSecurity()` is required because trigger handlers operate on records the platform has already committed. Do NOT disable CRUD security in Service or Controller layers.

---

## TDTM (Table-Driven Trigger Management)

Registers handlers in Custom Metadata (`Trigger_Handler__mdt`), enabling enable/disable without a code deployment.

**Required CMDT fields:** `Object_Name__c`, `Handler_Class__c`, `Trigger_Event__c`, `Is_Active__c`, `Execution_Order__c`

```apex
public class TDTMDispatcher {

    private static Map<String, List<Trigger_Handler__mdt>> handlerCache =
        new Map<String, List<Trigger_Handler__mdt>>();

    public static void run(
        String objectName, String triggerEvent,
        List<SObject> newList, List<SObject> oldList,
        Map<Id, SObject> newMap, Map<Id, SObject> oldMap
    ) {
        String cacheKey = objectName + ':' + triggerEvent;
        List<Trigger_Handler__mdt> activeHandlers;

        if (handlerCache.containsKey(cacheKey)) {
            activeHandlers = handlerCache.get(cacheKey);
        } else {
            activeHandlers = [
                SELECT Handler_Class__c, Execution_Order__c
                FROM Trigger_Handler__mdt
                WHERE Object_Name__c  = :objectName
                  AND Trigger_Event__c = :triggerEvent
                  AND Is_Active__c    = true
                ORDER BY Execution_Order__c ASC
            ];
            handlerCache.put(cacheKey, activeHandlers);
        }

        for (Trigger_Handler__mdt cfg : activeHandlers) {
            Type handlerType = Type.forName(cfg.Handler_Class__c);
            if (handlerType == null) continue;
            ITriggerHandler handler = (ITriggerHandler) handlerType.newInstance();
            handler.execute(newList, oldList, newMap, oldMap);
        }
    }

    public interface ITriggerHandler {
        void execute(List<SObject> newList, List<SObject> oldList,
                     Map<Id, SObject> newMap, Map<Id, SObject> oldMap);
    }
}
```

To disable a handler for a data migration: set `Is_Active__c = false` in Setup — no code deployment needed.

---

## Bypass Mechanisms

### Option 1 — Static Boolean (Simple)

```apex
public class TriggerBypasses {
    public static Boolean bypassAccountTrigger = false;
}

// Usage — always use try/finally to guarantee cleanup
TriggerBypasses.bypassAccountTrigger = true;
try {
    insert accountsToMigrate;
} finally {
    TriggerBypasses.bypassAccountTrigger = false;
}
```

### Option 2 — Framework-Level (`TriggerHandler.bypass()`)

```apex
TriggerHandler.bypass('AccountTriggerHandler');
try {
    insert accounts;
} finally {
    TriggerHandler.clearBypass('AccountTriggerHandler');
}
```

### Option 3 — Custom Metadata (Declarative)

Map users or profiles to bypassed handlers via a `Trigger_Bypass__mdt` record. No code change or deployment needed — toggle in Setup.

---

## Recursion Prevention

### Static Set of Processed IDs

```apex
public class AccountTriggerHandler extends TriggerHandler {

    @TestVisible
    private static Set<Id> processedIds = new Set<Id>();

    override protected void onAfterUpdate() {
        List<Account> unprocessed = new List<Account>();
        for (Account acc : (List<Account>) newList) {
            if (!processedIds.contains(acc.Id)) {
                processedIds.add(acc.Id);
                unprocessed.add(acc);
            }
        }
        if (!unprocessed.isEmpty()) {
            AccountRelatedUpdater.syncContactOwnership(
                new Map<Id, Account>(unprocessed), (Map<Id, Account>) oldMap
            );
        }
    }
}
```

> **Testing note:** Static variables reset between test methods. Within a single test method they persist across multiple trigger executions — account for this when asserting call counts.

### Execution Depth Counter

Built into the `TriggerHandler` base class (`MAX_DEPTH = 2`). When a handler is invoked more than `MAX_DEPTH` times in the same transaction, subsequent calls are skipped. This prevents infinite recursion while allowing a single re-entry (e.g., a field update that triggers the same handler once).

---

## Migration Guide: Bare Trigger → Framework

1. Deploy `TriggerHandler.cls` base class to the org
2. Create the handler stub: `public class AccountTriggerHandler extends TriggerHandler {}`
3. Refactor the trigger body: replace all logic with `new AccountTriggerHandler().run();`
4. Move logic method by method into handler overrides and/or service classes
5. Add bypass support via base class or Custom Metadata
6. Delete old multiple-trigger files after consolidation (one trigger per object)

---

## Testing Trigger Frameworks

```apex
@isTest
static void testBypassMechanism_noDefaultsSetWhenBypassed() {
    TriggerHandler.bypass('AccountTriggerHandler');
    Account acc = new Account(Name = 'Bypass Test', Type = 'Customer', Industry = 'Tech');

    Test.startTest();
    insert acc;
    Test.stopTest();

    TriggerHandler.clearBypass('AccountTriggerHandler');

    Account result = [SELECT Customer_Tier__c FROM Account WHERE Id = :acc.Id];
    Assert.isNull(result.Customer_Tier__c,
        'Tier should NOT be set when handler is bypassed');
}
```
