# Fabric notebook source

# METADATA ********************

# META {
# META   "kernel_info": {
# META     "name": "synapse_pyspark"
# META   },
# META   "dependencies": {}
# META }

# MARKDOWN ********************

# # 01 · Bronze ingest
# Loads every CSV under `lh_bronze/Files/raw/<table>/` into a Delta table `lh_bronze.raw_<table>`.
# Bronze rule: **land exactly what arrived**. Every column stays a string, nothing is filtered, and each row gets load metadata
# (`_source_file`, `_ingested_at`, `_batch_id`). Typing and cleaning happen in silver.
# Lakehouses are resolved **by name in the current workspace**, so the same notebook runs unchanged in dev and prod
# after a deployment-pipeline promotion.

# CELL ********************

# Parameters (toggle as parameter cell to override from a pipeline)
tables = ""          # comma-separated subset, e.g. "product,coupon"; empty = all folders under Files/raw
bronze_lakehouse = "lh_bronze"

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

import uuid
from pyspark.sql import functions as F

bronze_root = notebookutils.lakehouse.get(bronze_lakehouse)["properties"]["abfsPath"]
raw_root = f"{bronze_root}/Files/raw"
batch_id = str(uuid.uuid4())

available = sorted(f.name.rstrip("/") for f in notebookutils.fs.ls(raw_root) if f.isDir)
selected = [t.strip().lower() for t in tables.split(",") if t.strip()] or available
missing = set(selected) - set(available)
assert not missing, f"No raw folder for: {sorted(missing)}"
print(f"batch {batch_id}: loading {selected}")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

results = []
for table in selected:
    df = (
        spark.read.option("header", True)
        .option("inferSchema", False)       # bronze keeps everything as string
        .option("multiLine", False)
        .csv(f"{raw_root}/{table}/*.csv")
        .withColumn("_source_file", F.col("_metadata.file_name"))  # must be taken before any projection
    )
    # normalise header names to snake_case lower so silver code is predictable
    for c in df.columns:
        df = df.withColumnRenamed(c, c.strip().lower().replace(" ", "_"))

    df = (
        df.withColumn("_ingested_at", F.current_timestamp())
        .withColumn("_batch_id", F.lit(batch_id))
    )
    (
        df.write.format("delta")
        .mode("overwrite")
        .option("overwriteSchema", True)
        .save(f"{bronze_root}/Tables/raw_{table}")
    )
    n = spark.read.format("delta").load(f"{bronze_root}/Tables/raw_{table}").count()
    results.append((f"raw_{table}", n))
    print(f"raw_{table}: {n:,} rows")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

display(spark.createDataFrame(results, "table string, row_count long"))

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
