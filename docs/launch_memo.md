# Launch memo: simplified checkout

> **SYNTHETIC/SIMULATED.** The user behaviour is real GA4 data from the Google Merchandise Store (obfuscated sample, Nov 2020–Jan 2021). The treatment assignment and the treatment effect are simulated. This memo demonstrates the decision process; it is not evidence that a simplified checkout works.

**Decision (pre-registered rule, plan v1.2 §8): NO LAUNCH YET.** The primary metric improved clearly, but the revenue guardrail cannot rule out harm.

**Recommendation to stakeholders:** launch to 90% of users and keep a 10% holdout. Track revenue per user against an RPU margin to be pre-registered before the 90% rollout. This is a business judgment on top of the rule, not the rule's outcome. See §5.

---

## 1. Question
Fewer than half of users who start checkout complete a purchase within 7 days. Would a shorter checkout form (one form, address autofill, fewer required fields) raise that share without lowering order value?

## 2. Test
| | |
|---|---|
| Design | User-level 50/50 randomisation at the first `begin_checkout`, over 6 full weeks (16 Nov – 27 Dec 2020) |
| Users | 5,962 (2,977 control / 2,985 treatment) |
| Primary metric | `exp_checkout_conversion_7d`: share of enrolled users who purchase within 7 days of the trigger |
| Guardrail | Average order value (AOV), with a non-inferiority margin of −5% |
| Pre-registration | Plan v1.0 `dd65d43`, amended to v1.2 `3126238` before any treatment data existed |

## 3. Results
| Check | Result | Verdict |
|---|---|---|
| Sample ratio (SRM) | 2,977 vs 2,985, p = 0.92 | ✅ Pass |
| Conversion levels (raw) | 46.2% → 50.8% | |
| **Conversion (CUPED, decision estimate)** | **+4.54 pp** (95% CI +2.06 to +7.03), p = 0.0003 | ✅ Positive |
| Conversion (raw) | +4.63 pp (95% CI +2.10 to +7.16), relative lift +10.0% | ✅ Consistent |
| **AOV guardrail** | $71.40 → $68.87: **−3.5%** (95% CI −11.1% to +4.7%) | ⚠️ Inconclusive |
| Revenue per enrolled user (follow-up, §8) | $37.01 → $38.81: +4.9% (95% CI −5.2% to +16.1%) | ⚠️ Inconclusive |

The CUPED covariate was sessions in the 14 days before the trigger. It reduced variance by 4.1%, which matches ρ² = 0.041.

## 4. What we learned
1. **The method recovers the effect.** The simulated true effect was +4.0 pp, about +4.4 pp as realised in this sample. The CI contains both values. An A/A check on real outcomes (1,000 random splits) gave a 4.9% false-positive rate against the expected 5%.
2. **The guardrail was underpowered, and this is a design flaw in the plan.** With about 1,600 orders per arm, the AOV CI is roughly ±8%. It cannot show non-inferiority against −5% even when the true AOV effect is zero, which it is by construction in this simulation. Showing non-inferiority with 80% power would need about 5× the sample: roughly 30 weeks at test-period traffic (~994 users/week), about 40 weeks at the 12-week average (760/week).
3. **The SRM check has low power at this scale.** In scenario S2, 3.35% of treatment users were removed and the check still passed (p = 0.23). We predicted and logged this before running: at ~2,980 per arm and p < 0.001, only losses of about 8–9% or more are detected. The random loss in S2 caused no visible bias. In production, losses are rarely random, so a small SRM can hide real bias.

## 5. Options
| Option | For | Against |
|---|---|---|
| **A. Launch to 90%, keep a 10% holdout (recommended)** | Captures the conversion gain now. The holdout measures long-run revenue impact against an RPU margin to be pre-registered before the 90% rollout. | The 10% holdout misses the improvement during the measurement period |
| B. Do not launch, run a longer test | Answers the AOV question directly | Roughly 30 weeks at test-period traffic (~994 users/week), about 40 weeks at the 12-week average (760/week); the conversion gain is lost in the meantime |
| C. Launch to 100% | Simplest | Gives up the ability to detect revenue harm |

## 6. Next experiment: design fixes
- Run a power calculation for every guardrail, not only the primary metric.
- Use a less noisy revenue guardrail, such as RPU with order revenue winsorised at the 99th percentile, or a ratio metric analysed with the delta method.
- Choose a CUPED covariate with stronger pre-period signal (for example prior purchases or prior checkouts), selected on historical data before the test starts.
- For SRM, monitor daily and alert on large deviations. Make the S2 simulation more realistic by dropping users in an outcome-correlated way.

## 7. Limitations
- The treatment effect is simulated. The real effect of a shorter form is unknown.
- The test window covers Black Friday and the run-up to Christmas, when the weekly baseline rose from about 38% to about 59%. Randomisation protects the comparison, but the effect may not generalise to other seasons.
- `user_pseudo_id` is a cookie or device identifier, so one person can appear in both groups.
- The data is obfuscated. 15.9% of purchase events lack a valid `transaction_id`, which affects AOV but not conversion.

## Reproducibility
| What | Where |
|---|---|
| Plan | `docs/experiment_plan.md` |
| Decisions and deviations | `docs/decisions.md` |
| Models | `models/` (`dbt build`) |
| Analysis | `analysis/experiment/analyze_experiment.py --scenario s0/s1/s2` and `rpu_followup.py` |
| Outputs | `analysis/experiment/output/synthetic_*.json` |
