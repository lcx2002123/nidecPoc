# Flow Debugging

## Flow Builder Debug Mode

1. Setup → Flows → open the Flow in Flow Builder.
2. Click the **Debug** button (top-right toolbar).
3. Set input variables (e.g., record ID for record-triggered flows).
4. Optionally set **Run as** to a specific user to reproduce a permission issue.
5. Check **Rollback** to undo DML changes automatically after the debug run.
6. Click **Run**.
7. Step through each element — green = succeeded, red = fault path taken.
8. Expand any element to inspect input/output variable values at that point.

### Rollback checkbox

Use **Rollback** when diagnosing logic errors so test data is not committed. Disable it only when you need to confirm that DML actually persists (e.g., debugging a fault that only appears after commit).

---

## Reading Flow Debug Output

Each element shows:
- **Input values** — what entered the element
- **Output values** — what the element produced
- **Fault message** — shown in red when the element threw an error

For Decision elements, the branch taken is highlighted. Check the `Outcome` field to see which condition matched.

---

## Common Flow Errors

| Error | Root Cause | Fix |
|---|---|---|
| "An unhandled fault has occurred in the flow" | An element threw an error with no fault connector wired | Add fault paths on every Get Records, Update Records, Create Records, Delete Records, and callout element |
| Flow SOQL 101 limit exceeded | Get Records element inside a loop | Move Get Records outside the loop; use Collection Filtering or Collection Sort to process results inside the loop |
| "This flow can't access the variable" | Variable not marked as available for input/output | Open the variable definition, enable **Available for input** and/or **Available for output** |
| Flow fires but produces no visible result | Flow is inactive or the entry criteria doesn't match | Check **Activation** status and verify trigger object + entry conditions |
| Record-triggered flow runs on wrong records | Filter conditions misconfigured | Use **Debug** and pass a specific record ID; inspect which conditions evaluate to true/false |
| Subflow "The flow could not be started" | API name mismatch or subflow input variable type mismatch | Verify the subflow API name and that all required input variables are mapped |

---

## Checking Flow Fault Emails

When a running flow faults without a fault connector, Salesforce emails the running user and the admin. Check:
- Setup → Email Log Files (if email not received)
- Setup → Paused and Failed Flow Interviews (for screen flows and scheduled flows)

---

## Debugging Scheduled / Autolaunched Flows

Scheduled flows cannot be stepped through in debug mode. Workarounds:
1. Convert to a Screen Flow temporarily with a Debug button.
2. Add `{!$Flow.InterviewGuid}` to an output variable and log it via a Create Records element to a custom debug object.
3. Use `System.debug` in any called Apex actions and read the resulting debug log via SF CLI.
