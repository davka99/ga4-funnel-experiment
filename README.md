# ga4-funnel-experiment

**Question:** Where do buyers drop out of the purchase funnel, and how would we test a simplified checkout so that the launch decision is credible?

## Data

`bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`. This is the public, obfuscated GA4 export from the Google Merchandise Store, covering about 2020-11-01 to 2021-01-31.

**Limitations:** some values in the dataset are redacted or obfuscated. The dataset contains no A/B experiment. Any experiment assignment or effect in this repo is simulated: such tables and files use the `synthetic_` prefix and are marked as simulated wherever they appear. They are never real results.

## Synthetic data

**Every `synthetic_` table is SIMULATED.** The experiment in `docs/experiment_plan.md` has never been run. Its assignment and treatment effect are generated on top of real events:

| Model | Contents |
|-------|----------|
| `synthetic_exp__assignment` | Simulated 50/50 assignment of the enrolled users (hash of `user_pseudo_id`) |
| `synthetic_exp__s1` | Scenario S1: real outcomes plus a simulated +4.0 pp effect in treatment |
| `synthetic_exp__s2` | Scenario S2: S1 with about 3% of treatment users dropped (simulated broken assignment) |

Results from these tables demonstrate the analysis method only. They are not evidence about checkout changes, and every chart based on them must be marked as simulated.

## Stack

BigQuery (Sandbox) · dbt-bigquery · Python · Looker Studio

## Structure

```
models/
  staging/        one row per event, event params unnested
  intermediate/   sessions and funnel steps
  marts/          funnel and cohort facts
analysis/
  exploration/    ad-hoc queries used to inform modelling decisions
docs/
  metrics.md      KPI definitions (numerator, denominator, grain, population, window)
  decisions.md    decision log
```

## Setup

```bash
py -3.12 -m venv .venv
.venv\Scripts\activate
pip install -r requirements-lock.txt
gcloud auth application-default login
```

`requirements-lock.txt` pins every package, including transitive dependencies, so installs are reproducible. `requirements.txt` holds only the direct dependencies. After changing it, reinstall and regenerate the lock file with `pip freeze > requirements-lock.txt`.

Create the `ga4_funnel_experiment` profile in `~/.dbt/profiles.yml`. Use `method: oauth` and point it at your own GCP project. Do not put the profile in the repo.

```bash
dbt debug
dbt build
```

Sandbox tables can expire automatically, so every model must be rebuildable with `dbt build`.
