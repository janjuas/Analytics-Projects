{% docs dim_product %}
Conformed product dimension. One row per `product_id`.

Used by every fact that touches a product: sales lines, coupon eligibility and weekly promo exposure
(display / mailer). `is_private_label` supports the national-vs-private-label pricing questions.
{% enddocs %}
