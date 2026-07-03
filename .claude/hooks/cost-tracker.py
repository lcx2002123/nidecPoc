#!/usr/bin/env python3
"""
Stop hook: reads exact token usage from transcript, displays per-turn cost
and running session total in the terminal after each Claude response.

Pricing (claude-sonnet-4-6): input $3/MTok, cache-write $3.75/MTok,
cache-read $0.30/MTok, output $15/MTok.
"""
import json
import os
import sys

PRICES = {
    "claude-sonnet-4-6":          {"in": 3.00,  "cw": 3.75,  "cr": 0.30, "out": 15.00},
    "claude-opus-4-8":            {"in": 15.00, "cw": 18.75, "cr": 1.50, "out": 75.00},
    "claude-haiku-4-5-20251001":  {"in": 0.80,  "cw": 1.00,  "cr": 0.08, "out": 4.00},
    "claude-fable-5":             {"in": 3.00,  "cw": 3.75,  "cr": 0.30, "out": 15.00},
}

def get_price(model: str) -> dict:
    for key, p in PRICES.items():
        if key in (model or ""):
            return p
    return PRICES["claude-sonnet-4-6"]

def cost_from_usage(usage: dict, model: str) -> float:
    p = get_price(model)
    return (
        usage.get("input_tokens", 0)                 * p["in"] +
        usage.get("cache_creation_input_tokens", 0)  * p["cw"] +
        usage.get("cache_read_input_tokens", 0)      * p["cr"] +
        usage.get("output_tokens", 0)                * p["out"]
    ) / 1_000_000

def parse_transcript(path: str) -> list[tuple[str, dict]]:
    """Return list of (model, usage_dict) for every assistant message."""
    entries = []
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                obj = json.loads(line)
            except json.JSONDecodeError:
                continue
            if obj.get("type") != "assistant":
                continue
            msg = obj.get("message", {})
            usage = msg.get("usage")
            if not usage:
                continue
            model = msg.get("model", "claude-sonnet-4-6")
            entries.append((model, usage))
    return entries

def load_state(path: str) -> dict:
    if os.path.exists(path):
        try:
            with open(path) as f:
                return json.load(f)
        except Exception:
            pass
    return {"seen": 0, "turns": []}

def save_state(path: str, state: dict) -> None:
    try:
        with open(path, "w") as f:
            json.dump(state, f)
    except Exception:
        pass

def fmt_tok(n: int) -> str:
    return f"{n:,}"

def write_to_terminal(text: str) -> None:
    try:
        with open("/dev/tty", "w") as tty:
            tty.write(text)
    except Exception:
        sys.stderr.write(text)

def main() -> None:
    try:
        data = json.load(sys.stdin)
    except Exception:
        sys.exit(0)

    transcript_path = data.get("transcript_path", "")
    session_id = (data.get("session_id") or "unknown")[:16]

    if not transcript_path or not os.path.exists(transcript_path):
        sys.exit(0)

    entries = parse_transcript(transcript_path)
    if not entries:
        sys.exit(0)

    state_path = f"/tmp/cc-cost-{session_id}.json"
    state = load_state(state_path)
    seen = state.get("seen", 0)
    new_entries = entries[seen:]

    if not new_entries:
        sys.exit(0)

    # Aggregate all API calls that belong to this user turn
    turn_in = turn_cw = turn_cr = turn_out = 0
    turn_cost = 0.0
    last_model = new_entries[-1][0]

    for model, usage in new_entries:
        turn_in  += usage.get("input_tokens", 0)
        turn_cw  += usage.get("cache_creation_input_tokens", 0)
        turn_cr  += usage.get("cache_read_input_tokens", 0)
        turn_out += usage.get("output_tokens", 0)
        turn_cost += cost_from_usage(usage, model)

    state["seen"] = len(entries)
    state.setdefault("turns", []).append({
        "in": turn_in, "cw": turn_cw, "cr": turn_cr,
        "out": turn_out, "cost": turn_cost,
    })
    session_cost = sum(t["cost"] for t in state["turns"])
    turn_num = len(state["turns"])
    save_state(state_path, state)

    # Format display
    in_billed = turn_in + turn_cw  # cache reads billed separately and cheaply
    cache_note = f" (↩ {fmt_tok(turn_cr)} cached)" if turn_cr > 0 else ""

    W = 52
    bar = "─" * W
    line1 = (
        f"  turn {turn_num}"
        f"  in {fmt_tok(in_billed)}{cache_note}"
        f"  out {fmt_tok(turn_out)}"
        f"  ${turn_cost:.4f}"
    )
    line2 = (
        f"  session ${session_cost:.4f}"
        f"  ·  {turn_num} turn{'s' if turn_num != 1 else ''}"
        f"  ·  {last_model.split('-')[1] if '-' in last_model else last_model}"
    )

    output = f"\n{bar}\n{line1}\n{line2}\n{bar}\n"
    write_to_terminal(output)
    sys.exit(0)

if __name__ == "__main__":
    main()
