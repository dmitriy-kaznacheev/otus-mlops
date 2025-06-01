#!/usr/bin/env python3

import findspark
findspark.init()

from pyspark.sql import SparkSession
from pyspark.sql.types import StructType, StructField
from pyspark.sql.types import DoubleType, IntegerType, StringType, TimestampType


spark = (
    SparkSession
        .builder
        .appName("mlops_hw03")
        .config("spark.driver.memory", "4g") 
        .config("spark.executor.memory", "4g")     # 8 ГБ для экзекутора
        .config("spark.executor.cores", "2")       # 2 ядра на экзекутор
        .config("spark.executor.instances", "6")   # 6 экзекуторов
        .getOrCreate()
)


schema = StructType([
    StructField("transaction_id", IntegerType(), True),
    StructField("tx_datetime", TimestampType(), True),
    StructField("customer_id", IntegerType(), True),
    StructField("terminal_id", IntegerType(), True),
    StructField("tx_amount", DoubleType(), True),
    StructField("tx_time_seconds", IntegerType(), True),
    StructField("tx_time_days", IntegerType(), True),
    StructField("tx_fraud", IntegerType(), True),
    StructField("tx_fraud_scenario", IntegerType(), True)
])


df = spark.read.csv(
    "/dataset",
    header=False,
    pathGlobFilter="*.txt",
    schema=schema, 
    comment="#",
    mode="PERMISSIVE"
)

df_clean = (
    df.filter(df.terminal_id.isNotNull())
      .filter(df.customer_id > 0)
      .filter(df.tx_amount > 0)
      .filter(df.tx_time_seconds > 0)
      .filter(df.transaction_id > 0)
      .filter((df.tx_fraud == 0) | (df.tx_fraud == 1))
      .filter((df.tx_fraud_scenario == 0) | (df.tx_fraud_scenario == 1) | (df.tx_fraud_scenario == 2) | (df.tx_fraud_scenario == 3))
      .dropDuplicates(['transaction_id'])
)

df_clean.write.parquet("s3a://{{ s3_bucket }}/dataset.parquet")

spark.stop()