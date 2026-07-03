# Callout Debugging

## Enabling Callout Logging

Set `Callout` log level to `FINE` when creating a trace flag. In Developer Console:
1. Debug → Change Log Levels
2. Set **Callout** to `FINE`

Via CLI:
```bash
# List trace flags to find the relevant one
sf data query \
    --query "SELECT Id, LogType, ExpirationDate, DebugLevel.CalloutLogLevel FROM TraceFlag" \
    --target-org myOrg

# Update an existing debug level to add FINE callout logging
sf data update record \
    --sobject DebugLevel \
    --record-id <DebugLevelId> \
    --values "CalloutLogLevel=FINE" \
    --target-org myOrg
```

---

## Reading Callout Events in a Log

With `CALLOUT: FINE` enabled:

```
CALLOUT_REQUEST|[12]|System.HttpRequest[Endpoint=https://api.example.com/orders, Method=POST]
CALLOUT_RESPONSE|[12]|System.HttpResponse[Status=OK, StatusCode=200]
```

The log shows the endpoint, method, status code, and (at FINEST) the full request/response body.

---

## Instrumenting Callouts in Code

When you need structured logging of request/response for debugging a specific service:

```apex
public class DebugCalloutService {
    public static HttpResponse send(HttpRequest req) {
        System.debug(LoggingLevel.INFO,
            'CALLOUT REQUEST: ' + req.getMethod() + ' ' + req.getEndpoint());
        System.debug(LoggingLevel.FINE, 'REQUEST BODY: ' + req.getBody());

        Http http = new Http();
        HttpResponse res = http.send(req);

        System.debug(LoggingLevel.INFO,
            'CALLOUT RESPONSE: ' + res.getStatusCode() + ' ' + res.getStatus());
        System.debug(LoggingLevel.FINE, 'RESPONSE BODY: ' + res.getBody());
        return res;
    }
}
```

Route existing service callouts through this wrapper temporarily — revert before deploying to production.

---

## Common Callout Errors

| Error | Root Cause | Fix |
|---|---|---|
| `Callout from triggers are not supported` | Synchronous callout in trigger context | Move callout to `@future(callout=true)`, Queueable, or Platform Event handler |
| `Read timed out` | External system too slow or network issue | Increase `req.setTimeout(ms)` (max 120,000 ms); add retry logic via Queueable |
| `Unauthorized endpoint` | Named Credential not configured or Remote Site not whitelisted | Add to Remote Site Settings or configure a Named Credential for the endpoint |
| `System.CalloutException: Exceeded max size limit` | Response body > 12 MB | Stream via chunked requests; contact external API owner for pagination |
| Response body is empty | Endpoint returns 204 or body is stripped by a CSP rule | Check `res.getStatusCode()` — 204 No Content is not an error |

---

## Mocking Callouts in Tests

Tests must mock callouts — real HTTP calls are blocked in test context.

```apex
// Implement HttpCalloutMock
public class OrderApiMock implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest req) {
        HttpResponse res = new HttpResponse();
        res.setStatusCode(200);
        res.setBody('{"orderId":"123","status":"OK"}');
        res.setHeader('Content-Type', 'application/json');
        return res;
    }
}

// In test method:
Test.setMock(HttpCalloutMock.class, new OrderApiMock());
```

If a callout behaves differently in org vs tests, the mock is likely returning a different payload than the real API — log the actual response body in a sandbox and update the mock accordingly.
