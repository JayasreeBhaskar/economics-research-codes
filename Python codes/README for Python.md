# Two-Stage LLM Classification of Open-Ended Survey Text

A small, self-contained pipeline that turns free-text household survey
responses (e.g. "describe the biggest setback your farm faced this year")
into structured shock categories usable in a regression.

## Approach

- **Stage 1 — extraction:** identify the discrete shock(s) described in each
  response, in general terms.
- **Stage 2 — classification:** map each extracted shock onto a fixed
  taxonomy (drought, flood, pest/livestock disease, price shock, health
  shock, asset loss, other).

This two-stage extract-then-classify structure is a common pattern for
converting unstructured survey or administrative text into an analysis-ready
categorical variable.

## Running it

No API key needed — runs on canned outputs for review:
```
python classify_shocks.py --input data/sample_responses.csv --dry-run
```

With a live Anthropic API key:
```
export ANTHROPIC_API_KEY=your_key_here
pip install anthropic
python classify_shocks.py --input data/sample_responses.csv --model claude-sonnet-4-6
```

## Output

A long-format CSV (`household_id`, `shock_description`, `shock_category`)
that merges cleanly onto a household panel by `household_id`.
