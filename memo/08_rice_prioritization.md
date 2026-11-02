# 08 RICE Prioritization

Ranks five improvement opportunities found in queries 01–07d. Every number below comes from a saved result in `results/`. Effort figures are assumptions (no engineering input available).

## Common scenario

Each opportunity is sized as a **10% relative improvement in its target metric**, over one quarter (the 3-month data window). AOV = $69.68 (deduplicated, 05b).

## Sizing

| Opportunity | Target metric | Increment under +10% | Revenue / quarter |
|---|---|---|---|
| Reduce cart → checkout drop-off | 38.9% → 42.8% | +778 checkouts → **+378 orders** | **~$26,400** |
| Improve search success | 43.2% → 47.5% | +679 successful searches → +57 orders | ~$3,900 (upper bound) |
| Get new visitors to view more items | share viewing 3+ items 7.8% → 8.6% | +2,089 deep browsers → **+242 returning users** | not sized* |
| Re-engage December cohorts | weeks 1–3 return 4.7% → 5.2% | +411 returning users | not sized* |
| Raise promotion click-through | 5.7% → 6.3% | +737 clicks → ~1 order | ~$0 |

\* Purchase rate of returning users was not measured, so these are not converted to revenue.

How increments were computed:
- **Cart → checkout:** reach 20,002 cart sessions per quarter (14,567 in the 67-day clean window, scaled to 92 days). Each extra checkout yields ~0.49 orders (checkout → payment 65.5% × payment → purchase 74.2%).
- **Search:** each extra successful search moves purchase rate from 0.54% (failed) to 8.88% (successful). Assumes the relationship is causal, so this is an upper bound.
- **Browsing:** 267,789 new users (cohorts excluding Oct 26); browsed-no-purchase users return at 15.3% vs 3.7% (06b).
- **December cohorts:** 87,429 new users in the Dec 7–28 cohorts; baseline return 4.7% (06).
- **Promotions:** click vs no-click purchase rate differs by 0.19 pts, not significant (07d).

## RICE scores

RICE = Reach × Impact × Confidence ÷ Effort. Impact scale: 3 massive, 2 high, 1 medium, 0.5 low, 0.25 minimal, 0 no measurable effect. Confidence: 80% strong evidence, 50% associational or proxy, 30% weak.

| Opportunity | Reach / quarter | Impact | Confidence | Effort (person-months) | **RICE** |
|---|---|---|---|---|---|
| Get new visitors to view more items | 267,789 new users | 1 | 50% | 2 | **66,947** |
| Reduce cart → checkout drop-off | 20,002 cart sessions | 2 | 80% | 2 | **16,002** |
| Improve search success | 15,719 search sessions | 2 | 50% | 1 | **15,719** |
| Re-engage December cohorts | 87,429 Dec new users | 0.5 | 30% | 1 | **13,114** |
| Raise promotion click-through | 128,447 promo-view sessions | 0 | 80% | 0.5 | **0** |

Rationale:
- **View more items:** Impact 1 (4.2x association with returning, but indirect for purchase). Confidence 50% (associational; the 3-item threshold was chosen, not learned). Effort 2 (recommendation module on product pages).
- **Cart → checkout:** Impact 2 (cart users have the strongest purchase intent and are few steps from buying). Confidence 80% (reliably tracked stage with a large drop, but the cause of the drop is unknown). Effort 2 (diagnose, then change checkout flow).
- **Search:** Impact 2 (16x purchase-rate gap between successful and failed searches). Confidence 50% (search success is a proxy; selection bias likely). Effort 1 (e.g. zero-results page suggestions, synonyms).
- **December cohorts:** Impact 0.5 (one-time gift buyers rarely return). Confidence 30% (comparison confounded by left-censoring and holiday weeks). Effort 1 (one email campaign).
- **Promotions:** Impact 0, because clicks show no measurable link to purchase.

## Two caveats

1. **RICE favors reach.** "View more items" ranks first mainly because it touches every new visitor, yet it is the one opportunity whose revenue effect we could not size. Its next step is an A/B test, not a full build.
2. **Scores depend on evidence.** With the standard minimum Impact of 0.25, promotions would score 51,379 and rank second, purely from large reach and low effort. The data shows no click-to-purchase link, so Impact is set to 0.

## Recommended roadmap

| Order | Item | Why |
|---|---|---|
| 0 (prerequisite) | Fix tracking: remaining ~24% add_to_cart gap, transaction_id gaps, select_item list source and clicked position | Experiments on the items below cannot be trusted without it |
| 1 | Reduce cart → checkout drop-off | Largest sized revenue (~$26K/quarter) and highest confidence |
| 2 | A/B test a recommendation module for new visitors | Highest RICE and reach, but revenue impact unknown |
| 3 | Fix failed searches | Low effort and clear signal, but only 4.4% of sessions search |
| 4 | Re-engage December cohorts | Weakest evidence; revisit with cleaner data |
| Not now | Raise promotion click-through | No evidence that clicks lead to purchases |

## Limitations

All relationships are associational; the +10% scenario is illustrative, not a forecast; Effort is assumed; data is an obfuscated sample from the 2020 holiday season.
