# Experiment plan: simplified checkout (pre-registered)

| | |
|---|---|
| Status | Pre-registered. v1.0 was committed in `e63eea0`. v1.1 corrects errors found in review before any treatment data was generated or analysed (see §11). The commit hash of each version serves as its registration timestamp. |
| Version | 1.1 (2026-11-10) |
| Data | Real GA4 events from the Google Merchandise Store (obfuscated sample). **Treatment assignment and treatment effect are SYNTHETIC/SIMULATED.** The dataset contains no real experiment. |

## 1. Background
Fewer than half of users who begin checkout purchase within 7 days (`checkout_conversion_7d` = 43.83%, 95% CI 42.82–44.84%, n = 9,232, Nov 2020–Jan 2021). The largest loss inside checkout is between `begin_checkout` and `add_payment_info`: only 59% of users who start checkout reach the payment step. (`add_shipping_info` fires for almost exactly the same users as `begin_checkout`, so the data shows no separate shipping drop-off.) The proposed (hypothetical) change replaces the multi-field shipping and payment form with a single, shorter form, using address autofill and fewer required fields.

## 2. Hypothesis
- **H0:** The simplified checkout does not change `exp_checkout_conversion_7d`.
- **H1:** The simplified checkout changes `exp_checkout_conversion_7d` (two-sided test).
- **Expected direction:** an increase, because a shorter form with fewer required fields gives users fewer reasons to abandon.

## 3. Design
| Item | Decision |
|---|---|
| Randomisation unit | User (`user_pseudo_id`) |
| Trigger (enrolment) | A user's first `begin_checkout` inside the experiment window. Users who never reach checkout are not enrolled, because they never see the change. |
| Assignment | Deterministic hash of `user_pseudo_id` with a fixed salt. 50% control / 50% treatment. A user stays in the same group for the whole test. |
| Experiment window | 6 full ISO weeks: 2020-11-16 to 2020-12-27 (W47–W52, UTC) |
| Outcome window | 7 days after the trigger. The last outcome ends no later than 2021-01-03, so every enrolled user has a full window. |
| Pre-period (for CUPED) | 14 days before each user's trigger. The window starts on 2020-11-16, so every user has 14 days of history inside the data. |

## 4. Metrics
**Primary**
- `exp_checkout_conversion_7d` = users with at least one `purchase` in [trigger, trigger + 7 days) / enrolled users. The trigger is the first `begin_checkout` inside the experiment window. This population is not the same as the one behind the descriptive `checkout_conversion_7d` in `docs/metrics.md`, where the anchor is the first checkout since 2020-11-01.

**Secondary (exploratory, no decision power)**
- `payment_step_rate_7d` = users with `add_payment_info` within 7 days / enrolled users.
- Conversion by `device_category`.

**Guardrails**
- **Average order value (AOV)** = revenue / number of distinct valid `transaction_id`. Rows where `transaction_id` is NULL or `(not set)` are excluded, and duplicates are removed by `transaction_id`. Non-inferiority margin: −5% relative.
- **Sample ratio mismatch (SRM):** the split between groups must be consistent with 50/50.

## 5. Sample size and power
Calculated in `analysis/power/power_mde.py`: two-sided test of two proportions, α = 0.05, power = 0.80, p0 = 0.4383.

| Item | Value |
|---|---|
| p0 for the experiment population | 46.31% (2,761 / 5,962 users enrolled under this plan's trigger, W47–W52) |
| Enrolled users | 5,962 → ~2,981 per arm |
| Planned MDE | **3.63 pp absolute (7.8% relative)** |
| Reference (v1.0 assumption) | 760 users/week and p0 = 43.83% → 2,280 per arm, MDE 4.13 pp (9.4% relative) |
| Sensitivity | MDE depends strongly on p0, which ranged from 29% to 60% by week (see `docs/decisions.md`) |

The achieved MDE will be reported after the test.

## 6. Synthetic treatment (simulation spec)
All of the following is SIMULATED and is labelled as such in every table and chart.

| Scenario | True effect | Purpose |
|---|---|---|
| **S1 – main** | +4.0 pp absolute on `exp_checkout_conversion_7d` | Demonstrates the full analysis. Expected power is ~0.87 at n = 2,981 per arm and p0 = 46.31%. |
| **S0 – A/A** | 0 pp | Checks the false positive rate. Over 1,000 simulated A/A splits, about 5% should be significant. |
| **S2 – SRM** | +4.0 pp, plus 3% of treatment users dropped | Checks that the SRM check catches broken assignment |

**How the effect is generated:** for treatment users who did not purchase, a simulated purchase is added with probability q = 0.04 / (1 − p_ctrl), where p_ctrl is the observed control conversion (≈ 0.075 if p_ctrl = 0.463). The purchase is timed within their outcome window. Its revenue is drawn from the empirical distribution of valid real orders, so the true effect on AOV is zero. Generation uses a fixed random seed. Outputs are stored in tables prefixed `synthetic_`.

## 7. Analysis plan
1. **SRM check first:** a chi-square goodness-of-fit test against 50/50. If p < 0.001, the test is invalid and no effect is reported.
2. **Primary test:** a pooled two-proportion z-test on `exp_checkout_conversion_7d`. Report the absolute difference with a 95% CI (Newcombe hybrid score interval) and the relative lift.
3. **CUPED:** Y = purchase (0/1). The covariate X = number of distinct sessions in [trigger − 14 days, trigger), counted from all events. This requires a new column; the existing `n_sessions_before_checkout` has no 14-day limit and is not used. θ = cov(Y, X) / var(X), estimated on both groups pooled. The adjusted outcome is Y_cv = Y − θ(X − mean(X)). The effect is mean(Y_cv, treatment) − mean(Y_cv, control), with a 95% Wald CI using SE = √(s²_t / n_t + s²_c / n_c) computed on Y_cv. Report the raw estimate, the CUPED estimate and the variance reduction (ρ²). The decision uses the CUPED estimate and its Wald CI. If ρ² < 0.01, the decision uses the raw estimate and the Newcombe CI.
4. **Guardrail:** relative difference in AOV with a 95% bootstrap CI (10,000 resamples of orders).
5. **No peeking:** fixed horizon, with a single analysis after all outcome windows have closed.
6. **Segments:** reported as exploratory only. No decisions are based on subgroup results.

## 8. Decision rule
| Outcome | Decision |
|---|---|
| SRM fails | **Invalid:** fix the assignment and rerun. No conclusion is drawn. |
| Primary CI lower bound > 0 **and** AOV CI lower bound > −5% | **Launch** |
| Primary CI includes 0 | **No launch.** No evidence of an effect ≥ MDE. Consider iterating on the design rather than running a longer test. |
| Primary CI upper bound < 0, or AOV CI upper bound < −5% | **No launch:** the change does harm |
| Primary positive, AOV inconclusive (CI spans −5%) | **No launch yet.** Review revenue per enrolled user and decide with stakeholders. |

## 9. Stopping rules
- No early stopping for success.
- The test is stopped early only for an SRM failure in a daily check (p < 0.001) or for a technical failure in checkout. Neither can occur in this simulation; the rule is included because a real test needs it.

## 10. Threats to validity and limitations
- **Synthetic effect:** the result demonstrates the method. It is not evidence that a simplified checkout works.
- **Seasonality:** the window covers Black Friday and the run-up to Christmas. The weekly baseline rises from about 38% (W47) to about 59% (W52). Randomisation protects the comparison, but the effect may not generalise to other seasons.
- **Identity:** `user_pseudo_id` is a cookie or device identifier. One person on two devices can land in both groups (contamination, which biases the effect towards zero).
- **Obfuscated data:** some values are redacted, and 15.9% of purchase events lack a valid `transaction_id`. This affects AOV but not conversion.
- **Time zone:** all boundaries are in UTC, not the store's local time.
- **Traffic attribution:** `traffic_source` and `traffic_medium` describe the user's first visit, not the session.

## 11. Change log
| Version | Commit | Change |
|---|---|---|
| 1.0 | `e63eea0` | First registration |
| 1.1 | this commit | Corrections found in review, before any treatment data existed: (1) the primary metric is renamed `exp_checkout_conversion_7d`, and p0 is set for the plan's own population (46.31% instead of 43.83%); (2) enrolled n is 5,962 instead of ~5,850, so the MDE is 3.63 pp and S1 power is 0.87; (3) the background no longer claims a separate shipping step; (4) the CUPED covariate is defined exactly as a new 14-day column; (5) the CI method for the CUPED estimate is specified. |
