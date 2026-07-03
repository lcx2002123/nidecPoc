# VS Code Apex Debugger

## Apex Replay Debugger (Free — all editions)

Available with the Salesforce Extension Pack. Replays a captured debug log locally — no live org connection needed during step-through.

### Steps

1. Capture a debug log:
   ```bash
   sf apex run \
       --file scripts/apex/repro.apex \
       --target-org myOrg > debug-output.log
   # or stream and save:
   sf apex tail log --target-org myOrg | tee debug-output.log
   ```
2. Open the `.log` file in VS Code.
3. Command Palette → **SFDX: Launch Apex Replay Debugger with Current File**
4. Set breakpoints in `.cls` files (click the gutter).
5. Step through execution; inspect variables and call stack in the Debug panel.

### Tips

- Set breakpoints **before** launching — the replayer cannot pause on lines that were not in the captured log.
- If the log is truncated (> 20 MB), reduce debug levels and re-capture a narrower transaction.
- Use `System.debug(LoggingLevel.ERROR, ...)` for values you always want visible at `FINEST` or lower log levels.

---

## Interactive Apex Debugger (Paid)

Requires **Performance / Unlimited Edition** or an Enterprise Edition add-on. Not available in Developer Edition or scratch orgs on trial.

### Setup: launch.json

```json
// .vscode/launch.json
{
    "version": "0.2.0",
    "configurations": [
        {
            "name": "Launch Apex Debugger",
            "type": "apex",
            "request": "launch",
            "userIdFilter": [],
            "requestTypeFilter": [],
            "entryPointFilter": "",
            "salesforceProject": "${workspaceRoot}"
        }
    ]
}
```

### Debugging Steps

1. Set breakpoints in `.cls` files.
2. **Run > Start Debugging (F5)** with the "Launch Apex Debugger" configuration selected.
3. Reproduce the action in the Salesforce UI (or via API).
4. VS Code pauses at the breakpoint — inspect variables, call stack, and heap.
5. Step Over (F10), Step Into (F11), Continue (F5).

### Limitations

| Constraint | Value |
|---|---|
| Max concurrent debug sessions | 2 per org |
| Request timeout | 30 seconds of idle |
| Supported transaction types | Synchronous Apex only (no `@future`, no Batch in `execute`) |
