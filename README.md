# ga4-funnel-experiment

A funnel analysis and pre-registered checkout experiment built on real GA4 e-commerce events with BigQuery, dbt and Python.

> **SYNTHETIC/SIMULATED — experiment part.** The user behaviour comes from real (obfuscated) GA4 events. The dataset contains **no A/B test**. The experiment's assignment and treatment effect are simulated. They live only in `synthetic_` tables (`synthetic_exp__assignment`, `synthetic_exp__s1`, `synthetic_exp__s2`) and `synthetic_` output files (`analysis/experiment/output/synthetic_*.json`). The experiment results demonstrate the method. They are not evidence that a simplified checkout works.

## Business question

Where do buyers drop out of the purchase funnel, and how would we test a simplified checkout so that the launch decision is credible?

## Key findings

1. **Much of the apparent checkout drop-off is most likely carts built in earlier sessions.** 5,156 of 11,106 sessions with a `begin_checkout` have no `add_to_cart` in the same session. A session-level funnel therefore overstates drop-off, so the primary KPI is measured per user.
2. **Baseline: 43.83% of users who begin checkout purchase within 7 days** (95% CI 42.82–44.84%, n = 9,232). The weekly rate rises over the period, from 29% to 58% (2020-W45 to 2021-W03). The cause is not established (season, traffic mix or obfuscation); the mix of new and returning users does not explain it.
3. **Simulated experiment (S1): conversion +4.54 pp** (CUPED, 95% CI +2.06 to +7.03; true simulated effect: +4.0 pp). The pre-registered decision is **NO LAUNCH YET**, because the AOV guardrail is inconclusive.
4. **The AOV guardrail was underpowered.** With about 1,600 orders per arm, its CI is roughly ±8%, so it cannot show non-inferiority against −5% even when the true AOV effect is zero. It would need about 5× the sample: roughly 30 weeks at test-period traffic, about 40 weeks at the 12-week average.
5. **The SRM check has low power at this scale.** Dropping 3.35% of treatment users (S2) still passed (p = 0.23). At about 2,980 users per arm and p < 0.001, only losses of about 8–9% or more are detected.

## Approach

```
raw GA4 export → staging → intermediate → marts → analysis
```

| Layer | What it does |
|-------|--------------|
| Raw | `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`, read only through a dbt source filtered on `_TABLE_SUFFIX` (2020-11-01 to 2021-01-31). |
| Staging | `stg_ga4__events`: one row per event, with event params unnested, a session key and typed dates, clustered by event name and date. |
| Intermediate | Session funnel with ordered step flags (`int_ga4__session_funnel`), the user-level checkout baseline (`int_ga4__user_checkout`) and the experiment population (`int_exp__enrolled_users`). |
| Marts | SIMULATED assignment and scenarios on top of the real population (`synthetic_exp__assignment`, `synthetic_exp__s1`, `synthetic_exp__s2`). |
| Analysis | Exploration queries (`analysis/exploration/`), power and MDE (`analysis/power/`), and the pre-registered experiment analysis (`analysis/experiment/`). |

Every KPI is defined in `docs/metrics.md` and every modelling choice is logged in `docs/decisions.md`. The experiment plan (`docs/experiment_plan.md`) was committed before any simulated treatment data existed (v1.0 `dd65d43`, amended to v1.2 `3126238`).

## Results (SYNTHETIC/SIMULATED, scenario S1)

| Check | Result | Verdict |
|---|---|---|
| Sample ratio (SRM) | 2,977 vs 2,985, p = 0.92 | ✅ Pass |
| Conversion levels (raw) | 46.2% → 50.8% | |
| **Conversion (CUPED, decision estimate)** | **+4.54 pp** (95% CI +2.06 to +7.03), p = 0.0003 | ✅ Positive |
| Conversion (raw) | +4.63 pp (95% CI +2.10 to +7.16), relative lift +10.0% | ✅ Consistent |
| **AOV guardrail** | $71.40 → $68.87: **−3.5%** (95% CI −11.1% to +4.7%) | ⚠️ Inconclusive |
| Revenue per enrolled user (follow-up, plan §8) | $37.01 → $38.81: +4.9% (95% CI −5.2% to +16.1%) | ⚠️ Inconclusive |

**Decision: NO LAUNCH YET.** See `docs/launch_memo.md` for the options and the recommendation.

## How to run

**Prerequisites:** Python 3.12, [Google Cloud CLI](https://cloud.google.com/sdk/docs/install) and a GCP project with BigQuery (the free BigQuery Sandbox is enough).

Create and activate a virtual environment:

```bash
# Windows (cmd)
py -3.12 -m venv .venv
.venv\Scripts\activate
```

```powershell
# Windows (PowerShell)
py -3.12 -m venv .venv
.venv\Scripts\Activate.ps1
```

```bash
# macOS / Linux
python3.12 -m venv .venv
source .venv/bin/activate
```

Install the pinned dependencies and authenticate:

```bash
pip install -r requirements-lock.txt
gcloud auth application-default login
gcloud auth application-default set-quota-project <your-gcp-project-id>
```

`requirements-lock.txt` pins every package, including transitive dependencies. `requirements.txt` holds only the direct dependencies.

Create `~/.dbt/profiles.yml` outside the repo. It uses OAuth through gcloud, so it contains no secrets:

```yaml
ga4_funnel_experiment:
  target: dev
  outputs:
    dev:
      type: bigquery
      method: oauth
      project: <your-gcp-project-id>
      dataset: funnel_dev
      location: US
      threads: 4
      maximum_bytes_billed: 10737418240   # 10 GiB cap per query
```

Build and test all models (about 3 GiB scanned per full build):

```bash
dbt debug
dbt build
```

Run the analysis scripts from the repository root, in this order. They read the `funnel_dev` dataset in the project given by the environment variable `GCP_PROJECT` (default: `a4-funnel-experiment`):

```bash
export GCP_PROJECT=<your-gcp-project-id>        # macOS / Linux
$env:GCP_PROJECT = "<your-gcp-project-id>"      # Windows PowerShell
set GCP_PROJECT=<your-gcp-project-id>           # Windows cmd
```

```bash
python analysis/power/power_mde.py
python analysis/experiment/analyze_experiment.py --scenario s0
python analysis/experiment/analyze_experiment.py --scenario s1
python analysis/experiment/analyze_experiment.py --scenario s2
python analysis/experiment/rpu_followup.py --scenario s1
```

Sandbox tables expire after 60 days. Everything is rebuildable with `dbt build`.

Unit tests for the statistics (no BigQuery access needed):

```bash
pytest python_tests
```

CI (`.github/workflows/ci.yml`) runs these tests and `dbt parse` against a dummy profile on every push and pull request.

## Repository structure

```
models/
  staging/          stg_ga4__events, source definition
  intermediate/     session funnel, user checkout baseline, experiment population
  marts/            synthetic_exp__* (SIMULATED assignment and scenarios)
tests/generic/      custom generic tests (funnel monotonicity, row counts, ranges, ...)
macros/             wilson_bound
analysis/
  exploration/      01–08: event counts, checks, funnel, baseline, trend, transactions
  power/            power_mde.py
  experiment/       analyze_experiment.py, rpu_followup.py, output/synthetic_*.json
python_tests/       pytest unit tests for the experiment statistics
.github/workflows/  CI: unit tests and dbt parse
docs/
  metrics.md        KPI definitions
  decisions.md      decision log
  experiment_plan.md  pre-registered plan (v1.2)
  launch_memo.md    decision memo (SIMULATED results)
```

## Limitations

- The treatment effect is simulated. The real effect of a shorter checkout form is unknown.
- The test window covers Black Friday and the run-up to Christmas, when the weekly baseline rose from about 38% to about 59%. Randomisation protects the comparison, but the effect may not generalise to other seasons.
- `user_pseudo_id` is a cookie or device identifier, so one person can appear in both groups.
- The data is obfuscated. 15.9% of purchase events lack a valid `transaction_id`, which affects AOV but not conversion.

## Data source

Google's public BigQuery dataset [`bigquery-public-data.ga4_obfuscated_sample_ecommerce`](https://developers.google.com/analytics/bigquery/web-ecommerce-demo-dataset): an obfuscated GA4 export from the Google Merchandise Store, about 2020-11-01 to 2021-01-31. Some values are redacted or obfuscated.

## License

The code in this repository is released under the MIT License (see `LICENSE`). The data is not part of this repository and is not covered by that license. The dataset is provided by Google and is subject to Google's terms for the dataset.
