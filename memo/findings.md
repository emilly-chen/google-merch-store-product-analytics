## 01 Funnel by device (sql/01_funnel_by_device.sql)
- Question: Where do sessions drop off, and does it differ by device?
- Key numbers: 360,129 sessions; overall session conversion 0.79%.
  Biggest leak: view_item -> add_to_cart (19.7% convert, 80.3% drop).
  Biggest post-cart leak: add_to_cart -> begin_checkout (39.3% convert).
- Device: mobile 0.82% vs desktop 0.77% overall (two-proportion z = 1.83, p ≈ 0.07),
  step rates within 1-2 pts across devices -> no meaningful device gap.
- My prior: post-cart drop would be largest; desktop would convert higher. Device prior not supported.
- Open questions: How many purchase sessions are missing earlier steps (DQ check)?
  Are cart drop-offs abandoned, or bought in a later session (needs user-level funnel)?

## 02 Data quality check (sql/02_dq_check.sql)
- Question: How many purchase sessions are missing an earlier funnel step?
- Key numbers: 4,848 purchase sessions. Missing add_to_cart: 2,000 (41.3%);
  missing view_item: 150 (3.1%); missing begin_checkout / add_payment_info: 3 each.
  4,848 - 2,848 (closed-funnel purchases) = 2,000: every excluded purchase lacks add_to_cart.
- Meaning: checkout-stage steps are reliable. add_to_cart is under-tracked, so the closed funnel
  understates conversion (0.79% vs 1.35% of sessions with a purchase) and likely overstates the
  view -> cart drop. North Star (purchasing users) relies on purchase events only, so it is unaffected.
- Open questions: Exactly 2,000 looks artificial. Is the gap concentrated in certain dates
  (tracking outage) or spread evenly (a checkout path that skips add_to_cart)?

## 03 Missing add_to_cart by date (sql/03_dq_missing_cart_by_date.sql)
- Question: Is the add_to_cart gap a tracking outage or a steady pattern?
- Key numbers: Nov 1-25: 1,127 of 1,223 purchase sessions (92%) lack add_to_cart
  (100% on Nov 1-15; partial recovery Nov 16-20). Nov 26-Jan 31: 873 of 3,625 (24%), stable daily.
- Meaning: add_to_cart was effectively untracked until Nov 26. Funnel conclusions about
  view -> cart must use Nov 26-Jan 31 only. The remaining ~24% gap is unexplained
  (possible "buy now" path or general loss) and is listed as a limitation.
- Decision: re-run the funnel for Nov 26-Jan 31 (01b). North Star and cohort retention
  do not depend on add_to_cart and keep the full window.

## 01b Funnel, clean tracking window (sql/01b_funnel_clean_window.sql)
- Question: Does the funnel conclusion hold once the add_to_cart outage is excluded?
- Window: 2020-11-26 to 2021-01-31 (271,118 sessions).
- Key numbers: view -> cart 26.2% (14,567 / 55,502; was 19.7%); cart -> checkout 38.9%; checkout -> payment 65.5%;
  payment -> purchase 74.2%. Only view -> cart moved, consistent with the DQ diagnosis.
- Device: mobile 1.05% vs desktop 0.99% (z = 1.68, p ≈ 0.09) -> still no meaningful gap.
- Meaning: view -> cart is still the largest drop (74%), but ~24% of purchases still lack
  add_to_cart, so part of it is tracking loss. cart -> checkout (61% drop) is the largest leak
  in a reliably tracked stage and the strongest candidate for product investigation.
- Caveat: overall conversion rose 0.79% -> 1.02%, but the new window is all holiday season,
  so the change mixes tracking repair and seasonality.

## 04 Weekly cohort retention (sql/04_cohort_retention.sql)
- Definition: cohort = week of user's first event (Monday weeks); retained = any event in week N.
  Unit: user_pseudo_id. Full window (does not depend on add_to_cart).
- Key numbers: 270,154 users across 14 cohorts. Week-1 retention 4.2% (weighted, cohorts Nov 2-Jan 18);
  week-2 1.9%; most cohorts flatten at ~0.4-0.6% by week 5-6.
- Cohort comparison (week 1): Nov 2-30 cohorts 5.8%; Dec 7-28 cohorts 2.9%; Jan 4-18 3.7% and rising.
- Meaning: retention drops steeply in week 1 then flattens; holiday-season new visitors look more
  one-and-done. Steep early drop means a constant churn rate (as in a simple CLV model) misstates value.
- Caveats: Nov cohorts include pre-window returning users (left-censoring), which inflates Nov retention;
  Dec 21/28 cohorts' week 1 falls on Christmas/New Year weeks (calendar effect). Oct 26 cohort is one day
  (Nov 1) and excluded. user_pseudo_id is device-level, so retention is understated.
- Calendar effect: Nov 2/9 cohorts rebound in weeks 3-4 (Black Friday / Cyber Monday weeks).
- Open questions: Do users who purchase in their first week retain better? (activation, week 2 plan)

## 05 North Star weekly (sql/05_north_star_weekly.sql)
- North Star (weekly purchasing users): 242 (wk Nov 2) -> 497 (Black Friday wk) -> 573 (Cyber Monday wk)
  -> peak 737 (wk Dec 7) -> low 136 (wk Dec 28) -> 367 (wk Jan 18). Peak is the 2nd week of December,
  not Black Friday (possible Christmas shipping cutoff; hypothesis only). Reliable: uses purchase events
  and user IDs only.
- Guardrail (AOV) NOT usable from 05: transaction_id missing Nov 1-8 and 70% missing wk Jan 25;
  duplicate purchase events 30% (wk Nov 16) and 18% (wk Nov 23) double-count revenue;
  numerator included events without transaction_id while denominator did not.
- Apparent AOV drop (~$100 in Nov -> ~$70 in Dec) is largely an artifact. Clean weeks Nov 30-Jan 18:
  AOV ~$57-74, ~$69 overall, no clear trend. Fix in 05b (dedupe to one row per transaction_id).

## 05b AOV deduplicated (sql/05b_aov_dedup.sql)
- Fix: one row per transaction_id (MAX revenue), same orders in numerator and denominator.
- Dedup effect: wk Nov 16 revenue $38,156 -> $26,869 (-30%); AOV $100 -> $70.52.
- AOV (wks Nov 16-Jan 18, 4,138 orders): $69.68 overall; Nov 16-30 $71.98; Dec 7-14 $71.31;
  Dec 21-Jan 18 $64.44. Wks Nov 9 and Jan 25 excluded (transaction_id coverage 58% / 30%).
- Meaning: weekly purchasers doubled (364 -> 737) into the Dec peak while AOV held ~$71, so peak
  growth came from more buyers, not larger orders. Flat AOV does not rule out discounting.

## 06 Activation (sql/06_activation.sql)
- Question: Which first-week behaviors are associated with returning in weeks 1-3?
- Cohorts Nov 30 - Jan 4 (132,371 new users; add_to_cart reliable; 3 full follow-up weeks).
  Baseline return rate 4.7%.
- First-week purchase: 1.1% of users; return 28.4% vs 4.5% (6.4x); 6.8% of returners.
- 3+ item views: 7.8% of users; return 17.2% vs 3.7% (4.7x); 28.5% of returners.
- Add to cart: 5.3% of users; 16.7% vs 4.1% (4.1x); 18.5% of returners.
- Search: 4.8% of users; 7.2% vs 4.6% (1.6x); 7.3% of returners. All differences: 95% CI excludes 0.
- Meaning: first-week purchase validates as activation (strongest association) but is too rare to
  steer. 3+ item views is the best leading indicator: strong association and the largest reach.
  Search is weakly associated (hypothesis: searchers who don't find items leave; check in adoption).
- Caveats: associational, not causal (self-selection); behaviors overlap (purchasers also browse).
- Open question: does browsing still predict return after excluding purchasers? (06b)

## 06b Activation segments (sql/06b_activation_segments.sql)
- Question: Does 3+ item browsing still predict return after excluding first-week purchasers?
- Mutually exclusive segments (Nov 30 - Jan 4 cohorts, 132,371 users; checks match 06):
  purchased 1.1% of users, return 28.4%, 6.8% of returners;
  browsed 3+ items, no purchase 6.8% of users, return 15.3%, 22.1% of returners;
  neither 92.0% of users, return 3.7%.
- browsed_no_purchase vs neither: 4.2x (diff 11.7 pts, 95% CI 10.9-12.4).
- Meaning: the browsing signal is not driven by purchasers. Proposed leading indicator for activation:
  3+ item views in the first week. Next: test with an experiment (e.g. stronger recommendations).
- Caveats: associational (more interested users browse more and return more); the 3-item threshold is
  arbitrary; test 1/2/3/5/10 to find where return rate jumps.

## 07a Event inventory (sql/07a_event_inventory.sql)
- Search: view_search_results 26,172 events -> enough for adoption/success analysis.
- Promotions: view_promotion 190,104; select_promotion 9,450 (~5.0% event-level click rate, rough).
- select_item 31,007 exists, but view_item_list only 71 -> check items.item_list_name/index (07b).
- first_visit 257,462: can identify truly new users and fix left-censoring in the cohort analysis (04).
- purchase events 5,692 vs 4,848 purchase sessions: consistent with duplicate purchase events (05).
- add_shipping_info (19,722) sits between begin_checkout and add_payment_info; not in our funnel yet.

## 07b select_item list and position (sql/07b_select_item_lists.sql)
- Question: Can we measure which list (e.g. search results) a click came from and its position?
- item_list_name is only placeholders ("(not set)", "Not available in demo dataset").
- item_list_index is not the clicked position: ~10.6 items per select_item event
  (329,339 unnested rows in the top 50 groups vs 31,007 events), and positions 2-12 are almost
  evenly distributed (~20K each), unlike real click behavior that concentrates at the top.
- Decision: cannot measure "clicked a top-3 search result". Proxy for search success:
  view_item after view_search_results in the same session (event_timestamp order).
- Tracking recommendation: record list source and clicked position on select_item.

## 07c Search adoption (sql/07c_search_adoption.sql)
- Adoption: 15,719 of 360,129 sessions searched (4.4%).
- Success (view_item after first search in session): 6,791 (43.2%); 8,928 search sessions (56.8%)
  ended without viewing any item.
- Outcome (session purchase rate): no search 1.22%; search 4.14%; successful search 8.88%;
  failed search 0.54% (16x gap, diff 95% CI 7.6-9.0 pts). Failed searchers buy less than non-searchers.
- Meaning: explains the weak search-return link in 06 (most searches fail). Opportunity: improve
  search success. Illustrative upper bound: +10 pts success -> ~1,572 more successful sessions ->
  ~131 orders -> ~$9.1K over 3 months at $69.68 AOV (assumes causality; validate with an A/B test).
- Limitations: session-level success; proxy for search quality (no click position, no search terms
  available); associational only.

## 07d Promotion adoption (sql/07d_promotion_adoption.sql)
- Adoption: 128,447 of 360,129 sessions saw a promotion (35.7%), 8x search adoption.
- Success (select_promotion after first view_promotion): 7,377 sessions (5.7% click rate).
- Outcome: purchase rate no promo view 0.27%; promo view 3.29%; promo click 3.47%;
  promo view without click 3.28%. Click vs no-click difference 0.19 pts, not significant
  (95% CI -0.24 to +0.62 pts).
- Meaning: clicking a promotion is not associated with buying more. The 12x gap between seeing
  and not seeing a promotion is likely selection bias: sessions that never see a promotion are
  mostly single-page landings that rarely buy. Promotion CTR is a low-priority lever; search
  success is the stronger opportunity.
- Data quality: only 15 sessions clicked a promotion without a tracked view; tracking is consistent.
- Limitations: session-level; promotion names/creatives not analyzed; associational only.
