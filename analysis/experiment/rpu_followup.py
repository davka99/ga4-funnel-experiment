"""Follow-up from plan section 8: revenue per enrolled user (RPU).

The plan says that when the primary metric is positive but the AOV guardrail is
inconclusive, RPU is reviewed and the decision is made with stakeholders. RPU is
input to that discussion. It is not a decision metric and does not change the
pre-registered decision.

All treatment assignment and treatment effects are SYNTHETIC/SIMULATED.

Usage:
    python analysis/experiment/rpu_followup.py --scenario s1
"""

from __future__ import annotations

import argparse
import json

import numpy as np

from analyze_experiment import ALPHA, N_BOOT, OUTPUT_DIR, SEED, TABLES, load_scenario


def rpu_bootstrap(rev_c: np.ndarray, rev_t: np.ndarray, n_boot: int = N_BOOT, seed: int = SEED) -> dict:
    """Relative difference in revenue per enrolled user, with a percentile bootstrap CI over users."""
    rng = np.random.default_rng(seed)
    rpu_c, rpu_t = rev_c.mean(), rev_t.mean()
    rel = np.empty(n_boot)
    chunk = 500
    for start in range(0, n_boot, chunk):
        k = min(chunk, n_boot - start)
        ic = rng.integers(0, len(rev_c), size=(k, len(rev_c)))
        it = rng.integers(0, len(rev_t), size=(k, len(rev_t)))
        rel[start:start + k] = rev_t[it].mean(1) / rev_c[ic].mean(1) - 1
    lo, hi = np.percentile(rel, [100 * ALPHA / 2, 100 * (1 - ALPHA / 2)])
    return {"rpu_control": float(rpu_c), "rpu_treatment": float(rpu_t),
            "rel_diff": float(rpu_t / rpu_c - 1), "ci_low": float(lo), "ci_high": float(hi)}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--scenario", choices=["s1", "s2"], default="s1")
    args = parser.parse_args()

    df = load_scenario(TABLES[args.scenario])
    is_treat = (df["variant"] == "treatment").to_numpy()
    rev = df["revenue_7d"].fillna(0).to_numpy(dtype=float)
    orders = df["n_orders_7d"].fillna(0).to_numpy(dtype=float)
    buyers = df["purchased_7d"].to_numpy(dtype=float)

    result = {
        "label": "SYNTHETIC/SIMULATED - follow-up, not a decision metric",
        "rpu": rpu_bootstrap(rev[~is_treat], rev[is_treat]),
        "orders_per_buyer": {
            "control": float(orders[~is_treat].sum() / buyers[~is_treat].sum()),
            "treatment": float(orders[is_treat].sum() / buyers[is_treat].sum()),
        },
    }
    out = OUTPUT_DIR / f"synthetic_rpu_{args.scenario}.json"
    out.write_text(json.dumps(result, indent=2))
    print(json.dumps(result, indent=2))
    print(f"\nSaved to {out}")


if __name__ == "__main__":
    main()
