---
name: optimize
description: "Optimize a draft prompt for token efficiency. TRIGGER when the user invokes /optimize or passes a prompt to optimize. Show estimated token count, provide 2-3 leaner alternatives with before/after comparison. Do NOT trigger for general refactoring or code optimization — only for optimizing Claude prompts."
---

# optimize: Prompt Token Optimizer

When this skill is invoked, help the user reduce token cost for their prompt by estimating current size and suggesting more concise alternatives.

## Input

The user invokes `/optimize` with their draft prompt, either:
- Inline: `/optimize "Apexクラスのロジックを全部解説してテストも書いて"`
- Or interactively: `/optimize` with no argument → ask "Paste the prompt to optimize:"

If no prompt is provided, ask for it once and wait.

## Token Estimation Formula

Use this to estimate tokens for any text:

```
english_words  = number of whitespace-separated tokens in non-CJK text
cjk_chars      = count of characters in ranges: CJK Unified (U+4E00–U+9FFF),
                 Hiragana/Katakana (U+3040–U+30FF), Hangul (U+AC00–U+D7AF)
estimated_tokens = round(english_words * 1.3 + cjk_chars * 1.2)
```

For tool-use context (file reads, SOQL results, etc.), add a rough multiplier of 2–5× the prompt itself. Mention this overhead when relevant.

## Session Multiplier Effect

In a multi-turn session, the full conversation history is re-sent as input each turn.
A 100-token reduction in a prompt that runs for 10 turns saves ~1,000 input tokens total.
Mention this when the session is clearly long or iterative.

## Output Format

Always respond in this exact structure:

```
original  (N tok):  "<the original prompt>"

  ✦ option 1  (M tok, −X%):
    "<rewritten version — preserve the intent, cut filler>"

  ✦ option 2  (P tok, −Y%):
    "<more aggressive cut — compress to bare essentials>"

  ✦ option 3  (Q tok, −Z%):  [only if clearly distinct from option 2]
    "<structural change — e.g. switch from prose to bullet keywords>"

─────────────────────────────────────────
  Savings:  option 1 saves ~N tok/turn · ~NNN tok over a 10-turn session
```

## Rewriting Principles

1. **Drop courtesy phrasing** — "教えてください", "お願いします", "can you please" add tokens, not intent.
2. **Replace prose with directives** — "〇〇の部分について詳しく説明してほしい" → "Explain: <thing>"
3. **Name the target explicitly** — "this code" → "MyController.cls" when a filename is obvious from context.
4. **Specify output format up-front** — "list" / "table" / "bullet" / "one-line" saves Claude from choosing and outputting a verbose default.
5. **Cut scope if it's overloaded** — if the prompt asks Claude to do 4 things at once, note that splitting into 2 prompts is often cheaper and more accurate.
6. **Keep language** — if the user wrote in Japanese, keep option 1 in Japanese; option 2 can switch to English if that's genuinely shorter.

## Pricing Reference (claude-sonnet-4-6)

- Input: $3.00 / MTok
- Cache read: $0.30 / MTok (≈10× cheaper if context is cached)
- Output: $15.00 / MTok

Show dollar amounts only when the savings exceed ~$0.001/turn (i.e., the delta is > ~70 tokens). Below that, just show the percentage reduction.

## Example

User: `/optimize "Apexクラス MyController のロジックを全部詳しく解説してください。また、それに対するApexテストクラスも書いてもらえますか？"`

Response:
```
original  (38 tok):  "Apexクラス MyController のロジックを全部詳しく解説してください。また、それに対するApexテストクラスも書いてもらえますか？"

  ✦ option 1  (22 tok, −42%):
    "MyController.cls のロジック解説 + Apex テスト作成"

  ✦ option 2  (14 tok, −63%):
    "Explain MyController logic + write Apex test"

  ✦ option 3  (9 tok, −76%):
    "MyController: explain + test skeleton"

──────────────────────────────────────────
  Savings: option 1 saves ~16 tok/turn · ~160 tok over a 10-turn session ($0.00048)
  Note: at this size, the output token cost dominates — consider constraining output
        with "bullet list only" or "max 200 words" to reduce output cost more.
```
