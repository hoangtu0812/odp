#!/usr/bin/env python3
"""Create deterministic Maximo-shaped work-order fixtures for LDL."""

from __future__ import annotations

import argparse
import json
import random
from datetime import datetime, timedelta, timezone
from pathlib import Path

SITES = ("DQ", "NS", "VT")
AREAS = ("A", "B", "C", "D")
STATUSES = ("COMP", "INPRG", "WAPPR", "APPR", "CLOSE", "CAN")
BASE = datetime(2026, 1, 1, tzinfo=timezone.utc)


def timestamp(days: int, hours: int) -> str:
    return (BASE + timedelta(days=days, hours=hours)).isoformat().replace("+00:00", "Z")


def generate(workorders: int, seed: int) -> list[dict]:
    rng = random.Random(seed)
    records = []
    for number in range(1, workorders + 1):
        status = STATUSES[(number * 11 + seed) % len(STATUSES)]
        reported_day = (number * 7) % 365
        target_day = reported_day + 1 + number % 10
        completed = status in {"COMP", "CLOSE"}
        records.append({
            "wonum": f"WO-{number:06d}", "description": f"Preventive maintenance task {number:06d}",
            "status": status, "siteid": SITES[(number - 1) % len(SITES)],
            "location": AREAS[(number - 1) % len(AREAS)], "assetnum": f"ASSET-{(number * 13) % 750 + 1:04d}",
            "lead": f"DEPT-{(number * 5) % 24 + 1:02d}", "reportdate": timestamp(reported_day, number % 24),
            "targcompdate": timestamp(target_day, 17), "actfinish": timestamp(target_day - (number % 3), 14) if completed else None,
            "esttotalcost": round(500_000 + rng.random() * 49_500_000, 2), "changedate": timestamp(reported_day + number % 14, (number * 3) % 24),
        })
    return records


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--workorders", type=int, default=10_000)
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--output", type=Path, default=Path(__file__).parent / "generated" / "workorders.json")
    args = parser.parse_args()
    if args.workorders < 1:
        parser.error("--workorders must be positive")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps({"member": generate(args.workorders, args.seed)}, ensure_ascii=False), encoding="utf-8")
    print(f"Generated {args.workorders} deterministic Maximo work orders in {args.output}")


if __name__ == "__main__":
    main()
