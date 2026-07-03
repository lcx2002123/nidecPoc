---
name: debugging-salesforce
description: "Multi-domain Salesforce debugging how-to: VS Code Apex Debugger setup, Flow debug mode, LWC browser debugging, Developer Console / SOQL Query Plan, and callout inspection. TRIGGER when: user asks how to debug a Flow/LWC, set up VS Code debugger, use Developer Console, or inspect callout payloads. DO NOT TRIGGER when: actual log file needs analysis (use debugging-apex-logs), generating or fixing Apex code (use generating-apex), or running Apex tests (use running-apex-tests)."
origin: SCC
user-invocable: false
---

# debugging-salesforce: Salesforce Debugging How-To

Use this skill when the user needs **guidance on how to use debugging tools**: setting up VS Code debuggers, running Flow debug mode, inspecting LWC errors in the browser, querying the SOQL explain plan, or capturing callout payloads.

This skill covers **tool setup and technique**. For deep log-file analysis (governor limits, stack traces, CPU/heap profiling) delegate to `debugging-apex-logs`.

---

## When This Skill Owns the Task

| Trigger | Tool / Reference |
|---|---|
| "How do I debug my Flow?" | [flow-debugging.md](references/flow-debugging.md) |
| "My LWC isn't rendering data" | [lwc-debugging.md](references/lwc-debugging.md) |
| "Set up VS Code Apex Debugger" | [vscode-debugger.md](references/vscode-debugger.md) |
| "How do I use Developer Console / checkpoints?" | [developer-console.md](references/developer-console.md) |
| "Check the SOQL query plan" | [developer-console.md](references/developer-console.md) |
| "Inspect callout request/response" | [callout-debugging.md](references/callout-debugging.md) |
| "What causes SOQL-in-loop / NullPointer / MIXED_DML?" | [common-errors.md](references/common-errors.md) |

---

## When to Delegate Instead

| Need | Delegate to | Reason |
|---|---|---|
| Analyze an actual `.log` file | [debugging-apex-logs](../debugging-apex-logs/SKILL.md) | Deep log parsing, scoring, governor-limit root cause |
| Implement the Apex fix | [generating-apex](../generating-apex/SKILL.md) | Code generation / review |
| Run or fix Apex tests | [running-apex-tests](../running-apex-tests/SKILL.md) | Test execution loop |
| Deploy after fixing | [deploying-metadata](../deploying-metadata/SKILL.md) | Deployment orchestration |

---

## Reference File Index

| File | When to read |
|------|-------------|
| `references/vscode-debugger.md` | VS Code Apex Replay Debugger and Interactive Debugger setup |
| `references/flow-debugging.md` | Flow Builder debug mode and common Flow errors |
| `references/lwc-debugging.md` | Browser DevTools, Lightning Debug Mode, Chrome extensions |
| `references/developer-console.md` | Developer Console, SOQL Query Plan, heap checkpoints |
| `references/callout-debugging.md` | Capturing and inspecting callout request/response payloads |
| `references/common-errors.md` | Quick lookup: SOQL-in-loop, CPU limit, NullPointer, MIXED_DML, etc. |
