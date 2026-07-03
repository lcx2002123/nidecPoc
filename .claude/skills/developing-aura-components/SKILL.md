---
name: developing-aura-components
description: "Aura component development — bundle structure (.cmp, Controller.js, Helper.js), event handling, server-side actions via $A.enqueueAction, Locker Service, and LWC interoperability. TRIGGER when: user maintains or extends existing Aura components, debugs $A.enqueueAction callbacks or Aura event propagation, builds Aura-LWC interop layers, or asks about Aura-specific APIs. DO NOT TRIGGER for new LWC development (use generating-lwc-components). For Aura→LWC migration strategy, see generating-lwc-components ## Migrating from Aura."
origin: SCC
user-invocable: false
---

# developing-aura-components: Aura Component Maintenance & Interoperability

Aura is Salesforce's original Lightning component framework (introduced 2014). While LWC is the modern standard, thousands of production orgs still run Aura components. Use this skill when **maintaining, extending, or debugging** existing Aura components, or when building **Aura-LWC interoperability layers**.

> **Aura is in maintenance mode.** For new component development use [generating-lwc-components](../generating-lwc-components/SKILL.md). For migration guidance, see the `## Migrating from Aura` section in that skill.

## When This Skill Owns the Task

- Maintaining or extending existing Aura components that cannot be rewritten immediately
- Debugging Aura event propagation, `$A.enqueueAction` callbacks, or Locker Service errors
- Building interoperability layers between LWC and Aura
- Understanding Aura source patterns as context for migration to LWC

Delegate elsewhere when the user is:
- building new components → [generating-lwc-components](../generating-lwc-components/SKILL.md)
- migrating Aura to LWC → [generating-lwc-components](../generating-lwc-components/SKILL.md) (`## Migrating from Aura`)
- deploying Aura bundles → [deploying-metadata](../deploying-metadata/SKILL.md)

---

## Component Bundle Structure

An Aura component is a folder (bundle) containing up to eight files. Only the `.cmp` file is required.

```
force-app/main/default/aura/AccountManager/
    AccountManager.cmp           ← Component markup (required)
    AccountManagerController.js  ← Client-side controller (action handlers)
    AccountManagerHelper.js      ← Reusable logic (called by controller)
    AccountManagerRenderer.js    ← Custom rendering overrides (rare)
    AccountManager.css           ← Component-scoped styles
    AccountManager.design        ← App Builder property editor config
    AccountManager.cmp-meta.xml  ← Metadata (apiVersion, description)
```

### Component Markup (.cmp)

```xml
<aura:component controller="AccountController"
                implements="force:appHostable,flexipage:availableForAllPageTypes"
                access="global">
    <aura:attribute name="accounts" type="Account[]" default="[]" />
    <aura:attribute name="isLoading" type="Boolean" default="true" />
    <aura:attribute name="errorMessage" type="String" />

    <aura:registerEvent name="accountSelected" type="c:AccountSelectedEvent" />
    <aura:handler name="init" value="{!this}" action="{!c.doInit}" />

    <lightning:card title="Account Manager" iconName="standard:account">
        <aura:if isTrue="{!v.isLoading}">
            <lightning:spinner alternativeText="Loading" size="small" />
            <aura:set attribute="else">
                <aura:iteration items="{!v.accounts}" var="acct">
                    <lightning:tile label="{!acct.Name}">
                        <dl class="slds-list_horizontal slds-wrap">
                            <dt class="slds-item_label">Type:</dt>
                            <dd class="slds-item_detail">{!acct.Type}</dd>
                        </dl>
                    </lightning:tile>
                </aura:iteration>
            </aura:set>
        </aura:if>
    </lightning:card>
</aura:component>
```

---

## Event Handling

### Component Events (Parent-Child)

```xml
<!-- AccountSelectedEvent.evt -->
<aura:event type="COMPONENT" description="Fired when an account is selected">
    <aura:attribute name="accountId" type="String" />
</aura:event>
```

```javascript
// Child controller — firing
handleAccountClick: function(component, event, helper) {
    var compEvent = component.getEvent("accountSelected");
    compEvent.setParams({ accountId: event.currentTarget.dataset.accountId });
    compEvent.fire();
}
```

```xml
<!-- Parent — handling -->
<c:AccountTile onaccountSelected="{!c.handleAccountSelected}" />
```

### Application Events (Cross-Component)

```xml
<aura:event type="APPLICATION" description="Broadcast notification">
    <aura:attribute name="message" type="String" />
</aura:event>
```

```javascript
// Firing
var appEvent = $A.get("e.c:GlobalNotificationEvent");
appEvent.setParams({ message: "Record saved" });
appEvent.fire();
```

```xml
<!-- Any component can handle -->
<aura:handler event="c:GlobalNotificationEvent" action="{!c.handleNotification}" />
```

Prefer component events over application events. For new cross-component communication, use Lightning Message Service instead.

---

## Controller and Helper Patterns

Keep controllers thin; helpers do the work.

```javascript
// AccountManagerController.js
({
    doInit: function(component, event, helper) {
        helper.loadAccounts(component);
    },
    handleSearch: function(component, event, helper) {
        helper.loadAccounts(component);
    }
})
```

```javascript
// AccountManagerHelper.js
({
    loadAccounts: function(component) {
        component.set("v.isLoading", true);
        var action = component.get("c.getAccounts");
        action.setParams({
            searchTerm: component.get("v.searchTerm") || ""
        });
        action.setCallback(this, function(response) {
            var state = response.getState();
            if (state === "SUCCESS") {
                component.set("v.accounts", response.getReturnValue());
            } else if (state === "ERROR") {
                this.handleErrors(component, response.getError());
            } else if (state === "INCOMPLETE") {
                component.set("v.errorMessage", "Server unreachable.");
            }
            component.set("v.isLoading", false);
        });
        $A.enqueueAction(action);
    },

    handleErrors: function(component, errors) {
        var message = "Unknown error";
        if (errors && errors[0] && errors[0].message) {
            message = errors[0].message;
        }
        component.set("v.errorMessage", message);
    }
})
```

---

## Server-Side Communication

### $A.enqueueAction() Pattern

All Apex calls in Aura go through the action queue. Always handle all three response states: `SUCCESS`, `ERROR`, `INCOMPLETE`.

### Storable Actions (Client-Side Caching)

```javascript
var action = component.get("c.getPicklistValues");
action.setStorable(); // Only valid for @AuraEnabled(cacheable=true) methods
```

The callback may fire twice — once from cache, once from the server. Never use storable actions for DML operations.

### $A.getCallback() for Async Code

Any code executing outside the Aura lifecycle (setTimeout, Promises, third-party callbacks) must be wrapped in `$A.getCallback()`:

```javascript
setTimeout($A.getCallback(function() {
    if (component.isValid()) {
        component.set("v.status", "Complete");
    }
}), 2000);
```

---

## Interoperability with LWC

### Embedding LWC Inside Aura

```xml
<!-- AuraWrapper.cmp -->
<aura:component>
    <c:lwcRecordDetail
        record-id="{!v.selectedRecordId}"
        onrecordupdate="{!c.handleRecordUpdate}" />
</aura:component>
```

**Aura → LWC** — pass data via attributes mapped to `@api` properties on the LWC.
**LWC → Aura** — LWC dispatches a `CustomEvent`; Aura receives via `on{eventname}` handler and accesses detail via `event.getParam("detail")`.

---

## Cross-Skill Integration

| Need | Delegate to | Reason |
|---|---|---|
| New component development | [generating-lwc-components](../generating-lwc-components/SKILL.md) | LWC is the modern standard |
| Aura → LWC migration strategy and mappings | [generating-lwc-components](../generating-lwc-components/SKILL.md) | see `## Migrating from Aura` |
| Apex `@AuraEnabled` controller | [generating-apex](../generating-apex/SKILL.md) | server-side logic |
| Deploy Aura bundle | [deploying-metadata](../deploying-metadata/SKILL.md) | metadata deployment |
| Security review | [checking-security-constraints](../checking-security-constraints/SKILL.md) | Locker Service, XSS guardrails |
