"""Pre-registered analysis of the checkout experiment (docs/experiment_plan.md, v1.2, section 7).

All treatment assignment and treatment effects in the input tables are SYNTHETIC/SIMULATED.

Usage:
    python analysis/experiment/analyze_experiment.py --scenario s1
    python analysis/experiment/analyze_experiment.py --scenario s2
    python analysis/experiment/analyze_experiment.py --scenario s0   # A/A check on real outcomes
"""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path

import numpy as np
import pandas as pd
from scipy.stats import chisquare, norm

PROJECT = os.environ.get("GCP_PROJECT", "a4-funnel-experiment")
DATASET = "funnel_dev"
ALPHA = 0.05
SRM_THRESHOLD = 0.001
AOV_MARGIN = -0.05          # non-inferiority margin, relative
RHO2_MIN = 0.01             # below this, the raw estimate decides (plan section 7.3)
N_BOOT = 10_000
N_AA = 1_000
SEED = 20201116
OUTPUT_DIR = Path("analysis/experiment/output")

TABLES = {"s1": "synthetic_exp__s1", "s2": "synthetic_exp__s2"}


# ---------------------------------------------------------------- data
def load_scenario(table: str) -> pd.DataFrame:
    from google.cloud import bigquery  # imported here so the statistics can be tested offline

    client = bigquery.Client(project=PROJECT)
    sql = f"""
        SELECT user_pseudo_id, variant, pre_sessions_14d,
               CAST(purchased_7d AS INT64) AS purchased_7d,
               revenue_7d, n_orders_7d
        FROM `{PROJECT}.{DATASET}.{table}`
    """
    return client.query(sql).to_dataframe()


def load_population() -> pd.DataFrame:
    from google.cloud import bigquery

    client = bigquery.Client(project=PROJECT)
    sql = f"""
        SELECT user_pseudo_id, CAST(purchased_7d AS INT64) AS purchased_7d
        FROM `{PROJECT}.{DATASET}.int_exp__enrolled_users`
    """
    return client.query(sql).to_dataframe()


# ---------------------------------------------------------------- statistics
def srm_check(n_control: int, n_treatment: int) -> dict:
    """Chi-square goodness of fit against a 50/50 split."""
    stat, p = chisquare([n_control, n_treatment])
    return {"n_control": n_control, "n_treatment": n_treatment,
            "chi2": float(stat), "p_value": float(p), "passed": bool(p >= SRM_THRESHOLD)}


def wilson(x: int, n: int, alpha: float = ALPHA) -> tuple[float, float]:
    z = norm.ppf(1 - alpha / 2)
    p = x / n
    centre = (p + z**2 / (2 * n)) / (1 + z**2 / n)
    half = z * np.sqrt(p * (1 - p) / n + z**2 / (4 * n**2)) / (1 + z**2 / n)
    return centre - half, centre + half


def two_proportion_test(x_c: int, n_c: int, x_t: int, n_t: int) -> dict:
    """Pooled z-test plus Newcombe hybrid score CI for p_t - p_c."""
    p_c, p_t = x_c / n_c, x_t / n_t
    p_pool = (x_c + x_t) / (n_c + n_t)
    se_pool = np.sqrt(p_pool * (1 - p_pool) * (1 / n_c + 1 / n_t))
    z = (p_t - p_c) / se_pool
    p_value = 2 * (1 - norm.cdf(abs(z)))

    l_t, u_t = wilson(x_t, n_t)
    l_c, u_c = wilson(x_c, n_c)
    d = p_t - p_c
    lower = d - np.sqrt((p_t - l_t) ** 2 + (u_c - p_c) ** 2)
    upper = d + np.sqrt((u_t - p_t) ** 2 + (p_c - l_c) ** 2)
    return {"p_control": p_c, "p_treatment": p_t, "diff": d, "rel_lift": d / p_c,
            "ci_low": float(lower), "ci_high": float(upper), "z": float(z), "p_value": float(p_value)}


def cuped(y: np.ndarray, x: np.ndarray, is_treat: np.ndarray) -> dict:
    """CUPED-adjusted difference in means with a Wald CI (plan section 7.3)."""
    theta = np.cov(y, x, ddof=1)[0, 1] / np.var(x, ddof=1)
    rho2 = np.corrcoef(y, x)[0, 1] ** 2
    y_cv = y - theta * (x - x.mean())
    yt, yc = y_cv[is_treat], y_cv[~is_treat]
    diff = yt.mean() - yc.mean()
    se = np.sqrt(yt.var(ddof=1) / len(yt) + yc.var(ddof=1) / len(yc))
    z = norm.ppf(1 - ALPHA / 2)
    p_value = 2 * (1 - norm.cdf(abs(diff / se)))
    se_raw = np.sqrt(y[is_treat].var(ddof=1) / is_treat.sum() + y[~is_treat].var(ddof=1) / (~is_treat).sum())
    return {"theta": float(theta), "rho2": float(rho2), "diff": float(diff),
            "ci_low": float(diff - z * se), "ci_high": float(diff + z * se), "p_value": float(p_value),
            "variance_reduction": float(1 - (se / se_raw) ** 2)}


def aov_bootstrap(rev_c, ord_c, rev_t, ord_t, n_boot: int = N_BOOT, seed: int = SEED) -> dict:
    """Relative AOV difference (treatment / control - 1) with a percentile bootstrap CI.

    Users are resampled within each group (cluster bootstrap), because orders from the
    same user are not independent.
    """
    rng = np.random.default_rng(seed)
    aov_c, aov_t = rev_c.sum() / ord_c.sum(), rev_t.sum() / ord_t.sum()
    rel = np.empty(n_boot)
    chunk = 500
    for start in range(0, n_boot, chunk):
        k = min(chunk, n_boot - start)
        ic = rng.integers(0, len(rev_c), size=(k, len(rev_c)))
        it = rng.integers(0, len(rev_t), size=(k, len(rev_t)))
        rel[start:start + k] = (rev_t[it].sum(1) / ord_t[it].sum(1)) / (rev_c[ic].sum(1) / ord_c[ic].sum(1)) - 1
    lo, hi = np.percentile(rel, [100 * ALPHA / 2, 100 * (1 - ALPHA / 2)])
    return {"aov_control": float(aov_c), "aov_treatment": float(aov_t),
            "rel_diff": float(aov_t / aov_c - 1), "ci_low": float(lo), "ci_high": float(hi)}


def decide(srm: dict, primary_low: float, primary_high: float, aov: dict) -> str:
    """Decision rule from plan section 8."""
    if not srm["passed"]:
        return "INVALID: SRM failed, fix assignment and rerun"
    if primary_high < 0 or aov["ci_high"] < AOV_MARGIN:
        return "NO LAUNCH: the change does harm"
    if primary_low > 0 and aov["ci_low"] > AOV_MARGIN:
        return "LAUNCH"
    if primary_low > 0:
        return "NO LAUNCH YET: primary positive, AOV inconclusive"
    return "NO LAUNCH: no evidence of an effect of at least the MDE"


# ---------------------------------------------------------------- scenarios
def analyse(df: pd.DataFrame) -> dict:
    is_treat = (df["variant"] == "treatment").to_numpy()
    y = df["purchased_7d"].to_numpy(dtype=float)
    x = df["pre_sessions_14d"].to_numpy(dtype=float)
    rev = df["revenue_7d"].fillna(0).to_numpy(dtype=float)
    orders = df["n_orders_7d"].fillna(0).to_numpy(dtype=float)

    srm = srm_check(int((~is_treat).sum()), int(is_treat.sum()))
    raw = two_proportion_test(int(y[~is_treat].sum()), int((~is_treat).sum()),
                              int(y[is_treat].sum()), int(is_treat.sum()))
    cv = cuped(y, x, is_treat)
    use_cuped = cv["rho2"] >= RHO2_MIN
    low, high = (cv["ci_low"], cv["ci_high"]) if use_cuped else (raw["ci_low"], raw["ci_high"])
    aov = aov_bootstrap(rev[~is_treat], orders[~is_treat], rev[is_treat], orders[is_treat])
    return {"label": "SYNTHETIC/SIMULATED", "srm": srm, "primary_raw": raw, "primary_cuped": cv,
            "decision_estimate": "cuped" if use_cuped else "raw",
            "aov_guardrail": aov, "decision": decide(srm, low, high, aov)}


def aa_check(y: np.ndarray, n_sims: int = N_AA, seed: int = SEED) -> dict:
    """Random 50/50 splits of real outcomes (no effect). About 5% should be significant."""
    rng = np.random.default_rng(seed)
    p_values = np.empty(n_sims)
    for i in range(n_sims):
        is_treat = rng.random(len(y)) < 0.5
        r = two_proportion_test(int(y[~is_treat].sum()), int((~is_treat).sum()),
                                int(y[is_treat].sum()), int(is_treat.sum()))
        p_values[i] = r["p_value"]
    rate = float(np.mean(p_values < ALPHA))
    se = np.sqrt(ALPHA * (1 - ALPHA) / n_sims)
    return {"label": "SYNTHETIC/SIMULATED splits of real outcomes", "n_sims": n_sims,
            "false_positive_rate": rate, "expected": ALPHA,
            "within_2se": bool(abs(rate - ALPHA) <= 2 * se)}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--scenario", choices=["s0", "s1", "s2"], required=True)
    args = parser.parse_args()

    if args.scenario == "s0":
        pop = load_population()
        result = aa_check(pop["purchased_7d"].to_numpy(dtype=float))
    else:
        result = analyse(load_scenario(TABLES[args.scenario]))

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    out = OUTPUT_DIR / f"synthetic_results_{args.scenario}.json"
    out.write_text(json.dumps(result, indent=2))
    print(json.dumps(result, indent=2))
    print(f"\nSaved to {out}")


if __name__ == "__main__":
    main()
