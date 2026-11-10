"""Power and minimum detectable effect (MDE) for checkout_conversion_7d.

Two-sided test of two proportions (control vs. treatment), 50/50 split,
randomisation and analysis at user level.

Inputs come from analysis/exploration/05_checkout_baseline.sql and
06_baseline_trend_diagnostic.sql:
- baseline p0 = 0.4383 (4,046 / 9,232 users)
- weekly range of p0: roughly 0.29 to 0.60
- new users entering checkout per week: about 760 (9,141 users over the 12 full weeks W45-W03)
- experiment population (plan v1.1+): 5,962 users enrolled in W47-W52, p0 = 0.4631 (2,761 / 5,962)
"""

import numpy as np
from scipy.stats import norm

ALPHA = 0.05
POWER = 0.80
WEEKLY_USERS = 760          # users entering the experiment per week (both arms)
P0_SCENARIOS = {"low (Nov)": 0.30, "baseline": 0.4383, "high (Dec-Jan)": 0.55}


def n_per_arm(p0: float, p1: float, alpha: float = ALPHA, power: float = POWER) -> float:
    """Users per arm needed to detect p0 -> p1 (normal approximation)."""
    z_a = norm.ppf(1 - alpha / 2)
    z_b = norm.ppf(power)
    p_bar = (p0 + p1) / 2
    num = (z_a * np.sqrt(2 * p_bar * (1 - p_bar))
           + z_b * np.sqrt(p0 * (1 - p0) + p1 * (1 - p1))) ** 2
    return num / (p1 - p0) ** 2


def mde_for_n(p0: float, n: float) -> float:
    """Smallest absolute lift detectable with n users per arm (bisection)."""
    lo, hi = 1e-5, 1 - p0 - 1e-5
    for _ in range(100):
        mid = (lo + hi) / 2
        if n_per_arm(p0, p0 + mid) > n:
            lo = mid
        else:
            hi = mid
    return hi


def simulated_power(p0: float, p1: float, n: int, sims: int = 20_000, seed: int = 42) -> float:
    """Monte Carlo check of the analytic formula with a pooled two-proportion z-test."""
    rng = np.random.default_rng(seed)
    x0 = rng.binomial(n, p0, sims)
    x1 = rng.binomial(n, p1, sims)
    p_pool = (x0 + x1) / (2 * n)
    se = np.sqrt(p_pool * (1 - p_pool) * 2 / n)
    z = (x1 / n - x0 / n) / se
    return float(np.mean(np.abs(z) > norm.ppf(1 - ALPHA / 2)))


if __name__ == "__main__":
    print("A) Users per arm and weeks needed, by relative lift")
    print(f"{'p0':>16} {'lift':>6} {'abs pp':>7} {'n/arm':>8} {'weeks':>6}")
    for label, p0 in P0_SCENARIOS.items():
        for rel in (0.05, 0.10, 0.15):
            p1 = p0 * (1 + rel)
            n = n_per_arm(p0, p1)
            weeks = 2 * n / WEEKLY_USERS
            print(f"{label:>16} {rel:>6.0%} {100*(p1-p0):>7.2f} {n:>8.0f} {weeks:>6.1f}")

    print("\nB) MDE by test length (baseline p0 = 0.4383)")
    print(f"{'weeks':>6} {'n/arm':>7} {'MDE abs pp':>11} {'MDE rel':>8}")
    for weeks in (2, 4, 6, 8, 12):
        n = weeks * WEEKLY_USERS / 2
        d = mde_for_n(0.4383, n)
        print(f"{weeks:>6} {n:>7.0f} {100*d:>11.2f} {d/0.4383:>8.1%}")

    print("\nC) Simulation check (4 weeks, p0 = 0.4383, lift = analytic MDE)")
    n = int(4 * WEEKLY_USERS / 2)
    d = mde_for_n(0.4383, n)
    print(f"n/arm={n}, p1={0.4383+d:.4f}, simulated power={simulated_power(0.4383, 0.4383+d, n):.3f}")

    print("\nD) Experiment plan v1.1+ (enrolled W47-W52)")
    p0_exp, n_exp = 2761 / 5962, 5962 / 2
    d = mde_for_n(p0_exp, n_exp)
    print(f"p0={p0_exp:.4f}, n/arm={n_exp:.0f}, MDE={100*d:.2f} pp ({d/p0_exp:.1%} relative)")
    print(f"power for S1 (+4.0 pp), simulated: {simulated_power(p0_exp, p0_exp + 0.04, int(n_exp)):.3f}")
