"""Unit tests for the statistics in analysis/experiment/analyze_experiment.py.

These tests need no BigQuery access: the data loaders are never called.
"""

import numpy as np
import pytest

from analyze_experiment import aa_check, cuped, decide, srm_check, two_proportion_test, wilson


# ---------------------------------------------------------------- Wilson interval
def test_wilson_matches_checkout_baseline():
    # checkout_conversion_7d baseline in docs/metrics.md: 4,046 / 9,232, CI 42.82%-44.84%
    low, high = wilson(4046, 9232)
    assert (round(low, 4), round(high, 4)) == (0.4282, 0.4484)


# ---------------------------------------------------------------- Newcombe interval
def test_newcombe_hybrid_score_interval():
    # Newcombe (1998), example: 56/70 vs 48/80, difference 0.2000, CI 0.0524 to 0.3339
    r = two_proportion_test(x_c=48, n_c=80, x_t=56, n_t=70)
    assert round(r["diff"], 4) == 0.2000
    assert (round(r["ci_low"], 4), round(r["ci_high"], 4)) == (0.0524, 0.3339)


# ---------------------------------------------------------------- SRM
def test_srm_passes_for_balanced_split():
    assert srm_check(2977, 2985)["passed"] is True


def test_srm_fails_for_ten_percent_loss():
    result = srm_check(2981, 2683)
    assert result["passed"] is False
    assert result["p_value"] < 0.001


# ---------------------------------------------------------------- CUPED
@pytest.fixture
def outcome():
    rng = np.random.default_rng(1)
    n = 20_000
    y = rng.binomial(1, 0.46, n).astype(float)
    is_treat = rng.random(n) < 0.5
    return rng, y, is_treat


def test_cuped_independent_covariate_gives_no_variance_reduction(outcome):
    rng, y, is_treat = outcome
    x = rng.poisson(1.6, len(y)).astype(float)
    result = cuped(y, x, is_treat)
    assert abs(result["variance_reduction"]) < 0.01


def test_cuped_correlated_covariate_reduces_variance(outcome):
    rng, y, is_treat = outcome
    x = 3 * y + rng.normal(0, 1, len(y))
    result = cuped(y, x, is_treat)
    assert result["variance_reduction"] > 0.5
    assert result["variance_reduction"] == pytest.approx(result["rho2"], abs=0.02)


# ---------------------------------------------------------------- decision rule (plan v1.2 §8)
SRM_OK = {"passed": True}
SRM_FAIL = {"passed": False}
AOV_OK = {"ci_low": -0.02, "ci_high": 0.04}           # lower bound above -5%
AOV_INCONCLUSIVE = {"ci_low": -0.11, "ci_high": 0.05}  # CI spans -5%
AOV_HARM = {"ci_low": -0.15, "ci_high": -0.07}        # upper bound below -5%


def test_decide_srm_fails_is_invalid():
    assert decide(SRM_FAIL, 0.02, 0.07, AOV_OK).startswith("INVALID")


def test_decide_primary_positive_and_aov_non_inferior_is_launch():
    assert decide(SRM_OK, 0.02, 0.07, AOV_OK) == "LAUNCH"


def test_decide_primary_ci_includes_zero_is_no_launch():
    assert decide(SRM_OK, -0.01, 0.05, AOV_OK).startswith("NO LAUNCH: no evidence")


def test_decide_primary_negative_is_harm():
    assert decide(SRM_OK, -0.07, -0.01, AOV_OK) == "NO LAUNCH: the change does harm"


def test_decide_aov_below_margin_is_harm():
    assert decide(SRM_OK, 0.02, 0.07, AOV_HARM) == "NO LAUNCH: the change does harm"


def test_decide_primary_positive_aov_inconclusive_is_no_launch_yet():
    assert decide(SRM_OK, 0.02, 0.07, AOV_INCONCLUSIVE).startswith("NO LAUNCH YET")


# ---------------------------------------------------------------- A/A check
def test_aa_check_false_positive_rate_near_alpha():
    rng = np.random.default_rng(7)
    y = rng.binomial(1, 0.46, 5962).astype(float)
    result = aa_check(y)
    assert result["within_2se"] is True
    assert result["n_sims"] == 1000
