# Fabric notebook source

# METADATA ********************

# META {
# META   "kernel_info": {
# META     "name": "synapse_pyspark"
# META   },
# META   "dependencies": {}
# META }

# MARKDOWN ********************

# # 02 · Silver clean
# Reads `lh_bronze.raw_*` and writes typed, cleaned tables to `lh_silver` (same table names, no `raw_` prefix).
# Per table: rename (where the source is anonymised), cast to declared types, trim strings and turn blanks into NULL,
# drop exact duplicates, resolve known key conflicts with an explicit rule, then check the declared primary key is unique.
# Rows that fail a cast or lose a key conflict go to `lh_silver._rejects` (with a `reason`) instead of disappearing.
# dbt reads these tables through the `lh_silver` SQL endpoint (cross-database query from `wh_gold`).

# CELL ********************

tables = ""          # comma-separated subset; empty = all in SPEC
bronze_lakehouse = "lh_bronze"
silver_lakehouse = "lh_silver"

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# Table contracts: target column -> (source column, spark type). Keys are the grain used for the uniqueness check.
SPEC = {
    "transaction_data": {
        "columns": {
            "household_key":     ("household_key", "int"),
            "basket_id":         ("basket_id", "bigint"),
            "day":               ("day", "int"),
            "product_id":        ("product_id", "int"),
            "quantity":          ("quantity", "int"),
            "sales_value":       ("sales_value", "decimal(12,2)"),
            "store_id":          ("store_id", "int"),
            "retail_disc":       ("retail_disc", "decimal(12,2)"),
            "trans_time":        ("trans_time", "int"),          # HHMM, 0-2359
            "week_no":           ("week_no", "int"),
            "coupon_disc":       ("coupon_disc", "decimal(12,2)"),
            "coupon_match_disc": ("coupon_match_disc", "decimal(12,2)"),
        },
        # transaction lines are not unique on a natural key in the source; dedupe exact rows only
        "keys": None,
    },
    "product": {
        "columns": {
            "product_id":           ("product_id", "int"),
            "manufacturer":         ("manufacturer", "int"),
            "department":           ("department", "string"),
            "brand":                ("brand", "string"),
            "commodity_desc":       ("commodity_desc", "string"),
            "sub_commodity_desc":   ("sub_commodity_desc", "string"),
            "curr_size_of_product": ("curr_size_of_product", "string"),
        },
        "keys": ["product_id"],
    },
    "hh_demographic": {
        # this copy of the dataset anonymises five headers; mapping matches the dunnhumby user guide
        "columns": {
            "household_key":       ("household_key", "int"),
            "age_desc":            ("classification_1", "string"),
            "marital_status_code": ("classification_2", "string"),
            "income_desc":         ("classification_3", "string"),
            "household_size_desc": ("classification_4", "string"),
            "hh_comp_desc":        ("classification_5", "string"),
            "homeowner_desc":      ("homeowner_desc", "string"),
            "kid_category_desc":   ("kid_category_desc", "string"),
        },
        "keys": ["household_key"],
    },
    "campaign_desc": {
        "columns": {
            "campaign":      ("campaign", "int"),
            "campaign_type": ("description", "string"),
            "start_day":     ("start_day", "int"),
            "end_day":       ("end_day", "int"),
        },
        "keys": ["campaign"],
    },
    "campaign_table": {
        "columns": {
            "household_key": ("household_key", "int"),
            "campaign":      ("campaign", "int"),
            "campaign_type": ("description", "string"),
        },
        "keys": ["household_key", "campaign"],
    },
    "coupon": {
        "columns": {
            "coupon_upc": ("coupon_upc", "string"),   # identifier, keep as text
            "product_id": ("product_id", "int"),
            "campaign":   ("campaign", "int"),
        },
        "keys": ["coupon_upc", "product_id", "campaign"],
    },
    "coupon_redempt": {
        "columns": {
            "household_key": ("household_key", "int"),
            "day":           ("day", "int"),
            "coupon_upc":    ("coupon_upc", "string"),
            "campaign":      ("campaign", "int"),
        },
        "keys": None,
    },
    "causal_data": {
        "columns": {
            "product_id":   ("product_id", "int"),
            "store_id":     ("store_id", "int"),
            "week_no":      ("week_no", "int"),
            "display_code": ("display", "string"),   # in-store display location code, 0 = none
            "mailer_code":  ("mailer", "string"),    # mailer placement code, 0 = none
        },
        "keys": ["product_id", "store_id", "week_no"],
        # Source quirk: ~15k product/store/week keys (0.04%) appear twice with different codes.
        # Rule: keep the row showing the most promo exposure; the loser goes to _rejects (reason = duplicate_key).
        # expressions are sorted descending; first row per key wins
        "resolve_duplicates": [
            "(case when display_code <> '0' then 1 else 0 end) + (case when mailer_code <> '0' then 1 else 0 end)",
            "display_code",
            "mailer_code",
        ],
    },
}

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

from functools import reduce
from pyspark.sql import functions as F
from pyspark.sql.window import Window

bronze_root = notebookutils.lakehouse.get(bronze_lakehouse)["properties"]["abfsPath"]
silver_root = notebookutils.lakehouse.get(silver_lakehouse)["properties"]["abfsPath"]
selected = [t.strip().lower() for t in tables.split(",") if t.strip()] or list(SPEC)


def clean(table: str):
    spec = SPEC[table]
    raw = spark.read.format("delta").load(f"{bronze_root}/Tables/raw_{table}")

    # trim + blank -> NULL on the raw strings first
    src_cols = {src for src, _ in spec["columns"].values()}
    for c in src_cols:
        raw = raw.withColumn(c, F.when(F.trim(F.col(c)) == "", None).otherwise(F.trim(F.col(c))))

    typed = raw.select(
        *[F.col(src).cast(t).alias(tgt) for tgt, (src, t) in spec["columns"].items()],
        *[F.col(src).alias(f"_raw_{tgt}") for tgt, (src, _) in spec["columns"].items()],
        "_source_file",
        "_batch_id",
    )
    # a cast failure = raw value present but typed value NULL
    failed = reduce(
        lambda a, b: a | b,
        [F.col(f"_raw_{tgt}").isNotNull() & F.col(tgt).isNull() for tgt in spec["columns"]],
    )
    cast_rejects = typed.filter(failed).select(
        F.lit(table).alias("table_name"),
        F.lit("cast_failure").alias("reason"),
        F.to_json(F.struct(*[f"_raw_{tgt}" for tgt in spec["columns"]])).alias("raw_record"),
        "_source_file",
        "_batch_id",
        F.current_timestamp().alias("_rejected_at"),
    )
    good = typed.filter(~failed).select(*spec["columns"].keys(), "_source_file", "_batch_id").dropDuplicates(list(spec["columns"]))
    rejects = cast_rejects

    if spec.get("resolve_duplicates"):
        w = Window.partitionBy(*spec["keys"]).orderBy(*[F.expr(e).desc() for e in spec["resolve_duplicates"]])
        ranked = good.withColumn("_rn", F.row_number().over(w))
        dup_rejects = ranked.filter("_rn > 1").select(
            F.lit(table).alias("table_name"),
            F.lit("duplicate_key").alias("reason"),
            F.to_json(F.struct(*spec["columns"].keys())).alias("raw_record"),
            "_source_file",
            "_batch_id",
            F.current_timestamp().alias("_rejected_at"),
        )
        good = ranked.filter("_rn = 1").drop("_rn")
        rejects = rejects.unionByName(dup_rejects)

    good = good.select(*spec["columns"].keys()).withColumn("_loaded_at", F.current_timestamp())
    return good, rejects, spec["keys"]


# rejects are rebuilt per run for the tables being processed
rejects_path = f"{silver_root}/Tables/_rejects"
if notebookutils.fs.exists(rejects_path):
    spark.read.format("delta").load(rejects_path).filter(~F.col("table_name").isin(selected))         .write.format("delta").mode("overwrite").option("overwriteSchema", True).save(rejects_path + "_tmp")
    notebookutils.fs.rm(rejects_path, True)
    notebookutils.fs.mv(rejects_path + "_tmp", rejects_path)

summary = []
for table in selected:
    good, rejects, keys = clean(table)
    good.write.format("delta").mode("overwrite").option("overwriteSchema", True).save(f"{silver_root}/Tables/{table}")
    silver = spark.read.format("delta").load(f"{silver_root}/Tables/{table}")

    rejects = rejects.cache()
    n_rej = rejects.count()
    if n_rej:
        rejects.write.format("delta").mode("append").option("mergeSchema", True).save(rejects_path)

    dup_keys = 0
    if keys:
        dup_keys = silver.groupBy(*keys).count().filter("count > 1").count()

    n = silver.count()
    summary.append((table, n, n_rej, dup_keys))
    print(f"{table}: {n:,} rows, {n_rej:,} rejected, {dup_keys:,} duplicate keys")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

df = spark.createDataFrame(summary, "table string, rows long, rejected long, duplicate_keys long")
display(df)
bad = [r.table for r in df.collect() if r.duplicate_keys > 0]
assert not bad, f"Primary-key uniqueness failed for: {bad}"

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
