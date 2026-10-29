# GA4 E-commerce Product Analytics — Project Guide for Claude

## Who I am and why this project exists
I'm Emilly Chen, a UCSD MSBA 2026 graduate targeting US Product Analyst roles. This repo is a portfolio project that proves skills I can't yet show on my resume: funnel analysis, cohort retention, activation, feature adoption, North Star / guardrail metrics, and roadmap prioritization. It will be the lead project on my portfolio website and I will defend every line of it in interviews, including live SQL rounds.

## How we work together (most important)
- **I write the core SQL first; you review it.** For funnel, cohort, activation and adoption queries, do not write the query for me unless I explicitly ask. Instead, point out bugs, edge cases, and clearer patterns, and explain *why*. I need to be able to write these from scratch in an interview.
- You can write supporting code freely: query runners, chart code, Streamlit/HTML for the dashboard, tests, README formatting.
- Explain trade-offs in plain language when you make a methodological choice (e.g., session vs. user grain, open vs. closed funnel).
- Never invent numbers. Every figure in a write-up must come from a query in this repo that was actually run, with its output saved in results/.
- Correlation is not causation. When describing activation or "what predicts retention", say it is associational unless an experiment supports it.

## Data
- Table: bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*
- Coverage: 2020-11-01 to 2021-01-31 (_TABLE_SUFFIX BETWEEN '20201101' AND '20210131')
- Google Merchandise Store GA4 export. Obfuscated sample: some values are placeholders such as <Other> or (data deleted). Mention this as a limitation in every write-up.
- Session key: user_pseudo_id + ga_session_id (int_value in event_params).
- Known tracking gaps (see memo/findings.md): add_to_cart untracked Nov 1-25; transaction_id missing Nov 1-8 and mostly missing week of Jan 25; duplicate purchase events mid-November.

## Cost guard
- Always dry-run a new query first and report the bytes it will scan before running it.
- Set maximum_bytes_billed (Python) or --maximum_bytes_billed (bq CLI) to 1 GB unless I approve more.

## Metric framework
- North Star: Weekly Purchasing Users (chosen over revenue so one large order or a price change can't inflate it).
- Input metrics: weekly active users; view_item → add_to_cart; add_to_cart → begin_checkout; checkout → purchase; repeat-purchase rate.
- Guardrails: average order value (deduplicated by transaction_id); revenue per purchaser; data quality (share of purchase sessions missing earlier funnel events).

## Plan
| Week | Deliverable | Skills proven |
|---|---|---|
| 1 | Metric framework; session funnel by device; data-quality check | North Star, guardrails, funnel |
| 2 | Weekly cohort retention heatmap; early behaviors associated with return visits; feature adoption (search, promotions) | Cohort, activation, adoption |
| 3 | 3–5 opportunities sized in revenue and ranked with RICE; one-page memo; interactive dashboard | Roadmap prioritization |

Status (2026-10-28): Week 1 done (01, 01b, 02, 03, 05, 05b). Weekly cohort retention (04) done early.
Next: activation, feature adoption, then RICE prioritization.

## Repo layout

```
sql/          numbered queries: 01_funnel_by_device.sql, 02_dq_check.sql, ...
results/      CSV and PNG output of each query, same number as the query
notebooks/    analysis and charts
memo/         findings.md (running log), final one-page memo
app/          dashboard for the portfolio site
CLAUDE.md     this file
README.md     project summary for GitHub
```

## Conventions
- SQL: BigQuery Standard SQL, uppercase keywords, CTEs over nested subqueries, one comment block at the top stating the question, grain, and assumptions.
- Compute rates from raw counts, never from already-rounded columns.
- After each analysis step, append to memo/findings.md: the question, the query file, the key number(s), what it means, and open questions.
- Commit after each working step with a message that says what was learned, not just what changed.
