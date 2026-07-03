<!-- Parent: building-sf-integrations/SKILL.md -->
# Platform Events Guide

## Overview

Platform Events enable event-driven architecture in Salesforce. They provide a scalable, asynchronous messaging system for real-time integrations.

## Event Types

### Standard Volume

- Up to ~2,000 events per hour
- Included in all Salesforce editions
- Standard delivery guarantees

### High Volume

- Millions of events per day
- At-least-once delivery
- 24-hour retention for replay
- May require additional entitlement

## When to Use Platform Events

| Scenario | Platform Events | Other Options |
|----------|-----------------|---------------|
| Real-time notifications | ✅ Best choice | - |
| Decoupled integrations | ✅ Best choice | - |
| High-volume streaming | ✅ High Volume | Change Data Capture |
| Simple record sync | Consider | Change Data Capture |
| External system notifications | ✅ Best choice | - |
| Internal process triggers | ✅ Good choice | Process Builder, Flow |

## Creating Platform Events

### Via Metadata (Recommended)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<CustomObject xmlns="http://soap.sforce.com/2006/04/metadata">
    <deploymentStatus>Deployed</deploymentStatus>
    <eventType>HighVolume</eventType>
    <label>Order Update Event</label>
    <pluralLabel>Order Update Events</pluralLabel>
    <publishBehavior>PublishAfterCommit</publishBehavior>
    <fields>
        <fullName>Order_Id__c</fullName>
        <label>Order ID</label>
        <type>Text</type>
        <length>18</length>
    </fields>
    <fields>
        <fullName>Status__c</fullName>
        <label>Status</label>
        <type>Text</type>
        <length>50</length>
    </fields>
</CustomObject>
```

### File Location

```
force-app/main/default/objects/Order_Update_Event__e/Order_Update_Event__e.object-meta.xml
```

## Publishing Events

### From Apex

```apex
// Single event
Order_Update_Event__e event = new Order_Update_Event__e();
event.Order_Id__c = orderId;
event.Status__c = 'Shipped';

Database.SaveResult result = EventBus.publish(event);
if (result.isSuccess()) {
    System.debug('Event published: ' + result.getId());
}

// Multiple events
List<Order_Update_Event__e> events = new List<Order_Update_Event__e>();
// ... populate events
List<Database.SaveResult> results = EventBus.publish(events);
```

### From Flow

1. Create Record element
2. Select Platform Event object
3. Map field values

### From Process Builder

1. Add Immediate Action
2. Select "Create a Record"
3. Choose Platform Event

## Subscribing to Events

### Apex Trigger

```apex
trigger OrderUpdateSubscriber on Order_Update_Event__e (after insert) {
    for (Order_Update_Event__e event : Trigger.new) {
        System.debug('Order ' + event.Order_Id__c + ' is now ' + event.Status__c);
        // Process event
    }

    // Set checkpoint for durability
    EventBus.TriggerContext.currentContext().setResumeCheckpoint(
        Trigger.new[Trigger.new.size() - 1].ReplayId
    );
}
```

### Flow (Record-Triggered)

1. Create Platform Event-Triggered Flow
2. Select Platform Event object
3. Build logic with event data

### External (CometD)

External systems can subscribe using CometD streaming:

```
/event/Order_Update_Event__e
```

## Publish Behavior

### PublishAfterCommit (Default)

- Event published after transaction commits
- If transaction rolls back, event NOT published
- **Recommended for most cases**

### PublishImmediately

- Event published immediately
- Event still published even if transaction rolls back
- Use when external system must be notified regardless of outcome

## Durability & Replay

### Replay ID

Each event has a unique `ReplayId` for tracking and replay:

```apex
String replayId = event.ReplayId;
```

### Resume Checkpoint

Set checkpoint to ensure durability:

```apex
// In trigger
EventBus.TriggerContext.currentContext().setResumeCheckpoint(lastReplayId);
```

If trigger fails after checkpoint, processing resumes from that point.

### Retention

- High Volume events: 24 hours
- Standard Volume: 24 hours

## Best Practices

### Publishing

1. **Batch events** when publishing multiple
2. **Check SaveResults** for publish failures
3. **Use meaningful correlation IDs** for tracking
4. **Include timestamp** for ordering
5. **Keep payloads small** - use IDs, not full records

### Subscribing

1. **Always set resume checkpoint** in triggers
2. **Don't throw exceptions** - catch and log errors
3. **Process idempotently** - events may replay
4. **Keep processing lightweight** - queue heavy work
5. **Handle duplicates** using correlation ID

### Design

1. **Event granularity** - not too fine, not too coarse
2. **Include enough context** but not entire records
3. **Version your events** if schema evolves
4. **Document event contracts** for consumers

## Error Handling

### Publish Errors

```apex
List<Database.SaveResult> results = EventBus.publish(events);
for (Integer i = 0; i < results.size(); i++) {
    if (!results[i].isSuccess()) {
        for (Database.Error err : results[i].getErrors()) {
            System.debug('Publish failed: ' + err.getMessage());
        }
    }
}
```

### Subscriber Errors

```apex
trigger MySubscriber on My_Event__e (after insert) {
    for (My_Event__e event : Trigger.new) {
        try {
            processEvent(event);
        } catch (Exception e) {
            // Log error, don't throw
            System.debug('Error processing ' + event.ReplayId + ': ' + e.getMessage());
            // Create error log record
        }
    }

    // Still set checkpoint even if some failed
    EventBus.TriggerContext.currentContext().setResumeCheckpoint(lastReplayId);
}
```

## Monitoring

### Setup → Platform Events

- View event definitions
- Check usage metrics
- Monitor delivery status

### Event Delivery Failures

Check for:
- Unhandled exceptions in triggers
- Apex CPU timeout
- Governor limit errors

### Event Publishing

Query `EventBusSubscriber` for subscription health:

```apex
SELECT Id, Position, ExternalId, Name, Status, Tip
FROM EventBusSubscriber
WHERE Topic = 'Order_Update_Event__e'
```

## Retry and Error Handling in Subscribers

### RetryableException Pattern

Throw `EventBus.RetryableException` to signal a transient failure — the platform will retry from the last checkpoint instead of suspending the subscriber.

```apex
trigger OrderCompletedTrigger on Order_Completed__e (after insert) {
    // Bail out after platform max (9 retries for high-volume events)
    if (EventBus.TriggerContext.currentContext().retries > 9) {
        List<Error_Log__c> logs = new List<Error_Log__c>();
        for (Order_Completed__e event : Trigger.new) {
            logs.add(new Error_Log__c(
                Source__c = 'OrderCompletedTrigger',
                Message__c = 'Max retries exceeded for order: ' + event.Order_Id__c
            ));
        }
        insert logs;
        return;
    }

    try {
        // processOrder() MUST be idempotent — on retry it runs again for events
        // between the last checkpoint and the failure point.
        for (Order_Completed__e event : Trigger.new) {
            processOrder(event);
            EventBus.TriggerContext.currentContext()
                .setResumeCheckpoint(event.ReplayId);
        }
    } catch (Exception e) {
        throw new EventBus.RetryableException(
            'Transient failure, will retry: ' + e.getMessage());
    }
}
```

Key rules:
- `retries` starts at 0; high-volume events retry up to 9 times over 24 hours; standard-volume events do **not** retry automatically.
- `setResumeCheckpoint(replayId)` advances the resume point so retries skip already-processed events.
- Non-retryable (permanent) failures should be logged and `return`ed — **do not** throw `RetryableException` for them.

### Publish Callbacks

Implement `EventBus.EventPublishFailureCallback` and/or `EventBus.EventPublishSuccessCallback` to react asynchronously to enqueue outcomes:

```apex
public class OrderEventCallback
    implements EventBus.EventPublishFailureCallback,
               EventBus.EventPublishSuccessCallback {

    public void onFailure(EventBus.FailureResult result) {
        // Runs under Automated Process user
        for (String replayId : result.getReplayIds()) {
            insert new Error_Log__c(
                Source__c = 'OrderEventPublisher',
                Message__c = 'Publish failed, replayId: ' + replayId
            );
        }
    }

    public void onSuccess(EventBus.SuccessResult result) {
        System.debug('Published ' + result.getReplayIds().size() + ' events');
    }
}

// Pass callback instance as second argument
EventBus.publish(eventList, new OrderEventCallback());
```

Limits: 5 MB cumulative callback usage in the last 30 minutes; max 10 callback invocations per publish call.

---

## Limits

| Limit | Standard Volume | High Volume |
|-------|-----------------|-------------|
| Events per hour | ~2,000 | Millions |
| Retention | 24 hours | **72 hours** |
| Max event size | 1 MB | 1 MB |
| Fields per event | 100 | 100 |

> For edition-specific publishing/delivery allocations (DE vs EE vs UE), see [platform-events-limits.md](./platform-events-limits.md).

## External Integration

### Subscribe from External System

Use CometD client to connect to Streaming API:

```
Endpoint: /cometd/62.0
Channel: /event/Order_Update_Event__e
```

### Publish from External System

Use REST API:

```http
POST /services/data/v66.0/sobjects/Order_Update_Event__e
Content-Type: application/json

{
    "Order_Id__c": "001xx000003NGSFAA4",
    "Status__c": "Shipped"
}
```

---

## Subscribing in LWC via empApi

Full component that subscribes on mount, displays incoming events in a datatable, and cleans up on unmount.

```html
<!-- orderStatusMonitor.html -->
<template>
    <lightning-card title="Order Status Monitor" icon-name="standard:orders">
        <div class="slds-p-around_small">
            <template lwc:if={isSubscribed}>
                <lightning-badge label="Live" class="slds-m-bottom_small slds-theme_success"></lightning-badge>
            </template>
            <template lwc:else>
                <lightning-badge label="Disconnected" class="slds-m-bottom_small"></lightning-badge>
                <lightning-button label="Connect" onclick={handleSubscribe} variant="brand" class="slds-m-left_small"></lightning-button>
            </template>
        </div>

        <template lwc:if={hasEvents}>
            <lightning-datatable
                key-field="replayId"
                data={events}
                columns={columns}
                hide-checkbox-column>
            </lightning-datatable>
        </template>
        <template lwc:else>
            <div class="slds-p-around_medium slds-text-align_center slds-text-color_weak">
                Waiting for order status events...
            </div>
        </template>
    </lightning-card>
</template>
```

```javascript
// orderStatusMonitor.js
import { LightningElement } from 'lwc';
import { subscribe, unsubscribe, onError } from 'lightning/empApi';

const CHANNEL = '/event/Order_Status_Event__e';
const MAX_EVENTS = 50;
const COLUMNS = [
    { label: 'Order ID', fieldName: 'orderId', type: 'text' },
    { label: 'Status', fieldName: 'status', type: 'text' },
    { label: 'Message', fieldName: 'message', type: 'text' },
    { label: 'Time', fieldName: 'timestamp', type: 'text' }
];

export default class OrderStatusMonitor extends LightningElement {
    subscription = null;
    events = [];
    columns = COLUMNS;

    get isSubscribed() {
        return this.subscription != null;
    }

    get hasEvents() {
        return this.events.length > 0;
    }

    connectedCallback() {
        onError((error) => {
            console.error('empApi error: ', JSON.stringify(error));
            this.subscription = null; // allow reconnect
        });
        this.handleSubscribe();
    }

    disconnectedCallback() {
        this.handleUnsubscribe();
    }

    handleSubscribe() {
        // replayId -1 = new events only; -2 = all retained events (up to 72 h)
        subscribe(CHANNEL, -1, (response) => {
            const payload = response.data.payload;
            const evt = {
                replayId: response.data.event.replayId,
                orderId: payload.Order_Id__c,
                status: payload.Status__c,
                message: payload.Message__c,
                timestamp: new Date(payload.CreatedDate).toLocaleString()
            };
            this.events = [evt, ...this.events].slice(0, MAX_EVENTS);
        }).then((sub) => {
            this.subscription = sub;
        });
    }

    handleUnsubscribe() {
        if (this.subscription) {
            unsubscribe(this.subscription, () => {
                this.subscription = null;
            });
        }
    }
}
```

Key rules:
- Always `unsubscribe` in `disconnectedCallback()` — leaked subscriptions survive component removal.
- Register `onError` before subscribing so silent failures surface.
- Use `replayId: -1` for new-only; `-2` to replay all retained events.

---

## CDC Subscription in LWC

CDC events fire automatically on record DML — no custom event definition needed. Channel format: `/data/<ObjectName>ChangeEvent`.

```javascript
// accountChangeMonitor.js
import { LightningElement } from 'lwc';
import { subscribe, unsubscribe, onError } from 'lightning/empApi';

const CDC_CHANNEL = '/data/AccountChangeEvent';

export default class AccountChangeMonitor extends LightningElement {
    subscription = null;
    changes = [];

    connectedCallback() {
        onError((error) => {
            console.error('CDC error: ', JSON.stringify(error));
            this.subscription = null;
        });
        subscribe(CDC_CHANNEL, -1, (response) => {
            const header = response.data.payload.ChangeEventHeader;
            this.changes = [{
                id: Date.now(),
                recordIds: header.recordIds.join(', '),
                changeType: header.changeType,       // CREATE, UPDATE, DELETE, UNDELETE
                changedFields: header.changedFields.join(', '),
                commitUser: header.commitUser,
                timestamp: new Date(header.commitTimestamp).toLocaleString()
            }, ...this.changes].slice(0, 100);
        }).then((sub) => {
            this.subscription = sub;
        });
    }

    disconnectedCallback() {
        if (this.subscription) {
            unsubscribe(this.subscription, () => {
                this.subscription = null;
            });
        }
    }
}
```

Enable CDC for each object in Setup → Integrations → Change Data Capture before subscribing. See [cdc-guide.md](./cdc-guide.md) for full CDC event structure and gap handling.

---

## Testing Platform Events

Two separate test methods per event type: one for publish success, one for subscriber side effects.

```apex
@IsTest
private class OrderEventPublisher_Test {

    @IsTest
    static void testPublishSingleEvent() {
        Test.startTest();
        OrderEventPublisher.publishStatusChange(
            '801xx000000001AAA',
            'Shipped',
            'Order has been shipped'
        );
        Test.stopTest();
        // EventBus.publish() completes without exception — verified by lack of error
    }

    @IsTest
    static void testPublishBulkEvents() {
        List<Order_Status_Event__e> events = new List<Order_Status_Event__e>();
        for (Integer i = 0; i < 200; i++) {
            events.add(new Order_Status_Event__e(
                Order_Id__c = '801xx00000000' + String.valueOf(i).leftPad(4, '0'),
                Status__c = 'Processing',
                Message__c = 'Bulk event ' + i
            ));
        }

        Test.startTest();
        List<Database.SaveResult> results = EventBus.publish(events);
        Test.stopTest();

        for (Database.SaveResult result : results) {
            Assert.isTrue(result.isSuccess(), 'Bulk event publish should succeed');
        }
    }

    @IsTest
    static void testSubscriberCreatesTasksForFailedOrders() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;
        Order ord = new Order(
            AccountId = acc.Id,
            EffectiveDate = Date.today(),
            Status = 'Draft'
        );
        insert ord;

        List<Order_Status_Event__e> events = new List<Order_Status_Event__e>{
            new Order_Status_Event__e(
                Order_Id__c = ord.Id,
                Status__c = 'Failed',
                Message__c = 'Payment declined'
            ),
            new Order_Status_Event__e(
                Order_Id__c = ord.Id,
                Status__c = 'Shipped',
                Message__c = 'Shipped successfully'
            )
        };

        Test.startTest();
        OrderEventSubscriber.handleEvents(events);
        Test.stopTest();

        List<Task> tasks = [SELECT Subject, Priority, WhatId FROM Task WHERE Subject LIKE 'Order Failed%'];
        Assert.areEqual(1, tasks.size(), 'Should create task only for failed order');
        Assert.areEqual('High', tasks[0].Priority);
        Assert.areEqual(ord.Id, tasks[0].WhatId, 'Task should link to the Order');
    }
}
```

> To test the **full trigger path** (publisher → event bus → subscriber trigger), use `Test.getEventBus().deliver()` inside `Test.startTest()`/`Test.stopTest()`. See [../../generating-apex-test/references/integration-test-patterns.md](../../generating-apex-test/references/integration-test-patterns.md) for the pattern.
