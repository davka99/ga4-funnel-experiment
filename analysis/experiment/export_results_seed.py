"""Export the SYNTHETIC/SIMULATED experiment results to a dbt seed for reporting.

Reads analysis/experiment/output/synthetic_results_s0/s1/s2.json and synthetic_rpu_s1.json
and writes seeds/synthetic_experiment_results.csv (one row per scenario and metric).
Rerun this script, then `dbt seed`, whenever the analysis scripts are rerun.

Usage:
    python analysis/experiment/export_results_seed.py
"""

from __future__ import annotations

import csv
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUTPUT_DIR = ROOT / "analysis" / "experiment" / "output"
SEED_FILE = ROOT / "seeds" / "synthetic_experiment_results.csv"
LABEL = "SYNTHETIC/SIMULATED"
AOV_MARGIN = -0.05
COLUMNS = ["scenario", "metric", "estimate", "ci_low", "ci_high", "p_value", "verdict", "data_label"]


def load(name: str) -> dict:
    return json.loads((OUTPUT_DIR / name).read_text(encoding="utf-8"))


def ci_vs_zero(low: float, high: float) -> str:
    if low > 0:
        return "positive"
    if high < 0:
        return "negative"
    return "inconclusive"


def aov_verdict(low: float, high: float) -> str:
    if low > AOV_MARGIN:
        return "non-inferior"
    if high < AOV_MARGIN:
        return "harm"
    return "inconclusive"


def row(scenario, metric, estimate=None, ci_low=None, ci_high=None, p_value=None, verdict=None) -> dict:
    return {"scenario": scenario, "metric": metric, "estimate": estimate, "ci_low": ci_low,
            "ci_high": ci_high, "p_value": p_value, "verdict": verdict, "data_label": LABEL}


def scenario_rows(scenario: str, r: dict) -> list[dict]:
    srm, raw, cv, aov = r["srm"], r["primary_raw"], r["primary_cuped"], r["aov_guardrail"]
    share_treatment = srm["n_treatment"] / (srm["n_control"] + srm["n_treatment"])
    return [
        row(scenario, "srm_share_treatment", share_treatment, p_value=srm["p_value"],
            verdict="PASS" if srm["passed"] else "FAIL"),
        row(scenario, "conversion_diff_raw", raw["diff"], raw["ci_low"], raw["ci_high"], raw["p_value"],
            ci_vs_zero(raw["ci_low"], raw["ci_high"])),
        row(scenario, "conversion_diff_cuped", cv["diff"], cv["ci_low"], cv["ci_high"], cv["p_value"],
            ci_vs_zero(cv["ci_low"], cv["ci_high"])),
        row(scenario, "aov_rel_diff", aov["rel_diff"], aov["ci_low"], aov["ci_high"],
            verdict=aov_verdict(aov["ci_low"], aov["ci_high"])),
        row(scenario, "decision", verdict=r["decision"]),
    ]


def main() -> None:
    s0 = load("synthetic_results_s0.json")
    rpu = load("synthetic_rpu_s1.json")["rpu"]

    rows = [row("s0", "aa_false_positive_rate", s0["false_positive_rate"],
                verdict="PASS" if s0["within_2se"] else "FAIL")]
    rows += scenario_rows("s1", load("synthetic_results_s1.json"))
    rows += scenario_rows("s2", load("synthetic_results_s2.json"))
    rows.append(row("s1", "rpu_rel_diff", rpu["rel_diff"], rpu["ci_low"], rpu["ci_high"],
                    verdict=ci_vs_zero(rpu["ci_low"], rpu["ci_high"])))

    SEED_FILE.parent.mkdir(parents=True, exist_ok=True)
    with SEED_FILE.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=COLUMNS)
        writer.writeheader()
        writer.writerows(rows)
    print(f"Wrote {len(rows)} rows to {SEED_FILE.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
