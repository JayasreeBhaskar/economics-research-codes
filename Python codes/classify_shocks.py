"""
classify_shocks.py

Two-stage LLM pipeline for classifying open-ended household survey
responses into a fixed taxonomy of economic shocks.

Motivation
----------
Household surveys (e.g. LSMS-ISA) often include a free-text field asking
farmers to describe the biggest shock or setback they faced in the past
year. These responses are heterogeneous and hard to use directly in a
regression. This script mirrors a common applied-economics pattern for
turning that kind of unstructured text into structured, analysis-ready
categories:

  Stage 1 (extraction):  identify the discrete shock(s) described in each
                          response, stated in general terms rather than
                          verbatim.
  Stage 2 (classification): map each extracted shock to one category in a
                          fixed taxonomy, so shocks can be tabulated,
                          merged onto the household panel, and used as
                          regressors or fixed effects.

This is a self-contained illustrative sample: it runs in --dry-run mode
with canned model outputs (no API key required) so it can be reviewed
end-to-end, or with a real Anthropic API key for live classification.

Usage
-----
    python classify_shocks.py --input data/sample_responses.csv --dry-run
    python classify_shocks.py --input data/sample_responses.csv --output results.csv
"""

from __future__ import annotations

import argparse
import csv
import json
import os
import sys
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional

SHOCK_TAXONOMY = [
    "Drought / rainfall shortfall",
    "Flood / excess rainfall",
    "Pest or crop disease",
    "Livestock disease or loss",
    "Price shock (input or output)",
    "Health shock (illness, injury, death in household)",
    "Asset loss (theft, fire, other)",
    "Other / unclassified",
]

STAGE1_SYSTEM_PROMPT = """You are a research analyst who specializes in reading open-ended \
household survey responses and identifying the discrete shocks or setbacks described.

You describe each shock in general, anonymized terms rather than quoting the response \
verbatim. If a response describes more than one shock, list each separately. If a response \
describes no identifiable shock, return an empty list.

You always return structured JSON and nothing else, in the form:
{"shocks": ["<shock 1 description>", "<shock 2 description>", ...]}
"""

STAGE2_SYSTEM_PROMPT = f"""You are a research analyst who classifies described economic shocks \
into a fixed taxonomy for a household panel dataset.

Taxonomy (choose exactly one per shock):
{json.dumps(SHOCK_TAXONOMY, indent=2)}

You always return structured JSON and nothing else, in the form:
{{"category": "<one category from the taxonomy, copied exactly>"}}
"""


@dataclass
class ClassifiedResponse:
    household_id: str
    raw_text: str
    shocks: list[str] = field(default_factory=list)
    categories: list[str] = field(default_factory=list)


def _dry_run_stage1(text: str) -> list[str]:
    """Canned Stage 1 output for offline/demo use, keyword-triggered."""
    text_lower = text.lower()
    shocks = []
    if "rain" in text_lower or "drought" in text_lower:
        shocks.append("Insufficient rainfall affecting crop yield")
    if "flood" in text_lower:
        shocks.append("Excess rainfall damaging standing crops")
    if "price" in text_lower or "market" in text_lower:
        shocks.append("Unfavorable change in output or input prices")
    if "sick" in text_lower or "illness" in text_lower or "hospital" in text_lower:
        shocks.append("Household member illness affecting labor supply")
    if "cattle" in text_lower or "livestock" in text_lower or "animal" in text_lower:
        shocks.append("Loss of livestock")
    if not shocks:
        shocks.append("Unspecified setback")
    return shocks


def _dry_run_stage2(shock: str) -> str:
    """Canned Stage 2 output for offline/demo use, keyword-triggered."""
    s = shock.lower()
    if "rainfall affecting" in s or "drought" in s:
        return SHOCK_TAXONOMY[0]
    if "excess rainfall" in s or "flood" in s:
        return SHOCK_TAXONOMY[1]
    if "livestock" in s:
        return SHOCK_TAXONOMY[3]
    if "price" in s:
        return SHOCK_TAXONOMY[4]
    if "illness" in s:
        return SHOCK_TAXONOMY[5]
    return SHOCK_TAXONOMY[7]


def call_stage1(text: str, client, model: str, dry_run: bool) -> list[str]:
    """Extract discrete shocks from a single free-text survey response."""
    if dry_run or client is None:
        return _dry_run_stage1(text)

    response = client.messages.create(
        model=model,
        max_tokens=500,
        system=STAGE1_SYSTEM_PROMPT,
        messages=[{"role": "user", "content": text}],
    )
    payload = json.loads(response.content[0].text)
    return payload.get("shocks", [])


def call_stage2(shock: str, client, model: str, dry_run: bool) -> str:
    """Map a single extracted shock description to a taxonomy category."""
    if dry_run or client is None:
        return _dry_run_stage2(shock)

    response = client.messages.create(
        model=model,
        max_tokens=100,
        system=STAGE2_SYSTEM_PROMPT,
        messages=[{"role": "user", "content": shock}],
    )
    payload = json.loads(response.content[0].text)
    return payload.get("category", "Other / unclassified")


def classify_with_retry(fn, *args, max_retries: int = 3, **kwargs):
    """Thin retry wrapper around API calls, since network/LLM calls can fail
    transiently. Not needed in --dry-run mode."""
    last_error: Optional[Exception] = None
    for attempt in range(max_retries):
        try:
            return fn(*args, **kwargs)
        except Exception as exc:  # noqa: BLE001 - want to catch and retry broadly here
            last_error = exc
            time.sleep(1.5 * (attempt + 1))
    raise RuntimeError(f"Failed after {max_retries} attempts: {last_error}")


def run_pipeline(input_path: Path, output_path: Path, model: str, dry_run: bool) -> None:
    client = None
    if not dry_run:
        try:
            import anthropic  # imported lazily so --dry-run needs no dependency
        except ImportError:
            sys.exit(
                "The 'anthropic' package is required for live runs. "
                "Install it with `pip install anthropic`, or use --dry-run."
            )
        api_key = os.environ.get("ANTHROPIC_API_KEY")
        if not api_key:
            sys.exit("Set the ANTHROPIC_API_KEY environment variable, or use --dry-run.")
        client = anthropic.Anthropic(api_key=api_key)

    results: list[ClassifiedResponse] = []

    with open(input_path, newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            household_id = row["household_id"]
            raw_text = row["response_text"]

            shocks = classify_with_retry(call_stage1, raw_text, client, model, dry_run)
            categories = [
                classify_with_retry(call_stage2, shock, client, model, dry_run)
                for shock in shocks
            ]

            results.append(
                ClassifiedResponse(
                    household_id=household_id,
                    raw_text=raw_text,
                    shocks=shocks,
                    categories=categories,
                )
            )

    with open(output_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["household_id", "shock_description", "shock_category"])
        for r in results:
            for shock, category in zip(r.shocks, r.categories):
                writer.writerow([r.household_id, shock, category])

    print(f"Wrote {sum(len(r.shocks) for r in results)} classified shock rows to {output_path}")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, required=True, help="CSV with household_id, response_text columns")
    parser.add_argument("--output", type=Path, default=Path("classified_shocks.csv"))
    parser.add_argument("--model", type=str, default="claude-sonnet-4-6")
    parser.add_argument("--dry-run", action="store_true", help="Run with canned outputs, no API key required")
    return parser.parse_args()


if __name__ == "__main__":
    args = parse_args()
    run_pipeline(args.input, args.output, args.model, args.dry_run)

