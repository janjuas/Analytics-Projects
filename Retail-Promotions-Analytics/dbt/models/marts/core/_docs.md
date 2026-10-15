{% docs dim_product %}
Conformed product dimension. One row per `product_id`.

Used by every fact that touches a product: sales lines, coupon eligibility and weekly promo exposure
(display / mailer). `is_private_label` supports the national-vs-private-label pricing questions.
{% enddocs %}

{% docs dim_date %}
Study calendar. One row per study day, covering the transaction history (days 1-711) and the campaign
days that run past it.

The source only has day and week numbers. Day 1 is anchored on `var('day_one_date')`, a Wednesday, so
that the source's weeks (which start on day 6) line up with Monday-to-Sunday calendar weeks and
weekday analysis is meaningful. The anchor is an assumption; the weekday pattern is real.
{% enddocs %}

{% docs dim_household %}
One row per household in the panel (2,500), built from transactions so no household is lost.

Demographics exist for 801 households; the other 1,699 carry `Unknown` bands and `has_demographics = 0`
rather than being dropped. Band labels are anonymised but ordinal; the `*_sort` columns give their
numeric order. Attribute names for the anonymised `classification_*` source columns are inferred from
the original public release of this dataset, whose value sets match.
{% enddocs %}

{% docs dim_store %}
One row per store with panel transactions (582). Only 115 stores have display and mailer tracking
(`has_promo_tracking = 1`); promotion-uplift analysis should be limited to them. The source has no
store attributes, so `panel_sales_band` is derived from panel spend.
{% enddocs %}

{% docs dim_campaign %}
One row per marketing campaign (30). TypeA campaigns are targeted: each participating household gets
16 coupons selected from the campaign's pool based on its purchase history. TypeB and TypeC campaigns
send every coupon to every participating household. Coupons are valid between the start and end days.
{% enddocs %}
