# LWC Debugging

## Enable Lightning Debug Mode

Lightning components are minified in production mode — error messages are cryptic and stack traces point to bundle offsets rather than source lines.

**To enable debug mode:**
1. Setup → Session Settings
2. Enable **Enable Debug Mode for Lightning Components**
3. Save — the change takes effect on next page load (no deploy needed)

Note: debug mode increases page load time noticeably. Disable it in production and re-enable only during active debugging sessions.

---

## Browser Developer Tools

### Console Logging

```javascript
import { LightningElement, wire } from 'lwc';

export default class AccountCard extends LightningElement {
    connectedCallback() {
        console.group('AccountCard mounted');
        console.log('accountId:', this.accountId);
        console.groupEnd();
    }

    handleError(error) {
        console.error('AccountCard error:', JSON.stringify(error));
    }
}
```

### Wire Adapter Errors

Wire results expose both `data` and `error`. Always handle both:

```javascript
@wire(getAccount, { recordId: '$recordId' })
wiredAccount({ data, error }) {
    if (data) {
        this.account = data;
    } else if (error) {
        console.error('Wire error:', JSON.stringify(error));
    }
}
```

`error` from a wire adapter is an object with `body.message` and `statusCode` — `JSON.stringify` it before logging or the console will show `[object Object]`.

### Inspecting LWC Shadow DOM

Chrome and Firefox DevTools can pierce the synthetic shadow:
1. Open DevTools → Elements tab
2. Locate the `<c-your-component>` element
3. Expand the shadow root — LWC uses synthetic shadow so child elements are accessible

---

## Salesforce Inspector Reloaded (Chrome Extension)

Install from the Chrome Web Store. Provides:
- **Metadata API browser** — explore sObjects, fields, and picklist values without Setup
- **Direct record access** — jump to any record by ID
- **API Inspector** — capture and replay REST API calls
- **SOQL query runner** — inline SOQL with field autocomplete

Useful for verifying that record data the LWC is requesting actually exists and has the expected values before assuming a wire or rendering bug.

---

## Common LWC Issues

| Symptom | Root Cause | Fix |
|---|---|---|
| Component renders but shows no data | Wire adapter returns `undefined` on first render | Guard with `get hasData() { return !!this.account; }` and `if:true={hasData}` in template |
| `Cannot read property 'X' of undefined` in console | Accessing deeply nested property before data is loaded | Optional chaining: `this.account?.contacts?.length` |
| Changes in JS not reflected after deploy | Browser cache serving old bundle | Hard refresh (Cmd+Shift+R / Ctrl+Shift+R) or open DevTools → Network → Disable cache |
| Event not received by parent | Event not composed or bubbling set incorrectly | For cross-shadow communication: `new CustomEvent('name', { bubbles: true, composed: true })` |
| `@track` not triggering re-render on nested object | Primitive assignment missed | Assign a new object reference: `this.obj = { ...this.obj, field: value }` |

---

## LWC Jest Tests vs Browser Debugging

Jest tests mock wire adapters and DOM APIs — they don't catch issues that only appear in a real org (CSRF tokens, CSP headers, session expiry). If a Jest test passes but the component fails in org, debug in the browser rather than the test suite.
